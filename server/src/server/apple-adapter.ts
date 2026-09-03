import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import {
  SignedDataVerifier,
  AppStoreServerAPIClient,
  Environment,
} from '@apple/app-store-server-library';
import type {
  JWSTransactionDecodedPayload,
  ResponseBodyV2DecodedPayload,
  TransactionInfoResponse,
} from '@apple/app-store-server-library';
import { ApiError } from './http';
import { findOrderByStoreTransactionId } from './order-repository';
import { paymentsForApp, appIdForAppleBundle } from './payment-apps';
import type { ApplePaymentsConfig } from './payment-apps';
import type {
  PaymentAdapter,
  PaymentProviderId,
  VerifyResult,
  WebhookEvent,
} from './payment-providers';

const CERTS_DIR = join(process.cwd(), 'certs');

function loadAppleRootCerts(): Buffer[] {
  try {
    return readdirSync(CERTS_DIR)
      .filter((f) => f.endsWith('.cer') || f.endsWith('.pem') || f.endsWith('.crt'))
      .map((f) => readFileSync(join(CERTS_DIR, f)));
  } catch {
    return [];
  }
}

function resolveEnvironment(value: string | undefined): Environment {
  if (value === 'Production') return Environment.PRODUCTION;
  if (value === 'LocalTesting') return Environment.LOCAL_TESTING;
  if (value === 'Xcode') return Environment.XCODE;
  return Environment.SANDBOX;
}

export class AppleAdapter implements PaymentAdapter {
  readonly id: PaymentProviderId = 'apple';
  /** Per-app per-environment caches（key = `${appId}|${env}`），见 environments()。 */
  private verifiers = new Map<string, SignedDataVerifier>();
  private apiClients = new Map<string, AppStoreServerAPIClient>();

  private cacheKey(appId: string, env: Environment): string {
    return `${appId}|${env}`;
  }

  /**
   * Primary env comes from the app's credential config; Production/Sandbox fall
   * back to each other — real App Store purchases hit Production while
   * TestFlight/sandbox transactions hit Sandbox. Pinning a single env makes
   * verify always fail on the other side.
   */
  private environments(cred: ApplePaymentsConfig): readonly Environment[] {
    const primary = resolveEnvironment(cred.environment);
    const fallback = primary === Environment.PRODUCTION
      ? Environment.SANDBOX
      : primary === Environment.SANDBOX ? Environment.PRODUCTION : null;
    return fallback ? [primary, fallback] : [primary];
  }

  private init(appId: string, env: Environment, cred: ApplePaymentsConfig): SignedDataVerifier {
    const key = this.cacheKey(appId, env);
    const cached = this.verifiers.get(key);
    if (cached) return cached;
    const verifier = new SignedDataVerifier(
      loadAppleRootCerts(),
      false,
      env,
      cred.bundleId,
      cred.appAppleId,
    );
    this.verifiers.set(key, verifier);
    return verifier;
  }

  /**
   * Build an App Store Server API client for authoritative server-side verification.
   * The client sends a transactionId, the server fetches the JWS from Apple and
   * verifies it — never trusting client-sent data.
   */
  private initApiClient(appId: string, env: Environment, cred: ApplePaymentsConfig): AppStoreServerAPIClient {
    const key = this.cacheKey(appId, env);
    const cached = this.apiClients.get(key);
    if (cached) return cached;
    const keyPath = join(process.cwd(), cred.privateKeyFile);
    if (!cred.issuerId || !cred.keyId || !existsSync(keyPath)) {
      throw new ApiError(503, 'PAYMENT_PROVIDER_NOT_CONFIGURED', `Apple Server API 配置不完整（${appId}）`, true);
    }
    const signingKey = readFileSync(keyPath, 'utf8').trim();
    const client = new AppStoreServerAPIClient(signingKey, cred.keyId, cred.issuerId, cred.bundleId, env);
    this.apiClients.set(key, client);
    return client;
  }

  async verifyReceipt(input: Readonly<{
    appId: string; userId: string; orderId?: string; receipt: unknown;
  }>): Promise<VerifyResult> {
    if (typeof input.receipt !== 'string') return { ok: false };
    const cred = paymentsForApp(input.appId).apple;
    if (!cred) {
      throw new ApiError(503, 'PAYMENT_PROVIDER_NOT_CONFIGURED', `Apple 支付尚未配置（${input.appId}）`, true);
    }
    // Try env by env: primary failing (e.g. Production configured but the transaction
    // came from a TestFlight sandbox purchase) falls through to the other env.
    for (const env of this.environments(cred)) {
      try {
        let jws: string;
        if (input.receipt.startsWith('eyJ')) {
          // Client sent a JWS directly (StoreKit 2 signed transaction, or test fixture).
          // Verify it with Apple's root CA — no network call needed.
          jws = input.receipt;
        } else {
          // Client sent a transactionId — Apple's recommended authoritative flow.
          // Fetch the JWS from Apple's App Store Server API, then verify.
          const response: TransactionInfoResponse =
            await this.initApiClient(input.appId, env, cred).getTransactionInfo(input.receipt);
          jws = response.signedTransactionInfo ?? '';
          if (!jws) return { ok: false };
        }
        const tx: JWSTransactionDecodedPayload =
          await this.init(input.appId, env, cred).verifyAndDecodeTransaction(jws);
        const expiresMs = tx.expiresDate;
        return {
          ok: true,
          storeTransactionId: tx.originalTransactionId ?? '',
          productId: tx.productId ?? '',
          expiresAt: expiresMs ? new Date(Number(expiresMs)).toISOString() : undefined,
        };
      } catch {
        // Fall through to the next env; all-env failure means verification rejected.
      }
    }
    return { ok: false };
  }

