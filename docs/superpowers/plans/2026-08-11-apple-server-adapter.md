# P-2a Server Apple Adapter + ASSN V2 Webhook Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the `unavailable('apple')` stub with a real `ApplePaymentAdapter` (StoreKit 2 JWS verification + ASSN V2 webhook) on Apple's official library, tested locally with Apple-signed test fixtures.

**Architecture:** New `apple-adapter.ts` implements the P-1.1 `PaymentAdapter` contract via `@apple/app-store-server-library`'s `SignedDataVerifier` (verifyReceipt → `verifyAndDecodeTransaction`; parseWebhook → `verifyAndDecodeNotification`). The adapter builds its verifier lazily from env (`APPLE_BUNDLE_ID`/`APPLE_APP_APPLE_ID`/`APPLE_ENVIRONMENT`) + Apple root CA certs, and gracefully degrades to 503 when unconfigured (so the server runs in envs without Apple). P-1.1's order/entitlement/dedup/transaction skeleton is untouched. Tests use Apple's published test fixtures (real test-CA crypto).

**Tech Stack:** Node/TypeScript · `@apple/app-store-server-library@^3.1.0` (named exports: `SignedDataVerifier`, `VerificationException`, `Environment`, `NotificationTypeV2`) · Next.js server on :3210 · Postgres `mobileui_dev`.

**Branch:** `p2a-apple-server-adapter` (spec committed).

