import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { GoogleAuth } from 'google-auth-library';
import { ApiError } from './http';
import { findOrderByStoreTransactionId } from './order-repository';
import { paymentsForApp, appIdForGooglePackage } from './payment-apps';
import {
  pubsubAuthConfigured, verifyPubSubPush, warnPubsubAuthUnconfigured,
} from './pubsub-auth';
import type {
  PaymentAdapter,
  PaymentProviderId,
  VerifyResult,
  WebhookEvent,
} from './payment-providers';

const PLAY_API = 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications';
const SCOPE = 'https://www.googleapis.com/auth/androidpublisher';

/**
 * Google Play Developer API adapter — server-authoritative verification.
 *
 * The client sends { productId, purchaseToken } as the receipt.
 * The server calls Google Play Developer API to verify the purchase,
 * extracts productId + expiryTimeMillis, and returns the result.
 *
 * RTDN (Real-time Developer Notifications) arrive via Google Pub/Sub push
 * to /webhooks/google; parseWebhook decodes the Pub/Sub envelope, routes by
 * packageName → app credentials, and maps notificationType → WebhookEvent.
 */
export class GoogleAdapter implements PaymentAdapter {
  readonly id: PaymentProviderId = 'google';
  /** 多 app：每个 auth app_id 一套 GoogleAuth（各绑各的服务账号 JSON） */
  private auths = new Map<string, GoogleAuth>();

  private initAuth(appId: string): GoogleAuth {
    const cached = this.auths.get(appId);
    if (cached) return cached;
    const cred = paymentsForApp(appId).google;
    if (!cred || !cred.serviceAccountFile) {
      throw new ApiError(503, 'PAYMENT_PROVIDER_NOT_CONFIGURED', `Google 支付尚未配置（${appId}）`, true);
    }
    const keyPath = join(process.cwd(), cred.serviceAccountFile);
    if (!existsSync(keyPath)) {
      throw new ApiError(503, 'PAYMENT_PROVIDER_NOT_CONFIGURED', `Google 服务账号文件不存在: ${cred.serviceAccountFile}`, true);
    }
    const auth = new GoogleAuth({ keyFile: keyPath, scopes: [SCOPE] });
    this.auths.set(appId, auth);
    return auth;
  }

  private async getAccessToken(appId: string): Promise<string> {
    const client = await this.initAuth(appId).getClient();
    const token = await client.getAccessToken();
    return token.token ?? '';
  }

  async verifyReceipt(input: Readonly<{
    appId: string; userId: string; orderId?: string; receipt: unknown;
  }>): Promise<VerifyResult> {
    if (typeof input.receipt !== 'object' || input.receipt === null) {
      return { ok: false };
    }
    const { productId, purchaseToken } = input.receipt as { productId?: string; purchaseToken?: string };
    if (!productId || !purchaseToken) return { ok: false };

    const packageName = paymentsForApp(input.appId).google?.packageName;
    if (!packageName) {
      throw new ApiError(503, 'PAYMENT_PROVIDER_NOT_CONFIGURED', `Google 支付尚未配置（${input.appId}）`, true);
    }

    try {
      const token = await this.getAccessToken(input.appId);
      const headers = { Authorization: `Bearer ${token}` };

      // Try subscription verification first (month/year plans).
      let response = await fetch(
        `${PLAY_API}/${packageName}/purchases/subscriptions/${productId}/tokens/${purchaseToken}`,
        { headers },
      );
      let isSubscription = true;

      // 404 → not a subscription; try one-time product.
      if (response.status === 404) {
        isSubscription = false;
        response = await fetch(
          `${PLAY_API}/${packageName}/purchases/products/${productId}/tokens/${purchaseToken}`,
          { headers },
        );
      }

      if (!response.ok) return { ok: false };
      const purchase = await response.json() as Record<string, unknown>;

      // Subscriptions: expiryTimeMillis + ack state.
      // Products: purchaseState (0=Purchased, 1=Canceled).
      const expiryMs = purchase['expiryTimeMillis'] as string | undefined;
      const purchaseState = purchase['purchaseState'] as number | undefined;
      const consumptionState = purchase['consumptionState'] as number | undefined;

      // For one-time products, purchaseState 0 = Purchased.
      if (purchaseState !== undefined && purchaseState !== 0) {
        return { ok: false };
      }

      // 购买确认：未 ack 的购买 3 天后会被 Google 自动退款。acknowledge 幂等
      // （409/已 ack 视为成功）；ack 失败不否决验签结果，只尽力补 ack。
      const acknowledgementState = purchase['acknowledgementState'] as number | undefined;
      if (acknowledgementState === 0) {
        const kind = isSubscription ? 'subscriptions' : 'products';
        await fetch(
          `${PLAY_API}/${packageName}/purchases/${kind}/${productId}/tokens/${purchaseToken}:acknowledge`,
          { method: 'POST', headers, body: '{}' },
        ).catch(() => undefined);
      }

      return {
        ok: true,
        storeTransactionId: purchaseToken,
        productId,
        expiresAt: expiryMs ? new Date(Number(expiryMs)).toISOString() : undefined,
      };
    } catch {
      return { ok: false };
    }
  }

