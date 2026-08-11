import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import {
  SignedDataVerifier,
  Environment,
} from '@apple/app-store-server-library';
import type {
  JWSTransactionDecodedPayload,
  ResponseBodyV2DecodedPayload,
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
  private verifier: SignedDataVerifier | null = null;

  private init(): SignedDataVerifier {
    if (this.verifier) return this.verifier;
    const bundleId = process.env.APPLE_BUNDLE_ID;
    const appAppleId = process.env.APPLE_APP_APPLE_ID;
    if (!bundleId || !appAppleId) {
      throw new ApiError(503, 'PAYMENT_PROVIDER_NOT_CONFIGURED', 'Apple 支付尚未配置', true);
    }
    const environment = resolveEnvironment(process.env.APPLE_ENVIRONMENT ?? 'Sandbox');
    this.verifier = new SignedDataVerifier(
      loadAppleRootCerts(),
      false,
      environment,
      bundleId,
      Number(appAppleId),
    );
    return this.verifier;
  }

  async verifyReceipt(input: Readonly<{
    appId: string; userId: string; orderId?: string; receipt: unknown;
  }>): Promise<VerifyResult> {
    if (typeof input.receipt !== 'string') return { ok: false };
    try {
      const tx: JWSTransactionDecodedPayload =
        await this.init().verifyAndDecodeTransaction(input.receipt);
      const expiresMs = tx.expiresDate;
      return {
        ok: true,
        storeTransactionId: tx.originalTransactionId ?? '',
        productId: tx.productId ?? '',
        expiresAt: expiresMs ? new Date(Number(expiresMs)).toISOString() : undefined,
      };
    } catch {
      return { ok: false };
    }
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
    let notif: ResponseBodyV2DecodedPayload;
    try {
      notif = await this.init().verifyAndDecodeNotification(signedPayload);
    } catch {
      throw new ApiError(401, 'WEBHOOK_SIGNATURE_INVALID', 'apple webhook 验签失败', false);
    }
    const notificationType = String(notif.notificationType ?? '');
    const kind: 'refund' | 'renew' =
      notificationType === 'REFUND' || notificationType === 'REVOKE' ? 'refund' : 'renew';
    // The Data interface has no originalTransactionId; fall back to decoding signedTransactionInfo.
    let originalTransactionId = '';
    if (notif.data?.signedTransactionInfo) {
      try {
        const tx = await this.init().verifyAndDecodeTransaction(notif.data.signedTransactionInfo);
        originalTransactionId = tx.originalTransactionId ?? '';
      } catch {
        // leave empty — webhook-service handles unknown order safely
      }
    }
    let orderId = '';
    if (originalTransactionId) {
      const order = await findOrderByStoreTransactionId(originalTransactionId);
      orderId = order?.id ?? '';
    }
    return { provider: 'apple', eventId: notif.notificationUUID ?? '', kind, orderId };
  }
}

export const appleAdapter = new AppleAdapter();