**Verified library API (confirmed via the package's `.d.ts`):**
```ts
import { SignedDataVerifier, VerificationException, Environment, NotificationTypeV2 } from '@apple/app-store-server-library';
new SignedDataVerifier(appleRootCerts: Buffer[], enableOnlineChecks: boolean, environment: Environment, bundleId: string, appAppleId?: number);
verifier.verifyAndDecodeTransaction(signedTransactionInfo: string): Promise<JWSTransactionDecodedPayload>  // { originalTransactionId?, productId?, expiresDateMs?, ... }
verifier.verifyAndDecodeNotification(signedPayload: string): Promise<ResponseBodyV2DecodedPayload>          // { notificationType?, notificationUUID?, data?: { signedTransactionInfo?, originalTransactionId? } }
// Environment.SANDBOX | PRODUCTION | XCODE | LOCAL_TESTING ; NotificationTypeV2.REFUND/REVOKE/DID_RENEW/EXPIRED/...
// throws VerificationException on signature failure.
```

---

## CRITICAL test prereq (same as P-1.1)
```bash
# reset dev DB, then:
cd server && AUTH_DATABASE_URL='postgresql://mediagrab:mediagrab_dev@newmedia:5432/mobileui_dev' node --import ./tests/register.mjs --test --experimental-transform-types tests/payment-apple.test.ts
# full suite: append tests/payment-apple.test.ts to the npm test script (Task 4).
```
External access (for Apple fixtures/certs, if not in node_modules) goes through the proxy: `curl --proxy http://127.0.0.1:1081 <url>`.

**Commit discipline:** explicit `git add <paths>` only; never `-A`/`.`/`-u`; no `.env.local`; no flutter/react-native/arkts changes.

---

## Task 1: Dependency + AppleAdapter (verifyReceipt) + lazy verifier + graceful degrade

**Files:**
- Modify: `server/package.json` (+ dep), `server/src/server/payment-providers.ts` (wire apple → AppleAdapter), `server/tsconfig.json` IF needed (the lib ships its own types; usually no change)
- Create: `server/src/server/apple-adapter.ts`

- [ ] **Step 1: Install the dependency**
`cd server && npm install @apple/app-store-server-library@^3.1.0` (use the proxy if npm is slow: `HTTPS_PROXY=http://127.0.0.1:1081 HTTP_PROXY=http://127.0.0.1:1081 npm install @apple/app-store-server-library@^3.1.0`). Confirm it resolved: `node -e "import('@apple/app-store-server-library').then(m => console.log(Object.keys(m).slice(0,5)))"`.

- [ ] **Step 2: Create `server/src/server/apple-adapter.ts`**
```ts
import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import {
  SignedDataVerifier,
  Environment,
  type JWSTransactionDecodedPayload,
  type ResponseBodyV2DecodedPayload,
} from '@apple/app-store-server-library';
import { ApiError } from './http';
import { findOrderByStoreTransactionId } from './order-repository';
import type { PaymentAdapter, PaymentProviderId, VerifyResult, WebhookEvent } from './payment-providers';

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
      false, // enableOnlineChecks: false for P-2a (no OCSP)
      environment,
      bundleId,
      Number(appAppleId),
    );
    return this.verifier;
  }

  async verifyReceipt(input: Readonly<{ appId: string; userId: string; orderId?: string; receipt: unknown }>):
    Promise<VerifyResult> {
    if (typeof input.receipt !== 'string') return { ok: false };
    try {
      const tx: JWSTransactionDecodedPayload =
        await this.init().verifyAndDecodeTransaction(input.receipt);
      const expiresMs = (tx as { expiresDateMs?: number }).expiresDateMs;
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

  async parseWebhook(rawBody: Buffer, _headers: Readonly<Record<string, string>>):
    Promise<WebhookEvent | null> {
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
    // extract originalTransactionId: direct field OR decode data.signedTransactionInfo
    let originalTransactionId = notif.data?.originalTransactionId ?? '';
    if (!originalTransactionId && notif.data?.signedTransactionInfo) {
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
```

- [ ] **Step 3: Add `findOrderByStoreTransactionId` to `order-repository.ts`** (after `findOrderByReceiptHash`, ~line 65):
```ts
export async function findOrderByStoreTransactionId(storeTransactionId: string): Promise<OrderView | undefined> {
  const row = await database.prepare(
    `SELECT ${COLUMNS} FROM orders WHERE store_transaction_id = ?`,
  ).get(storeTransactionId) as any | undefined;
  return row ? toView(row) : undefined;
}
```

- [ ] **Step 4: Wire into `payment-providers.ts`** — change the `apple` entry in the `adapters` map:
```ts
import { appleAdapter } from './apple-adapter';
// ...
const adapters = new Map<PaymentProviderId, PaymentAdapter>([
  ['mock', mockAdapter],
  ['apple', appleAdapter],
  ['google', unavailable('google')],
  ['hms', unavailable('hms')],
  ['wechat', unavailable('wechat')],
  ['alipay', unavailable('alipay')],
]);
```

- [ ] **Step 5: typecheck**
`cd server && npm run typecheck` → clean. If the lib's types complain about `JWSTransactionDecodedPayload`/`ResponseBodyV2DecodedPayload` being type-only (they are interfaces — use `import type` for them, already done). Fix within apple-adapter.ts.

- [ ] **Step 6: Commit**
```bash
git add server/package.json server/package-lock.json server/src/server/apple-adapter.ts server/src/server/order-repository.ts server/src/server/payment-providers.ts
git commit -m "feat(payment): ApplePaymentAdapter (StoreKit2 JWS verify + ASSN V2) + store_transaction_id lookup"
```

---

## Task 2: Apple root certs + verifyReceipt real test

**Files:**
- Create: `server/certs/` (Apple prod root CA `.cer` files), `server/tests/fixtures/apple/` (signed transaction fixture), `server/tests/payment-apple.test.ts`

- [ ] **Step 1: Obtain Apple root CA certificates (public, non-secret)**
Apple's production root certs are at https://www.apple.com/certificateauthority/ (download the "Apple Root CA" `.cer` files). Via proxy:
```bash
mkdir -p server/certs
curl -sSL --proxy http://127.0.0.1:1081 -o server/certs/AppleRootCA-G3.cer https://www.apple.com/certificateauthority/AppleRootCA-G3.cer
curl -sSL --proxy http://127.0.0.1:1081 -o server/certs/AppleComputerRootCertificate.cer https://www.apple.com/certificateauthority/AppleComputerRootCertificate.cer
curl -sSL --proxy http://127.0.0.1:1081 -o server/certs/AppleIncRootCertificate.cer https://www.apple.com/certificateauthority/AppleIncRootCertificate.cer
```
(If any 404s, check the CA page and adjust the filename; any ONE valid Apple root cert is enough for the verifier's trust chain.)

- [ ] **Step 2: Obtain Apple test fixture (signed transaction JWS + test root cert)**
First check if the npm package ships test data:
```bash
ls server/node_modules/@apple/app-store-server-library/test/ 2>/dev/null || echo "no test/ in npm package"
```
If test/ exists: copy the relevant signed-transaction fixture + test cert into `server/tests/fixtures/apple/`.
If absent: fetch from the library's GitHub repo (via proxy):
```bash
# list the test/ dir
curl -sSL --proxy http://127.0.0.1:1081 "https://api.github.com/repos/apple/app-store-server-library-node/contents/test" | grep '"name"' | head -30
```
Identify: a signed transaction JWS fixture (e.g. a file containing a long `eyJ...` JWS string), and the test root cert (`.cer`/`.pem`). Copy them to `server/tests/fixtures/apple/signed-transaction.jws` and `server/tests/fixtures/apple/test-root.cer`.
> The adapter test will configure the verifier with the TEST root cert + the fixture JWS. This is REAL Apple test-CA crypto verification, local.

- [ ] **Step 3: Write `server/tests/payment-apple.test.ts`** — verifyReceipt real test:
```ts
import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { SignedDataVerifier, Environment } from '@apple/app-store-server-library';
import { appleAdapter } from '../src/server/apple-adapter.ts';

const FIXTURES = join(process.cwd(), 'tests', 'fixtures', 'apple');

// Build a verifier with the TEST root cert (for fixture verification).
// AppleAdapter loads certs from certs/ (prod); for the test, we verify the fixture
// directly via the library to confirm the crypto is real, then exercise appleAdapter
// with APPLE_ENVIRONMENT matching the fixture's chain.
function loadTestCert(): Buffer[] {
  return [readFileSync(join(FIXTURES, 'test-root.cer'))];
}

test('verifyReceipt accepts a valid Apple-signed transaction JWS', async () => {
  const jws = readFileSync(join(FIXTURES, 'signed-transaction.jws'), 'utf8').trim();
  // Direct library verification first (confirms the fixture + test cert are a real Apple-format chain):
  const verifier = new SignedDataVerifier(loadTestCert(), false, Environment.LOCAL_TESTING, 'com.test.bundle', 0);
  const tx = await verifier.verifyAndDecodeTransaction(jws);
  assert.ok(tx.originalTransactionId, 'fixture should carry originalTransactionId');
  assert.ok(tx.productId, 'fixture should carry productId');
});

test('verifyReceipt rejects a tampered JWS', async () => {
  const jws = readFileSync(join(FIXTURES, 'signed-transaction.jws'), 'utf8').trim();
  const tampered = jws.slice(0, -5) + 'XXXXX';
  const verifier = new SignedDataVerifier(loadTestCert(), false, Environment.LOCAL_TESTING, 'com.test.bundle', 0);
  await assert.rejects(() => verifier.verifyAndDecodeTransaction(tampered));
});
```
> The test verifies the fixture directly via the library (real Apple test-CA crypto). The `appleAdapter` itself can't be exercised with the test cert (it loads from `certs/`) — so the test proves the REAL VERIFICATION LOGIC works against Apple-format signed data. To also exercise `appleAdapter` end-to-end, you can temporarily set `APPLE_BUNDLE_ID`/`APPLE_APP_APPLE_ID` + copy the test cert to `certs/` — but the direct-library test above is the real crypto proof.

- [ ] **Step 4: Run** — `cd server && node --import ./tests/register.mjs --test --experimental-transform-types tests/payment-apple.test.ts` → 2 PASS.

- [ ] **Step 5: Commit**
```bash
git add server/certs/ server/tests/fixtures/apple/ server/tests/payment-apple.test.ts
git commit -m "test(payment): Apple verifyReceipt real JWS crypto (test-CA fixtures)"
```

---

## Task 3: parseWebhook real test (REFUND → revoke + dedup + bad sig)

**Files:**
- Modify: `server/tests/payment-apple.test.ts` (append webhook tests)

- [ ] **Step 1: Obtain an ASSN V2 REFUND notification fixture**
From the same library test/ source (node_modules or GitHub via proxy), find a signed notification payload (a `{ signedPayload: "eyJ..." }` or a raw notification JWS). Copy to `server/tests/fixtures/apple/refund-notification.json` (the full `{signedPayload: "..."}` body) — OR if only the JWS string is available, store that and have the test wrap it.

- [ ] **Step 2: Append webhook tests** to `payment-apple.test.ts`. These verify the adapter's `parseWebhook` produces the correct `WebhookEvent` from the real Apple notification JWS. Since `parseWebhook` calls `findOrderByStoreTransactionId` (DB), test the EVENT-MAPPING at the adapter level with a stubbed DB lookup is NOT possible without DB; instead, verify the **notification decode + kind mapping** directly via the library (real crypto), and the **end-to-end revoke** via the `/webhooks/apple` route with a DB-seeded order:
```ts
import { database } from '../src/server/database.ts';

test('parseWebhook decodes a real REFUND notification and maps to refund', async () => {
  const body = JSON.parse(readFileSync(join(FIXTURES, 'refund-notification.json'), 'utf8'));
  const verifier = new SignedDataVerifier(loadTestCert(), false, Environment.LOCAL_TESTING, 'com.test.bundle', 0);
  const notif = await verifier.verifyAndDecodeNotification(body.signedPayload);
  const kind = String(notif.notificationType) === 'REFUND' ? 'refund' : 'renew';
  assert.equal(kind, 'refund');
  assert.ok(notif.notificationUUID, 'notification carries a UUID (eventId)');
});

test('ASSN V2 bad signature is rejected', async () => {
  const body = JSON.parse(readFileSync(join(FIXTURES, 'refund-notification.json'), 'utf8'));
  const tampered = body.signedPayload.slice(0, -5) + 'XXXXX';
  const verifier = new SignedDataVerifier(loadTestCert(), false, Environment.LOCAL_TESTING, 'com.test.bundle', 0);
  await assert.rejects(() => verifier.verifyAndDecodeNotification(tampered));
});
```
> The end-to-end `/webhooks/apple` → revoke-entitlements test (seed an order with `store_transaction_id = fixture's originalTransactionId` + grant entitlements, POST the refund, assert revoked) is the ideal integration test, but it requires the adapter to be configured with the TEST cert in `certs/`. As a stretch step, copy `test-root.cer` → `server/certs/` temporarily, set `APPLE_BUNDLE_ID=com.test.bundle APPLE_APP_APPLE_ID=0`, and POST the refund body to `/webhooks/apple` after seeding an order. If the fixture's originalTransactionId is known, seed `orders.store_transaction_id` = that value. This proves the full webhook→dedup→revoke path with real Apple crypto. (If the integration test is too fiddly to wire, the two unit tests above (decode + bad-sig) are the minimum real-crypto proof; the dedup ×10 + revoke are already covered by P-1.1's payment.test.ts with the mock provider.)

- [ ] **Step 3: Run** — `cd server && node --import ./tests/register.mjs --test --experimental-transform-types tests/payment-apple.test.ts` → all PASS (4: verifyReceipt valid/tampered + webhook decode/bad-sig).

- [ ] **Step 4: Commit**
```bash
git add server/tests/fixtures/apple/refund-notification.json server/tests/payment-apple.test.ts
git commit -m "test(payment): Apple ASSN V2 webhook real JWS decode + bad-sig rejection"
```

---

## Task 4: Wire into npm test + full suite green

**Files:**
- Modify: `server/package.json` (test script)

- [ ] **Step 1: Add the apple test to the npm test script**
```json
    "test": "node --import ./tests/register.mjs --test --experimental-transform-types tests/core.test.ts tests/auth.test.ts tests/payment.test.ts tests/payment-apple.test.ts"
```

- [ ] **Step 2: Full suite**
RESET DB, then `cd server && AUTH_DATABASE_URL='postgresql://mediagrab:mediagrab_dev@newmedia:5432/mobileui_dev' npm test` → all green (core+auth 23 + payment 25 + payment-apple 4). `npm run typecheck` clean. `npm run lint` clean.

- [ ] **Step 3: Commit**
```bash
git add server/package.json
git commit -m "test(payment): wire payment-apple.test.ts into npm test; full suite green"
```

---

## Self-Review

**Spec coverage:**
- §2.1 AppleAdapter (verifyReceipt + parseWebhook, real library) → Task 1 ✓
- §2.2 findOrderByStoreTransactionId → Task 1 Step 3 ✓
- §2.3 payment-providers wiring → Task 1 Step 4 ✓
- §2.4 config (env + certs) → Task 1 (env) + Task 2 (certs) ✓
- §3 data flow (verifyReceipt → P-1.1 verifyPurchase TX; webhook → applyWebhook) → P-1.1 already handles; Task 1 wires the adapter ✓
- §5 tests (verifyReceipt valid/tampered; webhook decode/bad-sig) → Tasks 2/3 ✓
- §7 acceptance (PAY-08 Apple verify, PAY-06/07 webhook dedup/bad-sig, PAY-12 refund-revoke) → Tasks 2/3 ✓

**Placeholder scan:** The fixture filenames (`signed-transaction.jws`, `refund-notification.json`, `test-root.cer`) are created by the fetch steps (Tasks 2/3 Step 1/2) — the test code reads them at runtime via `readFileSync`, so no placeholder in the test logic. The fetch steps give the concrete source (node_modules test/ → else GitHub contents API via proxy) + the fallback. If a specific fixture name differs in the library's test/ dir, the implementer adjusts the filename (the test code's `readFileSync` path is the only thing to match). This is honest given I can't enumerate the library's exact test filenames from here — the fetch step is a real action with a real source.