  /**
   * Webhook 没有 x-app-id：先对 JWS **不验签**解码读出 bundleId 反查归属 app，
   * 再用该 app 的凭证做真实验证。路由读数据不构成信任边界——后续 verify
   * 才是；bundle 反查不到（未注册的 app）直接 401。
   */
  private routeAppId(signedPayload: string): string {
    try {
      const payloadPart = signedPayload.split('.')[1] ?? '';
      const payload = JSON.parse(
        Buffer.from(payloadPart, 'base64url').toString('utf8'),
      ) as { data?: { bundleId?: string }; summary?: { bundleId?: string } };
      const bundleId = payload.data?.bundleId ?? payload.summary?.bundleId ?? '';
      if (bundleId) {
        const appId = appIdForAppleBundle(bundleId);
        if (appId) return appId;
      }
    } catch {
      // 解码失败走统一 401
    }
    throw new ApiError(401, 'WEBHOOK_SIGNATURE_INVALID', 'apple webhook 归属 app 未知', false);
  }

  async parseWebhook(
    rawBody: Buffer,
    _headers: Readonly<Record<string, string>>,
  ): Promise<WebhookEvent | null> {
    let signedPayload: string;
    try {
      const body = JSON.parse(rawBody.toString()) as { signedPayload?: string };
      signedPayload = body.signedPayload ?? '';
    } catch {
      throw new ApiError(401, 'WEBHOOK_SIGNATURE_INVALID', 'apple webhook 无 signedPayload', false);
    }
    if (!signedPayload) {
      throw new ApiError(401, 'WEBHOOK_SIGNATURE_INVALID', 'apple webhook 无 signedPayload', false);
    }
    const appId = this.routeAppId(signedPayload);
    const cred = paymentsForApp(appId).apple;
    if (!cred) {
      throw new ApiError(401, 'WEBHOOK_SIGNATURE_INVALID', `apple webhook ${appId} 未配置凭证`, false);
    }
    let notif: ResponseBodyV2DecodedPayload | null = null;
    // Webhook 可能注册在任一环境（TestFlight 沙盒通知/生产通知），逐环境验签
    for (const env of this.environments(cred)) {
      try {
        notif = await this.init(appId, env, cred).verifyAndDecodeNotification(signedPayload);
        break;
      } catch {
        // 落下一环境
      }
    }
    if (!notif) {
      throw new ApiError(401, 'WEBHOOK_SIGNATURE_INVALID', 'apple webhook 验签失败', false);
    }
    const notificationType = String(notif.notificationType ?? '');
    // REFUND/REVOKE → 立即撤销；DID_RENEW → 续订；EXPIRED/GRACE_PERIOD_EXPIRED → 到期失效；
    // 其余（SUBSCRIBED/DID_CHANGE_RENEWAL_STATUS/TEST…）不改变权益，忽略。
    let kind: 'renew' | 'refund' | 'expire' = 'renew';
    if (notificationType === 'REFUND' || notificationType === 'REVOKE') kind = 'refund';
    else if (notificationType === 'DID_RENEW') kind = 'renew';
    else if (notificationType === 'EXPIRED' || notificationType === 'GRACE_PERIOD_EXPIRED') kind = 'expire';
    else return null;
    // The Data interface has no originalTransactionId; fall back to decoding signedTransactionInfo.
    let originalTransactionId = '';
    let expiresAt: string | undefined;
    if (notif.data?.signedTransactionInfo) {
      try {
        const tx = await this.init(
          appId,
          // 通知自带 environment 声明（Production/Sandbox），按它选验签器
          resolveEnvironment(notif.data.environment),
          cred,
        ).verifyAndDecodeTransaction(notif.data.signedTransactionInfo);
        originalTransactionId = tx.originalTransactionId ?? '';
        // JWS transaction 的 expiresDate 为毫秒 epoch（数字）
        const rawExpiry = (tx as { expiresDate?: number | string }).expiresDate;
        if (rawExpiry) expiresAt = new Date(Number(rawExpiry)).toISOString();
      } catch {
        // leave empty — webhook-service handles unknown order safely
      }
    }
    let orderId = '';
    if (originalTransactionId) {
      const order = await findOrderByStoreTransactionId(originalTransactionId);
      orderId = order?.id ?? '';
    }
    return { provider: 'apple', eventId: notif.notificationUUID ?? '', kind, orderId, expiresAt };
  }
}

export const appleAdapter = new AppleAdapter();
