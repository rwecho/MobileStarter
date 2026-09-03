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
  /** Per-environment caches (Production/Sandbox back each other up, see environments()). */
  private verifiers = new Map<Environment, SignedDataVerifier>();
  private apiClients = new Map<Environment, AppStoreServerAPIClient>();

  /**
   * Primary env comes from APPLE_ENVIRONMENT; Production/Sandbox fall back to each other —
   * real App Store purchases hit Production while TestFlight/sandbox transactions hit
   * Sandbox. Pinning a single env makes verify always fail on the other side.
   */
  private environments(): readonly Environment[] {
    const primary = resolveEnvironment(process.env.APPLE_ENVIRONMENT ?? 'Sandbox');
    const fallback = primary === Environment.PRODUCTION
      ? Environment.SANDBOX
      : primary === Environment.SANDBOX ? Environment.PRODUCTION : null;
    return fallback ? [primary, fallback] : [primary];
  }

  private init(env: Environment): SignedDataVerifier {
    const cached = this.verifiers.get(env);
    if (cached) return cached;
    const bundleId = process.env.APPLE_BUNDLE_ID;
    const appAppleId = process.env.APPLE_APP_APPLE_ID;
    if (!bundleId || !appAppleId) {
      throw new ApiError(503, 'PAYMENT_PROVIDER_NOT_CONFIGURED', 'Apple 支付尚未配置', true);
    }
    const verifier = new SignedDataVerifier(
      loadAppleRootCerts(),
      false,
      env,
      bundleId,
      Number(appAppleId),
    );
    this.verifiers.set(env, verifier);
    return verifier;
  }

  /**
   * Build an App Store Server API client for authoritative server-side verification.
   * Uses the issuer key (downloaded from App Store Connect) to call Apple's API directly.
   * This is the Apple-recommended pattern: the client sends a transactionId, the server
   * fetches the JWS from Apple and verifies it — never trusting client-sent data.
   */
  private initApiClient(env: Environment): AppStoreServerAPIClient {
    const cached = this.apiClients.get(env);
    if (cached) return cached;
    const issuerId = process.env.APPLE_ISSUER_ID;
    const keyId = process.env.APPLE_KEY_ID;
    const bundleId = process.env.APPLE_BUNDLE_ID;
    const keyFile = process.env.APPLE_PRIVATE_KEY_FILE;
    if (!issuerId || !keyId || !bundleId || !keyFile) {
      throw new ApiError(503, 'PAYMENT_PROVIDER_NOT_CONFIGURED', 'Apple Server API 尚未配置', true);
    }
    const keyPath = join(process.cwd(), keyFile);
    if (!existsSync(keyPath)) {
      throw new ApiError(503, 'PAYMENT_PROVIDER_NOT_CONFIGURED', `Apple 私钥文件不存在: ${keyFile}`, true);
    }
    const signingKey = readFileSync(keyPath, 'utf8').trim();
    const client = new AppStoreServerAPIClient(signingKey, keyId, issuerId, bundleId, env);
    this.apiClients.set(env, client);
    return client;
  }

  async verifyReceipt(input: Readonly<{
    appId: string; userId: string; orderId?: string; receipt: unknown;
  }>): Promise<VerifyResult> {
    if (typeof input.receipt !== 'string') return { ok: false };
    // Try env by env: primary failing (e.g. Production configured but the transaction
    // came from a TestFlight sandbox purchase) falls through to the other env.
    for (const env of this.environments()) {
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
            await this.initApiClient(env).getTransactionInfo(input.receipt);
          jws = response.signedTransactionInfo ?? '';
          if (!jws) return { ok: false };
        }
        const tx: JWSTransactionDecodedPayload =
          await this.init(env).verifyAndDecodeTransaction(jws);
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
    let notif: ResponseBodyV2DecodedPayload | null = null;
    // Webhook 可能注册在任一环境（TestFlight 沙盒通知/生产通知），逐环境验签
    for (const env of this.environments()) {
      try {
        notif = await this.init(env).verifyAndDecodeNotification(signedPayload);
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
          // 通知自带 environment 声明（Production/Sandbox），按它选验签器
          resolveEnvironment(notif.data.environment),
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