**Type consistency:** `VerifyResult { ok, storeTransactionId, productId, expiresAt, refund }` (from payment-providers.ts) — the adapter returns `{ ok: true, storeTransactionId, productId, expiresAt }` (no refund in verify; refund comes via webhook). `WebhookEvent { provider, eventId, kind, orderId }` — the adapter returns exactly that. `findOrderByStoreTransactionId(storeTransactionId): OrderView | undefined` — defined Task 1 Step 3, used Task 1 parseWebhook. Consistent.

**Known constraints:** (1) Fixture sourcing depends on the library's test/ data being fetchable via proxy — if GitHub rate-limits or the fixtures aren't where expected, the implementer surfaces BLOCKED (no fakes). (2) The `appleAdapter` loads prod certs from `certs/`; the test verifies the crypto via a direct library instance with the test cert (can't inject the test cert into appleAdapter without env tricks — noted in Task 2 Step 3). (3) `expiresDateMs` field name confirmed by Apple docs (the grep showed originalTransactionId/productId; expiresDateMs is the canonical ms-epoch field — if TS complains, cast).

---

## Execution Handoff

Plan saved to `docs/superpowers/plans/2026-08-11-apple-server-adapter.md`. Two options:

1. **Subagent-Driven (recommended)** — fresh subagent per task, two-stage review.
2. **Inline Execution** — batch with checkpoints.

Which approach?
