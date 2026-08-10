# P-1.3a React Native Payment Client Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mirror the Flutter payment contract onto the RN client (models + apiClient methods + mock PaymentProvider + rewire purchase flow + fix the false-success bug + independent CheckoutScreen), and add vitest integration tests against the real Next.js server.

**Architecture:** New `react-native/src/payment/` (paymentModels, paymentProvider, mockPaymentProvider) mirroring `flutter/lib/payment/`. Refactor `src/data/apiClient.ts` to be node-importable (injectable platform + token sources with lazy RN defaults) so vitest can hit the real server. Rewire `useDataActions.purchase` to createOrder→provider.purchase→verifyPurchase→membershipCurrent with `purchaseState`. Add vitest for real-environment tests.

**Tech Stack:** React Native 0.86 / TypeScript 5.8 / vitest (node env, global fetch) · Next.js server on :3210 · Postgres `mobileui_dev`.

**Branch:** `p13a-rn-payment-client` (spec committed at `f7cf01d`).

---

## CRITICAL test prerequisite (every task that runs `vitest`)

Tests hit the REAL Next.js server. From repo root `/Volumes/MacMiniDisk/workspace/MobileStarter`:
```bash
# 1. Reset dev DB (run from server/)
cd server && node --input-type=module -e "import { Client } from 'pg'; const c = new Client({ connectionString: 'postgresql://mediagrab:mediagrab_dev@newmedia:5432/mobileui_dev' }); await c.connect(); await c.query('DROP SCHEMA public CASCADE'); await c.query('CREATE SCHEMA public'); await c.end(); console.log('RESET');" && cd ..
# 2. Start server
cd server && AUTH_DATABASE_URL='postgresql://mediagrab:mediagrab_dev@newmedia:5432/mobileui_dev' nohup npm run dev > /tmp/p13-server.log 2>&1 &
SERVER_PID=$!
cd ..
for i in $(seq 1 60); do curl -sf http://localhost:3210/api/v1/health/live >/dev/null && break; sleep 1; done
# 3. (run vitest below from react-native/)
# 4. Stop server
kill $SERVER_PID 2>/dev/null || true
```
Run vitest from `react-native/` with the env prefix (apiClient's APP_ID/ENVIRONMENT throw at import if unset):
```bash
cd react-native && EXPO_PUBLIC_APP_ID=zhongbei EXPO_PUBLIC_APP_ENVIRONMENT=development EXPO_PUBLIC_API_URL=http://localhost:3210 npx vitest run
cd ..
```
`npm run typecheck` from `react-native/` (no server).

**Commit discipline:** explicit `git add <paths>` only; never `-A`/`.`/`-u`. Working tree is clean.

---

## File Structure

**Create**: `src/data/runtimePlatform.ts`, `src/payment/paymentModels.ts`, `src/payment/paymentProvider.ts`, `src/payment/mockPaymentProvider.ts`, `src/screens/CheckoutScreen.tsx`, `src/__tests__/testServer.ts`, `src/__tests__/apiClient.test.ts`, `src/__tests__/paymentModels.test.ts`, `src/__tests__/paymentProvider.test.ts`, `src/__tests__/purchaseFlow.test.ts`, `vitest.config.ts`.
**Modify**: `src/data/apiClient.ts` (refactor + new methods), `src/domain/models.ts` (BillingPlan + OrderView/OrderStatus), `src/state/useDataActions.ts` (purchase rewire), `src/state/AppStore.tsx` (purchaseState + purchase action), `src/screens/MembershipScreen.tsx` (→ checkout), `src/screens/DataScreens.tsx` (statusLabel enum), `src/navigation/routes.ts` (+ checkout wiring), `App.tsx` (setPlatformHeader), `package.json` (+ vitest + test script).

---

## Task 1: vitest + apiClient node-importable refactor

**Files:**
- Create: `react-native/src/data/runtimePlatform.ts`, `react-native/vitest.config.ts`, `react-native/src/__tests__/testServer.ts`, `react-native/src/__tests__/apiClient.test.ts`
- Modify: `react-native/src/data/apiClient.ts`, `react-native/App.tsx`, `react-native/package.json`

- [ ] **Step 1: Create `src/data/runtimePlatform.ts`** (pure TS — no react-native import)
```ts
// Platform is injected at runtime: the RN App entry calls setPlatformHeader(Platform.OS),
// tests call setPlatformHeader('ios') (the server only maps ios/android/harmonyos → store key).
let platform = 'web';
export function setPlatformHeader(value: string) { platform = value; }
export function getPlatformHeader() { return platform; }
```

- [ ] **Step 2: Refactor `src/data/apiClient.ts`** — apply these exact edits:

(a) REMOVE the imports at the top:
```ts
import { Platform } from 'react-native';
import {
  readAnonymousId,
  readRefreshToken,
  readSessionToken,
  saveRefreshToken,
  saveSessionToken,
} from './storage';
```
(b) ADD imports:
```ts
import { getPlatformHeader } from './runtimePlatform';
```
(c) Replace the `apiBase` const with a request-time getter (line 39-40):
```ts
function getApiBase() {
  return process.env.EXPO_PUBLIC_API_URL
    ?? (getPlatformHeader() === 'android' ? 'http://10.0.2.2:3210' : 'http://localhost:3210');
}
```
(d) Replace every `${Platform.OS} · MobileUI` deviceName with `${getPlatformHeader()} · MobileUI` (signIn, signUp, socialSignIn, verifyPhoneCode).
(e) In `clientHeaders()` (line 335-343), replace `'X-Platform': Platform.OS` with `'X-Platform': getPlatformHeader()`.
(f) Replace every `apiBase` reference with `getApiBase()` (in `sendRequest`'s fetch URL and `performRefresh`'s fetch URL).
(g) Add swappable token/anonymous providers + lazy defaults (append near the top of the module, after `apiClient` object or before `requestAuth`):
```ts
// Token/anonymous sources are injectable so the HTTP layer is node-testable
// (RN storage imports react-native/expo modules that don't load in node).
// Defaults lazily load the RN implementation only when actually used.
type Reader = () => Promise<string | null>;
let sessionTokenReader: Reader = () => import('./storage').then((m) => m.readSessionToken());
let refreshTokenReader: Reader = () => import('./storage').then((m) => m.readRefreshToken());
let anonymousIdReader: Reader = () => import('./storage').then((m) => m.readAnonymousId());
let sessionTokenWriter: (token: string | null) => Promise<void> =
  (token) => import('./storage').then((m) => m.saveSessionToken(token));
let refreshTokenWriter: (token: string | null) => Promise<void> =
  (token) => import('./storage').then((m) => m.saveRefreshToken(token));

export function setSessionTokenReader(reader: Reader) { sessionTokenReader = reader; }
export function setRefreshTokenReader(reader: Reader) { refreshTokenReader = reader; }
export function setAnonymousIdReader(reader: Reader) { anonymousIdReader = reader; }
export function setSessionTokenWriter(writer: (token: string | null) => Promise<void>) { sessionTokenWriter = writer; }
export function setRefreshTokenWriter(writer: (token: string | null) => Promise<void>) { refreshTokenWriter = writer; }
```
(h) In `sendRequest` (line 214-217), replace:
```ts
  const [token, installationId] = await Promise.all([
    readSessionToken(),
    readAnonymousId(),
  ]);
```
with:
```ts
  const [token, installationId] = await Promise.all([
    sessionTokenReader(),
    anonymousIdReader(),
  ]);
```
(i) In `performRefresh` (lines 275, 287-288), replace `readRefreshToken()` → `refreshTokenReader()`, `saveSessionToken(data.token)` → `sessionTokenWriter(data.token)`, `saveRefreshToken(data.refreshToken)` → `refreshTokenWriter(data.refreshToken)`.
> After this, `apiClient.ts` has NO top-level `react-native`/`expo`/storage import — it's pure TS + global `fetch`, so node/vitest can import it.

- [ ] **Step 3: Wire production platform in `App.tsx`** — add at the top of the component body (after imports):
```ts
import { Platform } from 'react-native';
import { setPlatformHeader } from './src/data/runtimePlatform';
setPlatformHeader(Platform.OS);
```
(Module-level call is fine — it runs before any API request.)

- [ ] **Step 4: Add vitest** — `package.json` devDependencies add `"vitest": "^3.2.4"` and scripts add `"test": "vitest run"`. Then `npm install` (in `react-native/`). Create `vitest.config.ts`:
```ts
import { defineConfig } from 'vitest/config';
export default defineConfig({
  test: { environment: 'node', include: ['src/**/*.test.ts'] },
});
```

- [ ] **Step 5: Create test helper `src/__tests__/testServer.ts`**
```ts
// Real-server test helper (mirrors flutter/test/payment/test_server.dart).
const apiBase = process.env.EXPO_PUBLIC_API_URL ?? 'http://localhost:3210';
const appId = process.env.EXPO_PUBLIC_APP_ID;
const appEnv = process.env.EXPO_PUBLIC_APP_ENVIRONMENT;

export async function signUpAndGetToken(email: string): Promise<string> {
  const response = await fetch(`${apiBase}/api/v1/auth/sign-up`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'x-app-id': appId,
      'x-app-environment': appEnv,
      'x-platform': 'ios',
    },
    body: JSON.stringify({
      email,
      password: 'Test1234',
      username: email.split('@')[0].slice(0, 24),
      consentVersion: '2026-07-29',
    }),
  });
  if (response.status !== 201) {
    throw new Error(`sign-up failed (${response.status}): ${await response.text()}`);
  }
  const body = await response.json() as { data: { token: string } };
  return body.data.token;
}
```
(The server returns the token at `data.token`; username truncated to ≤24 per the server schema.)

- [ ] **Step 6: Write a real-server smoke test `src/__tests__/apiClient.test.ts`**
```ts
import { beforeAll, describe, expect, it } from 'vitest';
import { apiClient, setAnonymousIdReader, setPlatformHeader, setRefreshTokenReader, setSessionTokenReader, setSessionTokenWriter, setRefreshTokenWriter } from '../data/apiClient';
import { signUpAndGetToken } from './testServer';

describe('apiClient (real server)', () => {
  let token: string;
  beforeAll(async () => {
    setPlatformHeader('ios');
    setAnonymousIdReader(async () => 'test-installation');
    setRefreshTokenReader(async () => null);
    setSessionTokenReader(async () => token);
    setSessionTokenWriter(async () => {});
    setRefreshTokenWriter(async () => {});
    token = await signUpAndGetToken(`p13-api-${Date.now()}@test.local`);
  });

  it('bootstrap returns a config', async () => {
    const boot = await apiClient.bootstrap();
    expect(boot.config?.plans?.length ?? 0).toBeGreaterThan(0);
  });

  it('orders() returns an empty list for a fresh user', async () => {
    const orders = await apiClient.orders();
    expect(orders).toHaveLength(0);
  });
});
```

- [ ] **Step 7: Run — server prereq + verify PASS**
Run the CRITICAL prereq (reset DB → start server → wait health), then:
```bash
cd react-native && EXPO_PUBLIC_APP_ID=zhongbei EXPO_PUBLIC_APP_ENVIRONMENT=development EXPO_PUBLIC_API_URL=http://localhost:3210 npx vitest run
cd ..
```
Expected: 2 tests PASS (bootstrap + orders against the real server). Then `cd react-native && npm run typecheck` → clean. Then kill server.

- [ ] **Step 8: Commit**
```bash
git add react-native/src/data/runtimePlatform.ts react-native/src/data/apiClient.ts react-native/App.tsx react-native/package.json react-native/package-lock.json react-native/vitest.config.ts react-native/src/__tests__/testServer.ts react-native/src/__tests__/apiClient.test.ts
git commit -m "feat(rn): node-importable apiClient (injectable platform/token) + vitest real-server smoke"
```

---

## Task 2: Payment models (mirror Flutter payment_models.dart)

**Files:**
- Create: `react-native/src/payment/paymentModels.ts`
- Modify: `react-native/src/domain/models.ts` (`BillingPlan`:41-50, `OrderView`:219-228), `react-native/src/screens/DataScreens.tsx` (`statusLabel`:129-136)
- Test: `react-native/src/__tests__/paymentModels.test.ts`

- [ ] **Step 1: Create `src/payment/paymentModels.ts`**
```ts
export type StoreProductMapping = Readonly<{ apple?: string; google?: string; hms?: string }>;

export type StoreProduct = Readonly<{ storeProductId: string; title?: string }>;

export type PurchaseResult = Readonly<{ storeProductId: string; receipt: unknown }>;

export type Entitlement = Readonly<{ key: string; expiresAt: string | null }>;

export type Subscription = Readonly<{ planId: string; status: string; renewAt: string | null }>;

export type MembershipCurrent = Readonly<{
  tier: string | null;
  entitlements: readonly Entitlement[];
  subscription: Subscription | null;
}>;

export type CreateOrderResult = Readonly<{
  orderId: string;
  storeProductId: string;
  status: string;
}>;

export type OrderStatus = 'pending' | 'processing' | 'success' | 'failed' | 'refunded';

export function parseOrderStatus(value: string): OrderStatus {
  return (['pending', 'processing', 'success', 'failed', 'refunded'] as const)
    .includes(value as OrderStatus) ? value as OrderStatus : 'pending';
}
```

- [ ] **Step 2: Extend `src/domain/models.ts`**
- `BillingPlan` (line 41): add `storeProductMapping?: StoreProductMapping;` to the type, and add the import `import { StoreProductMapping } from '../payment/paymentModels';` at the top.
- `OrderView` (line 219): change `status: string` → `status: OrderStatus`. Add import `import { OrderStatus } from '../payment/paymentModels';` (or reference via the existing models import). Confirm the `fromJson`/`toClient` mapping that constructs OrderView sets `status: parseOrderStatus(row.status)` — read the OrderView construction site and apply `parseOrderStatus`.

- [ ] **Step 3: Update `src/screens/DataScreens.tsx` `statusLabel`** (lines 129-136) to map the enum:
```ts
const statusLabel = (status: OrderStatus): string => ({
  pending: '待支付', processing: '处理中', success: '已生效', failed: '失败', refunded: '已退款',
}[status] ?? status);
```
Update its call sites (they pass `order.status` which is now `OrderStatus`). If the current `statusLabel` is a string-keyed map over the old string status, replace it; grep `statusLabel(` to update all callers.

- [ ] **Step 4: Write test `src/__tests__/paymentModels.test.ts`**
```ts
import { describe, expect, it } from 'vitest';
import { parseOrderStatus, type CreateOrderResult } from '../payment/paymentModels';
import type { BillingPlan, OrderView } from '../domain/models';

describe('payment models', () => {
  it('parseOrderStatus maps known values and defaults unknown to pending', () => {
    expect(parseOrderStatus('success')).toBe('success');
    expect(parseOrderStatus('refunded')).toBe('refunded');
    expect(parseOrderStatus('weird')).toBe('pending');
  });

  it('BillingPlan carries storeProductMapping', () => {
    const plan: BillingPlan = {
      id: 'pro-monthly', tierId: 'pro', name: 'Pro', interval: 'month',
      priceMinor: 1800, currency: 'CNY', provider: 'mock',
      storeProductMapping: { apple: 'com.x.pro', google: 'pro_g', hms: 'pro_h' },
    };
    expect(plan.storeProductMapping?.apple).toBe('com.x.pro');
  });

  it('OrderView.status is a typed OrderStatus', () => {
    const order: OrderView = {
      id: 'o1', planId: 'pro-monthly', status: parseOrderStatus('success'),
      amountMinor: 1800, currency: 'CNY', provider: 'mock', createdAt: 'now', completedAt: null,
    };
    expect(order.status).toBe('success');
  });

  it('CreateOrderResult shape', () => {
    const r: CreateOrderResult = { orderId: 'o1', storeProductId: 'com.x.pro', status: 'pending' };
    expect(r.storeProductId).toBe('com.x.pro');
  });
});
```
Read `OrderView`'s exact fields first and match them (add/omit fields as the real type has).

- [ ] **Step 5: Run — typecheck + vitest (models test is pure; run without server)**
`cd react-native && npm run typecheck` → clean. `EXPO_PUBLIC_APP_ID=zhongbei EXPO_PUBLIC_APP_ENVIRONMENT=development EXPO_PUBLIC_API_URL=http://localhost:3210 npx vitest run src/__tests__/paymentModels.test.ts` → PASS. (This test doesn't hit the server; the env vars are still needed because importing `apiClient` in the OTHER test file requires them — actually this test doesn't import apiClient, so run vitest without the server: `npx vitest run src/__tests__/paymentModels.test.ts` — env vars only needed if something imports apiClient. If it fails on env, add them.)

- [ ] **Step 6: Commit**
```bash
git add react-native/src/payment/paymentModels.ts react-native/src/domain/models.ts react-native/src/screens/DataScreens.tsx react-native/src/__tests__/paymentModels.test.ts
git commit -m "feat(rn): payment models + BillingPlan.storeProductMapping + OrderView OrderStatus"
```

---

## Task 3: PaymentProvider + MockPaymentProvider + apiClient payment methods

**Files:**
- Create: `react-native/src/payment/paymentProvider.ts`, `react-native/src/payment/mockPaymentProvider.ts`
- Modify: `react-native/src/data/apiClient.ts` (add methods)
- Test: `react-native/src/__tests__/paymentProvider.test.ts`

- [ ] **Step 1: Create `src/payment/paymentProvider.ts`**
```ts
import type { PurchaseResult, StoreProduct, StoreProductMapping } from './paymentModels';

export interface PaymentProvider {
  loadProducts(mapping: StoreProductMapping | null): Promise<readonly StoreProduct[]>;
  purchase(storeProductId: string): Promise<PurchaseResult>;
  restore(): Promise<readonly PurchaseResult[]>;
}
```

- [ ] **Step 2: Create `src/payment/mockPaymentProvider.ts`** (mirrors Flutter's, `failPurchases` field = sandbox failure mode, no test-double subclass)
```ts
import type { PurchaseResult, StoreProduct, StoreProductMapping } from './paymentModels';
import type { PaymentProvider } from './paymentProvider';

export class MockPaymentProvider implements PaymentProvider {
  failPurchases = false;
  private readonly owned = new Set<string>();

  async loadProducts(mapping: StoreProductMapping | null): Promise<readonly StoreProduct[]> {
    if (!mapping) return [];
    return [
      ...(mapping.apple ? [{ storeProductId: mapping.apple }] : []),
      ...(mapping.google ? [{ storeProductId: mapping.google }] : []),
      ...(mapping.hms ? [{ storeProductId: mapping.hms }] : []),
    ];
  }

  async purchase(storeProductId: string): Promise<PurchaseResult> {
    const receipt: Record<string, unknown> = { productId: storeProductId };
    if (this.failPurchases) receipt.fail = true;
    else this.owned.add(storeProductId);
    return { storeProductId, receipt };
  }

  async restore(): Promise<readonly PurchaseResult[]> {
    return [...this.owned].map((id) => ({
      storeProductId: id,
      receipt: { productId: id },
    }));
  }
}
```

- [ ] **Step 3: Add methods to `apiClient`** (inside the `apiClient` object, next to `purchase`):
```ts
  createOrder: (planId: string, idempotencyKey: string) => request<CreateOrderResult>(
    '/api/v1/orders',
    {
      ...jsonOptions('POST', { planId }),
      headers: {
        ...clientHeaders(),
        'Content-Type': 'application/json',
        'Idempotency-Key': idempotencyKey,
      },
    },
  ),
  verifyPurchase: (orderId: string | undefined, receipt: unknown) => request<OrderView>(
    '/api/v1/purchases/verify',
    jsonOptions('POST', { ...(orderId ? { orderId } : {}), receipt }),
  ),
  restore: (receipts: unknown[]) => request<{ entitlements: readonly string[] }>(
    '/api/v1/purchases/restore',
    jsonOptions('POST', { receipts }),
  ),
  membershipCurrent: () => request<MembershipCurrent>('/api/v1/membership/current'),
  entitlements: () => request<{ keys: readonly string[] }>('/api/v1/membership/entitlements'),
```
Add imports: `CreateOrderResult`, `MembershipCurrent` from `../payment/paymentModels` (and `OrderStatus` is already in models). **Remove the old `purchase(planId)` method** (lines 134-144).

- [ ] **Step 4: Write test `src/__tests__/paymentProvider.test.ts`** (pure)
```ts
import { describe, expect, it } from 'vitest';
import { MockPaymentProvider } from '../payment/mockPaymentProvider';

describe('MockPaymentProvider', () => {
  it('purchase returns a receipt with the productId', async () => {
    const p = new MockPaymentProvider();
    const r = await p.purchase('com.x.pro');
    expect(r.storeProductId).toBe('com.x.pro');
    expect((r.receipt as { productId: string }).productId).toBe('com.x.pro');
  });

  it('failPurchases=true yields a fail receipt', async () => {
    const p = new MockPaymentProvider();
    p.failPurchases = true;
    const r = await p.purchase('com.x.pro');
    expect((r.receipt as { fail: boolean }).fail).toBe(true);
  });

  it('restore replays purchased products', async () => {
    const p = new MockPaymentProvider();
    await p.purchase('com.x.pro');
    await p.purchase('pro_g');
    const restored = await p.restore();
    expect(restored.map((r) => r.storeProductId).sort()).toEqual(['com.x.pro', 'pro_g']);
  });
});
```

- [ ] **Step 5: Run — typecheck + provider test (pure, no server)**
`cd react-native && npm run typecheck` → clean. `npx vitest run src/__tests__/paymentProvider.test.ts` → PASS. (If `apiClient.ts` change breaks typecheck, fix within apiClient — e.g. ensure the removed `purchase` isn't referenced elsewhere: `grep -rn "apiClient.purchase\|\.purchase(" react-native/src`.)

- [ ] **Step 6: Commit**
```bash
git add react-native/src/payment/paymentProvider.ts react-native/src/payment/mockPaymentProvider.ts react-native/src/data/apiClient.ts react-native/src/__tests__/paymentProvider.test.ts
git commit -m "feat(rn): PaymentProvider + MockPaymentProvider + apiClient payment methods"
```

---

## Task 4: Rewire purchase flow + purchaseState

**Files:**
- Modify: `react-native/src/state/useDataActions.ts` (`purchase`:76-82), `react-native/src/state/AppStore.tsx`
- Test: `react-native/src/__tests__/purchaseFlow.test.ts`

- [ ] **Step 1: Add `purchaseState` + `purchase`/`restorePurchases` to `AppStore.tsx`** — read AppStore first. Add an `AsyncState`-style discriminated union (mirror CODE_RULES 7-state) if not present, or reuse existing state conventions. Concretely:
```ts
export type PurchaseState =
  | { kind: 'idle' } | { kind: 'loading' }
  | { kind: 'success'; order: OrderView } | { kind: 'failed'; order: OrderView }
  | { kind: 'error'; message: string } | { kind: 'offline' } | { kind: 'unauthorized' };
```
Wire it into `useApp()` with `purchaseState` + `restorePurchases`. (Read AppStore's existing structure — it has `busy`, `run`, `setUser`, `showToast` — and integrate accordingly.)

- [ ] **Step 2: Rewrite `purchase` in `useDataActions.ts`** — replace lines 76-82:
```ts
    purchase: async (planId: string) => {
      try {
        const idempotencyKey = `rn-${Date.now()}-${Math.random().toString(36).slice(2)}`;
        const order = await run(() => apiClient.createOrder(planId, idempotencyKey));
        const provider = new MockPaymentProvider();
        const result = await provider.purchase(order.storeProductId);
        const verified = await run(() => apiClient.verifyPurchase(order.orderId, result.receipt));
        if (verified.status === 'success') {
          setUser((await run(apiClient.bootstrap)).user);
        }
        // reflect the REAL outcome: purchaseState success/failed by order.status
        setPurchaseState(verified.status === 'success'
          ? { kind: 'success', order: verified }
          : { kind: 'failed', order: verified });
        return verified.status === 'success';
      } catch { return false; }
    },
```
> Requires `setPurchaseState` (from AppStore) passed into `useDataActions` and `MockPaymentProvider` imported. The old `apiClient.purchase` call is gone — this fixes the false-success bug (a `failed`/`pending` order no longer returns true / shows success).

- [ ] **Step 3: Write real-server test `src/__tests__/purchaseFlow.test.ts`** (mirrors Flutter's controller test):
```ts
import { beforeAll, describe, expect, it } from 'vitest';
import { apiClient, setAnonymousIdReader, setPlatformHeader, setRefreshTokenReader, setSessionTokenReader } from '../data/apiClient';
import { MockPaymentProvider } from '../payment/mockPaymentProvider';
import { signUpAndGetToken } from './testServer';

describe('purchase flow (real server)', () => {
  let token: string;
  beforeAll(async () => {
    setPlatformHeader('ios');
    setAnonymousIdReader(async () => 'test-installation');
    setRefreshTokenReader(async () => null);
    setSessionTokenReader(async () => token);
    token = await signUpAndGetToken(`p13-flow-${Date.now()}@test.local`);
  });

  it('createOrder → mock purchase → verify → success + entitlements', async () => {
    const order = await apiClient.createOrder('pro-monthly', `flow-${Date.now()}`);
    expect(order.status).toBe('pending');
    expect(order.storeProductId).toBeTruthy();

    const provider = new MockPaymentProvider();
    const result = await provider.purchase(order.storeProductId);
    const verified = await apiClient.verifyPurchase(order.orderId, result.receipt);
    expect(verified.status).toBe('success');

    const mc = await apiClient.membershipCurrent();
    expect(mc.entitlements.length).toBeGreaterThan(0);
  });

  it('failPurchases → order failed, no entitlements', async () => {
    const order = await apiClient.createOrder('pro-monthly', `flow-fail-${Date.now()}`);
    const provider = new MockPaymentProvider();
    provider.failPurchases = true;
    const result = await provider.purchase(order.storeProductId);
    const verified = await apiClient.verifyPurchase(order.orderId, result.receipt);
    expect(verified.status).toBe('failed');
    const mc = await apiClient.membershipCurrent();
    expect(mc.entitlements.length).toBe(0);
  });
});
```

- [ ] **Step 4: Run — server prereq + verify PASS**
Run the CRITICAL prereq, then `cd react-native && EXPO_PUBLIC_APP_ID=zhongbei EXPO_PUBLIC_APP_ENVIRONMENT=development EXPO_PUBLIC_API_URL=http://localhost:3210 npx vitest run`. Expected: ALL tests pass (Task 1 smoke 2 + Task 2 models 4 + Task 3 provider 3 + Task 4 flow 2 = 11). Then `npm run typecheck` clean. Kill server.

- [ ] **Step 5: Commit**
```bash
git add react-native/src/state/useDataActions.ts react-native/src/state/AppStore.tsx react-native/src/__tests__/purchaseFlow.test.ts
git commit -m "feat(rn): rewire purchase to createOrder→verify flow + purchaseState (fix false-success)"
```

---

## Task 5: CheckoutScreen + MembershipScreen wiring

**Files:**
- Create: `react-native/src/screens/CheckoutScreen.tsx`
- Modify: `react-native/src/screens/MembershipScreen.tsx` (`buy`:14-21), `react-native/src/navigation/routes.ts` (+ checkout wiring if a screen map exists)

- [ ] **Step 1: Create `src/screens/CheckoutScreen.tsx`** (mirror Flutter's; reads the selected plan + runs purchase, branches on `purchaseState.order.status`)
```tsx
import React from 'react';
import { ScrollView, StyleSheet, Text, View } from 'react-native';
import { AppButton, AppCard, PageHeader } from '../design-system/components';
import { useApp } from '../state/AppStore';
import { colors, radii, spacing } from '../theme/tokens';
import { styles } from '../theme/styles';
import { PrimaryTabs } from '../navigation/PrimaryTabs';

export function CheckoutScreen() {
  const { config, navigate, purchaseState, purchase, busy, showToast } = useApp();
  // selected plan comes via the pending selection (mirror Flutter's pendingPlanId)
  const selectedPlanId = usePendingPlanId(); // see Step 2 — read from a shared pending-plan holder
  const plan = config.plans.find((p) => p.id === selectedPlanId);
  const start = async () => {
    if (!selectedPlanId) return;
    const ok = await purchase(selectedPlanId);
    if (purchaseState?.kind === 'failed') showToast('订阅验证失败，请重试', 'error');
    else if (ok) showToast('订阅成功', 'success');
  };
  const st = purchaseState?.kind;
  return (
    <View style={styles.page}>
      <PageHeader title="确认订阅" />
      <ScrollView contentContainerStyle={styles.scrollContent}>
        <AppCard>
          <Text style={styles.heading}>{plan?.name ?? selectedPlanId}</Text>
          {plan ? <Text style={styles.secondary}>{formatPrice(plan)}</Text> : null}
          {plan?.provider === 'mock' ? <Text style={styles.caption}>演示支付：通过模拟渠道完成。</Text> : null}
        </AppCard>
        {st === 'loading' ? (
          <AppButton disabled label="正在确认…" icon="crown" onPress={() => {}} />
        ) : st === 'success' ? (
          <AppButton label="完成" icon="check" onPress={() => navigate('membership.home')} />
        ) : st === 'failed' ? (
          <AppButton label="重试" icon="crown" onPress={() => void start()} />
        ) : (
          <AppButton disabled={busy} label="确认订阅" icon="crown" onPress={() => void start()} />
        )}
      </ScrollView>
      <PrimaryTabs active="membership" />
    </View>
  );
}
```
> The `usePendingPlanId` + `pendingPlanId` holder and the `formatPrice` helper must be defined/exported (move `formatPrice` from MembershipScreen or duplicate it). Wire the selected plan from MembershipScreen into a shared pending-plan state (mirror Flutter's `PaymentController.pendingPlanId`). Read the existing navigation/screen-registration pattern and wire `membership.checkout` → `CheckoutScreen` (there's likely a route→screen map in `navigation/`; find it — grep `membership.checkout`).

- [ ] **Step 2: Modify `MembershipScreen.tsx` `buy()`** (lines 14-21) — instead of calling `purchase` directly + toasting, set the pending plan and navigate:
```tsx
  const buy = () => {
    if (!user) { navigate('auth.signIn'); return; }
    if (!selected) return;
    setPendingPlanId(selected);
    navigate('membership.checkout');
  };
```
(Keep the mock-disclaimer UI + button. Remove the direct `await purchase(selected)` + success toast — that path now lives in CheckoutScreen.)

- [ ] **Step 3: Verify — typecheck**
`cd react-native && npm run typecheck` → clean. Fix any navigation/screen-map integration (read the router to wire `CheckoutScreen`; grep `membership.checkout` and the screen map).

- [ ] **Step 4: Commit**
```bash
git add react-native/src/screens/CheckoutScreen.tsx react-native/src/screens/MembershipScreen.tsx react-native/src/navigation/routes.ts
# plus any navigation/screen-map file you touched to register CheckoutScreen
git commit -m "feat(rn): CheckoutScreen + MembershipScreen → checkout flow"
```

---

## Task 6: Ownership + idempotency + restore tests + full green

**Files:**
- Modify: `react-native/src/__tests__/purchaseFlow.test.ts` (append)

- [ ] **Step 1: Append tests** to `purchaseFlow.test.ts`:
```ts
  it('verify rejects another user order (ORDER_NOT_FOUND)', async () => {
    const ownerToken = await signUpAndGetToken(`p13-own-${Date.now()}@test.local`);
    // use a separate client with the owner token (reset readers for this block)
    setSessionTokenReader(async () => ownerToken);
    const owner = await apiClient.createOrder('pro-monthly', `own-${Date.now()}`);
    // switch back to the attacker token (the original `token`)
    setSessionTokenReader(async () => token);
    await expect(
      apiClient.verifyPurchase(owner.orderId, { productId: owner.storeProductId }),
    ).rejects.toThrow();
  });

  it('same idempotencyKey → same orderId', async () => {
    const key = `idem-${Date.now()}`;
    const a = await apiClient.createOrder('pro-monthly', key);
    const b = await apiClient.createOrder('pro-monthly', key);
    expect(a.orderId).toBe(b.orderId);
  });

  it('restore replays purchases', async () => {
    const order = await apiClient.createOrder('pro-monthly', `restore-${Date.now()}`);
    const provider = new MockPaymentProvider();
    await provider.purchase(order.storeProductId);
    const receipts = (await provider.restore()).map((r) => r.receipt);
    const keys = await apiClient.restore(receipts);
    expect(keys.length).toBeGreaterThan(0);
  });
```

- [ ] **Step 2: Run — server prereq + FULL suite green**
Run the CRITICAL prereq, then `cd react-native && EXPO_PUBLIC_APP_ID=zhongbei EXPO_PUBLIC_APP_ENVIRONMENT=development EXPO_PUBLIC_API_URL=http://localhost:3210 npx vitest run` → ALL pass (11 + 3 = 14). `npm run typecheck` clean. Kill server.

- [ ] **Step 3: Commit**
```bash
git add react-native/src/__tests__/purchaseFlow.test.ts
git commit -m "test(rn): cross-user ownership + idempotency + restore; full suite green"
```

---

## Self-Review

**Spec coverage:**
- §2.1 models (storeProductMapping, OrderStatus, Entitlement/Subscription/MembershipCurrent/CreateOrderResult) → Task 2 ✓
- §2.2 apiClient node-importable refactor (platform + token injection) → Task 1 ✓
- §2.3 API methods (createOrder/verifyPurchase/restore/membershipCurrent/entitlements) → Task 3 ✓
- §2.4 PaymentProvider + MockPaymentProvider → Task 3 ✓
- §2.5 state flow rewire + purchaseState + false-success fix → Task 4 ✓
- §2.6 CheckoutScreen + MembershipScreen → Task 5 ✓
- §5 vitest real-server tests (flow/failure/idempotent/ownership/restore/models) → Tasks 2/4/6 ✓
- Bug fix (no false-success toast) → Task 4 ✓

**Placeholder scan:** The `usePendingPlanId`/`pendingPlanId` in Task 5 is a named seam with instructions to wire it from MembershipScreen (mirror Flutter's pendingPlanId) — concrete enough (the implementer reads the navigation pattern). `AppStore.tsx` Step 1 references the existing `busy/run/showToast` structure with instruction to read it — concrete (it exists; the implementer integrates). No TBD/TODO.

**Type consistency:** `OrderStatus` defined Task 2, used Task 3 (`verified.status === 'success'`), Task 4, Task 6 — consistent. `CreateOrderResult`/`MembershipCurrent` defined Task 2, used Task 3/4 — consistent. `MockPaymentProvider` defined Task 3, used Task 4/6 — consistent. `setPlatformHeader`/`setSessionTokenReader` etc. defined Task 1, used in every test — consistent.

**Known constraints:** RN has no `Platform`/SecureStore in node — solved by the Task 1 injection seams (the only non-"real" adapters, mirroring Flutter's InMemoryTokenStore). The RN `AppStore.tsx` purchaseState integration requires reading AppStore's existing structure (concrete instruction, not a placeholder).

---

## Execution Handoff

Plan saved to `docs/superpowers/plans/2026-08-11-payment-rn-client.md`. Two options:

1. **Subagent-Driven (recommended)** — fresh subagent per task, two-stage review.
2. **Inline Execution** — batch with checkpoints.

Which approach?