  async parseWebhook(
    rawBody: Buffer,
    headers: Readonly<Record<string, string>>,
  ): Promise<WebhookEvent | null> {
    // 传输鉴权（与 Apple JWS / HMS x5c 验签对齐）：Pub/Sub push 附带的 OIDC
    // JWT 在解析任何报文内容之前验证。env 未配置时灰度放行（先部署后配置
    // 不破坏现有 push 订阅）。
    if (pubsubAuthConfigured()) {
      await verifyPubSubPush(headers);
    } else {
      warnPubsubAuthUnconfigured();
    }

    // Google RTDN arrives as a Pub/Sub push: { message: { data, messageId }, subscription }
    // The `data` is base64-encoded JSON: DeveloperNotification.
    let envelope: { message?: { data?: string; messageId?: string } };
    try {
      envelope = JSON.parse(rawBody.toString()) as typeof envelope;
    } catch {
      console.warn('[google-webhook] 拒绝推送：RTDN 格式无效');
      throw new ApiError(401, 'WEBHOOK_SIGNATURE_INVALID', 'Google RTDN 格式无效', false);
    }
    const data = envelope.message?.data;
    if (!data) {
      console.warn('[google-webhook] 拒绝推送：RTDN 无 data');
      throw new ApiError(401, 'WEBHOOK_SIGNATURE_INVALID', 'Google RTDN 无 data', false);
    }

    let notification: Record<string, unknown>;
    try {
      notification = JSON.parse(
        Buffer.from(data, 'base64').toString('utf8'),
      ) as Record<string, unknown>;
    } catch {
      console.warn('[google-webhook] 拒绝推送：RTDN data 解码失败');
      throw new ApiError(401, 'WEBHOOK_SIGNATURE_INVALID', 'Google RTDN data 解码失败', false);
    }

    // DeveloperNotification shape:
    //   { version, packageName, eventTimeMillis,
    //     subscriptionNotification: { notificationType, purchaseToken, subscriptionId },
    //     oneTimeProductNotification: { notificationType, purchaseToken, sku },
    //     voidedPurchaseNotification: { purchaseToken, orderId, productType, refundState } }
    const subNotif = notification['subscriptionNotification'] as Record<string, unknown> | undefined;
    const voidedNotif = notification['voidedPurchaseNotification'] as Record<string, unknown> | undefined;

    // 多 app 路由：packageName → auth app_id；未注册的包直接拒绝
    // （顺带构成一层伪造过滤——未知来源的通知进不了权益流程）。
    const packageName = String(notification['packageName'] ?? '');
    const routedAppId = appIdForGooglePackage(packageName);
    if (!routedAppId) {
      console.warn('[google-webhook] 拒绝推送：未知 packageName', packageName);
      throw new ApiError(401, 'WEBHOOK_SIGNATURE_INVALID', `google webhook 未知 packageName: ${packageName}`, false);
    }
    const cred = paymentsForApp(routedAppId).google;
    if (!cred) {
      console.warn('[google-webhook] 拒绝推送：未配置凭证', routedAppId);
      throw new ApiError(401, 'WEBHOOK_SIGNATURE_INVALID', `google webhook ${routedAppId} 未配置凭证`, false);
    }

    // Map notification types to refund/renew/expire——显式映射、无默认值：
    // 未识别的通知一律忽略（safe-by-default），绝不当作续订处理。
    // RTDN subscriptionNotification types: 1=RECOVERED, 2=RENEWED, 3=CANCELED, 4=PURCHASED,
    //   5=ON_HOLD, 6=IN_GRACE, 7=RESTARTED, 8=REVOKED, 12=EXPIRED, 13=PRICE_CHANGE_CONFIRMED.
    // Voided purchase notification = refund.
    // CANCELED(3) 只是关掉后续续订，权益保留到到期（EXPIRED(12) 随后到达）；
    // ON_HOLD(5) 冻结期挂起权益（RESTARTED(7)→renew 自动恢复）；IN_GRACE(6)
    // 保持现状——旧版 Play API 此刻回传的是过去时 expiryTime，写 renew 会把
    // renew_at 倒拨。
    let kind: 'refund' | 'renew' | 'expire';
    let purchaseToken = '';
    let subscriptionId = '';

    if (voidedNotif) {
      kind = 'refund';
      purchaseToken = String(voidedNotif['purchaseToken'] ?? '');
    } else if (subNotif) {
      purchaseToken = String(subNotif['purchaseToken'] ?? '');
      subscriptionId = String(subNotif['subscriptionId'] ?? '');
      const nt = Number(subNotif['notificationType'] ?? 0);
      if (nt === 1 || nt === 2 || nt === 4 || nt === 7) kind = 'renew';
      else if (nt === 5 || nt === 12) kind = 'expire';
      else if (nt === 8) kind = 'refund';
      else return null; // 3 CANCELED / 6 IN_GRACE / 13+ 未识别：不改变权益
    } else {
      // oneTimeProductNotification：会员订阅无一次性续订概念，忽略。
      return null;
    }

    // Find our order by the purchase token (stored as store_transaction_id).
    let orderId = '';
    if (purchaseToken) {
      const order = await findOrderByStoreTransactionId(purchaseToken);
      orderId = order?.id ?? '';
    }

    // 续订：RTDN 不带到期时刻 → 向 Play API 查询（尽力而为，失败则仅标记续订）
    let expiresAt: string | undefined;
    if (kind === 'renew' && purchaseToken && subscriptionId && orderId) {
      try {
        const token = await this.getAccessToken(routedAppId);
        const res = await fetch(
          `${PLAY_API}/${cred.packageName}/purchases/subscriptions/${subscriptionId}/tokens/${purchaseToken}`,
          { headers: { Authorization: `Bearer ${token}` } },
        );
        if (res.ok) {
          const purchase = await res.json() as Record<string, unknown>;
          const expiryMs = purchase['expiryTimeMillis'] as string | undefined;
          if (expiryMs) expiresAt = new Date(Number(expiryMs)).toISOString();
        }
      } catch {
        // 查询失败不否决续订事件
      }
    }

    return {
      provider: 'google',
      eventId: envelope.message?.messageId ?? '',
      kind,
      orderId,
      expiresAt,
    };
  }
}

export const googleAdapter = new GoogleAdapter();
