# P-1.3b ArkTS Payment Client Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mirror the payment contract onto the ArkTS/HarmonyOS client (models + ApiClient methods + mock PaymentProvider + AppStore purchase action + CheckoutPage), fixing the 3 baseline ArkTS compile errors first.

**Architecture:** Third mirror of the payment contract (after Flutter P-1.2, RN P-1.3a). New `arkts/entry/src/main/ets/payment/` (PaymentProvider + MockPaymentProvider). Extend `Models.ets` (storeProductMapping, OrderStatus, Entitlement/Subscription/MembershipCurrent/CreateOrderResult), `ApiClient.ets` (5 methods + import fix), `ApiTransport.ets` (per-request headers for Idempotency-Key), `AppStore.ets` (purchase + purchaseState), `CheckoutPage.ets` (new) + `MembershipPage` + `Index.ets` wiring. Fix `LaunchPages.ets` baseline regression.

**Tech Stack:** ArkTS / ArkUI · HarmonyOS SDK (local, via DevEco Studio's `hvigorw`) · Next.js server on :3210.

**Branch:** `p13b-arkts-payment-client` (spec committed).

**Verification = hvigor BUILD GATE (compile-level, NOT runtime).** ArkTS has no hypium/emulator here, so there are NO unit/integration tests. Each task's gate is: `assembleHap` compiles with ERROR=0. Runtime behavior mirrors the real-server-tested RN/Flutter flow; device validation is the user's later step. **This is compile-level verification, weaker than RN/Flutter — agreed with the user.**

---

## BUILD GATE (every task)

```bash
cd /Volumes/MacMiniDisk/workspace/MobileStarter/arkts
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw assembleHap --no-daemon 2>&1 | tail -20
# Gate: "COMPILE RESULT: PASS" (ERROR:0; WARN ok). If ERROR, fix within this task's files.
```
(The build runs in ~6s for the 5000-line project; verified working locally. First run may need DevEco's SDK — `DEVECO_SDK_HOME` is set.)

**Commit discipline:** explicit `git add <paths>` only; never `-A`/`.`/`-u`; no `.env.local`; no server/flutter/react-native changes.

---

## Task 1: Fix baseline ArkTS compile errors

**Files:**
- Modify: `arkts/entry/src/main/ets/pages/LaunchPages.ets` (error ~line 99), `arkts/entry/src/main/ets/data/ApiClient.ets` (error line 10)

- [ ] **Step 1: Run the build to enumerate ALL current errors**
`cd /Volumes/MacMiniDisk/workspace/MobileStarter/arkts && /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw assembleHap --no-daemon 2>&1 | grep -E "ERROR|Error Message|At File" | head -30`
Expected: the known 3 errors (LaunchPages.ets:99, ApiClient.ets:10, + at least one more — capture the full list).

- [ ] **Step 2: Fix `ApiClient.ets` import placement (line 9-10)**
Currently `export { ApiFailure } from './ApiTransport'` sits at line 9, BETWEEN the first import block (lines 1-8) and the `import { AppUser, ... } from '../domain/Models'` block (lines 10-31). Move the `export { ApiFailure }` line to AFTER line 31 (the end of the Models import block), i.e.:
```ts
import { UsageSummary } from '../domain/Models'

export { ApiFailure } from './ApiTransport'

export class ApiClient {
```
(One line moves from line 9 to after the Models import.)

- [ ] **Step 3: Fix `LaunchPages.ets` line 99 (statement inside `build()`)**
The error "Only UI component syntax can be written here" is the `const splash = this.store.config!.splash` statement inside `build()`. ArkUI `build()` allows only UI component syntax + `if`/`ForEach`. Fix: remove the `const` and reference via a getter + inline. Add a private getter to the component class (near the other fields/getters):
```ts
  private get splashConfig(): SplashConfig | null {
    return this.store.config?.splash ?? null
  }
```
and replace the `else` block (lines 97-114+) so it reads:
```ts
    } else {
      // 闪屏阶段：countdown 非空即已确认有 splash 配置（maybeAdvance 保证非空）
      if (this.splashConfig != null) {
        Stack({ alignContent: Alignment.TopEnd }) {
          SplashMedia({ splash: this.splashConfig })
          Row() {
            SkipCapsule({
              countdown: Math.max(this.countdown, 0),
              canSkip: this.splashConfig.skippable !== false,
              onSkip: () => { this.goHome() }
            })
          }
          .padding(AppSpacing.x3)
        }
        .width('100%').height('100%')
        .backgroundColor(AppColors.background)
      }
```
(Import `SplashConfig` from `../domain/Models` if not already imported. Read the full `build()` to ensure the rest of the `else` block — the `if/else if` that follows — stays intact; only the `const splash` statement is removed and `splash` → `this.splashConfig`.)

- [ ] **Step 4: Fix the remaining error(s)** — run the build again, fix each ERROR within the files it names (only arkts/ entry files; if an error is in a file outside the payment scope but is a genuine baseline error, fix it minimally).

- [ ] **Step 5: Build gate**
Run the full `assembleHap` → expect `COMPILE RESULT: PASS` (ERROR:0). 

- [ ] **Step 6: Commit**
```bash
git add arkts/entry/src/main/ets/pages/LaunchPages.ets arkts/entry/src/main/ets/data/ApiClient.ets
# plus any other arkts file you fixed for the remaining error
git commit -m "fix(arkts): baseline compile errors (LaunchPages build() statement, ApiClient import placement)"
```

---

## Task 2: Payment models (Models.ets)

**Files:**
- Modify: `arkts/entry/src/main/ets/domain/Models.ets`

- [ ] **Step 1: Add payment types** — append to `Models.ets` (after `OrderView`, or near the other models). ArkTS interfaces:
```ts
export interface StoreProductMapping {
  apple?: string
  google?: string
  hms?: string
}

export interface StoreProduct {
  storeProductId: string
  title?: string
}

export interface PurchaseResult {
  storeProductId: string
  receipt: Record<string, Object | null>
}

export interface Entitlement {
  key: string
  expiresAt: string | null
}

export interface Subscription {
  planId: string
  status: string
  renewAt: string | null
}

export interface MembershipCurrent {
  tier: string | null
  entitlements: Entitlement[]
  subscription: Subscription | null
}

export interface CreateOrderResult {
  orderId: string
  storeProductId: string
  status: string
}

export enum OrderStatus {
  Pending = 'pending',
  Processing = 'processing',
  Success = 'success',
  Failed = 'failed',
  Refunded = 'refunded'
}

export function parseOrderStatus(value: string): OrderStatus {
  if (value === 'pending') return OrderStatus.Pending
  if (value === 'processing') return OrderStatus.Processing
  if (value === 'success') return OrderStatus.Success
  if (value === 'failed') return OrderStatus.Failed
  if (value === 'refunded') return OrderStatus.Refunded
  return OrderStatus.Pending
}
```
> ArkTS note: `receipt` as `Record<string, Object | null>` (ArkTS objects; avoid `any`/`unknown` which ArkTS disallows). If `Record<string, Object | null>` doesn't satisfy the compiler, use `Record<string, string | number | boolean | null>` — the mock receipt is `{productId: string, fail?: boolean}`.

- [ ] **Step 2: Extend `BillingPlan`** (line 29) — add:
```ts
export interface BillingPlan {
  id: string
  tierId: string
  name: string
  interval: string
  priceMinor: number
  currency: string
  provider: string
  storeProductMapping?: StoreProductMapping
}
```
- [ ] **Step 3: Extend `OrderView`** (line 124) — change `status: string` to `status: OrderStatus`:
```ts
export interface OrderView {
  id: string
  planId: string
  status: OrderStatus
  amountMinor: number
  currency: string
  provider: string
  createdAt: string
  completedAt: string | null
}
```
- [ ] **Step 4: Fix the OrderView construction site** — grep `OrderView` construction in ArkTS (`grep -rn "OrderView" arkts/entry/src/main/ets`) and wherever an `OrderView` is built from server JSON (e.g. `orders()`), wrap `status` with `parseOrderStatus(...)`. `ApiClient.orders()` should map: `.then(rows => rows.map(row => ({ ...row, status: parseOrderStatus(row.status) })))` — but that's Task 3's ApiClient change; here, at minimum ensure no `OrderView` construction breaks typecheck. Since ArkTS `request<T>` type-asserts, the `orders()` raw return still compiles (status typed as OrderStatus but runtime string) — normalize it in Task 3's `verifyPurchase`/`orders` via `parseOrderStatus`.

- [ ] **Step 5: Build gate** — `assembleHap` → PASS (ERROR=0).

- [ ] **Step 6: Commit**
```bash
git add arkts/entry/src/main/ets/domain/Models.ets
git commit -m "feat(arkts): payment models + BillingPlan.storeProductMapping + OrderStatus enum"
```

---

## Task 3: PaymentProvider + MockPaymentProvider + ApiClient payment methods

**Files:**
- Create: `arkts/entry/src/main/ets/payment/PaymentProvider.ets`, `arkts/entry/src/main/ets/payment/MockPaymentProvider.ets`
- Modify: `arkts/entry/src/main/ets/data/ApiClient.ets`, `arkts/entry/src/main/ets/data/ApiTransport.ets`

- [ ] **Step 1: Create `payment/PaymentProvider.ets`**
```ts
import { PurchaseResult, StoreProduct, StoreProductMapping } from '../domain/Models'

export interface PaymentProvider {
  loadProducts(mapping: StoreProductMapping | null): Promise<StoreProduct[]>
  purchase(storeProductId: string): Promise<PurchaseResult>
  restore(): Promise<PurchaseResult[]>
}
```

- [ ] **Step 2: Create `payment/MockPaymentProvider.ets`**
```ts
import { PurchaseResult, StoreProduct, StoreProductMapping } from '../domain/Models'
import { PaymentProvider } from './PaymentProvider'

export class MockPaymentProvider implements PaymentProvider {
  failPurchases: boolean = false
  private owned: string[] = []

  loadProducts(mapping: StoreProductMapping | null): Promise<StoreProduct[]> {
    const products: StoreProduct[] = []
    if (mapping == null) return Promise.resolve(products)
    if (mapping.apple != null) products.push({ storeProductId: mapping.apple })
    if (mapping.google != null) products.push({ storeProductId: mapping.google })
    if (mapping.hms != null) products.push({ storeProductId: mapping.hms })
    return Promise.resolve(products)
  }

  purchase(storeProductId: string): Promise<PurchaseResult> {
    const receipt: Record<string, string | boolean> = { productId: storeProductId }
    if (this.failPurchases) {
      receipt['fail'] = true
    } else {
      this.owned.push(storeProductId)
    }
    return Promise.resolve({ storeProductId, receipt })
  }

  restore(): Promise<PurchaseResult[]> {
    const results: PurchaseResult[] = []
    for (let i = 0; i < this.owned.length; i++) {
      results.push({ storeProductId: this.owned[i], receipt: { productId: this.owned[i] } })
    }
    return Promise.resolve(results)
  }
}
```
> ArkTS: no `any`/`unknown`; `Record<string, string | boolean>` for the receipt. No `Array.includes` in some ArkTS lints — use the manual loop above if needed.

- [ ] **Step 3: Extend `ApiTransport.request` to accept extra headers**
In `ApiTransport.ets`, change the `request` signature (lines 98-103) to add an optional `extraHeaders` param, and merge into `header:` (and pass through the recursion at line 116):
```ts
  async request<T>(
    path: string,
    method: http.RequestMethod,
    body?: ApiRequestBody,
    extraHeaders?: Record<string, string>,
    retried: boolean = false
  ): Promise<T> {
    const client = http.createHttp()
    try {
      const merged = this.headers()
      if (extraHeaders !== undefined) {
        const keys = Object.keys(extraHeaders)
        for (let i = 0; i < keys.length; i++) {
          merged[keys[i]] = extraHeaders[keys[i]]
        }
      }
      const response = await client.request(`${API_BASE}${path}`, {
        method,
        header: merged,
        extraData: body === undefined ? undefined : JSON.stringify(body),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 5000,
        readTimeout: 5000
      })
      const text = String(response.result)
      if (response.responseCode === 401 && !retried && await this.refreshSession()) {
        return this.request<T>(path, method, body, extraHeaders, true)
      }
      ...
```
(Existing callers `request(path, method, body)` still work — `extraHeaders` defaults undefined.)

- [ ] **Step 4: Add payment methods to `ApiClient`** — add these to the `ApiClient` class (near `orders()`), and import the new types:
```ts
  createOrder(planId: string, idempotencyKey: string): Promise<CreateOrderResult> {
    return this.request<CreateOrderResult>(
      '/api/v1/orders',
      http.RequestMethod.POST,
      { planId },
      { 'Idempotency-Key': idempotencyKey }
    )
  }

  verifyPurchase(orderId: string | null, receipt: Record<string, string | boolean>):
    Promise<OrderView> {
    const body: Record<string, Object | null> = { receipt }
    if (orderId != null) body['orderId'] = orderId
    return this.request<OrderView>(
      '/api/v1/purchases/verify', http.RequestMethod.POST, body
    ).then(order => ({ ...order, status: parseOrderStatus(order.status) }))
  }

  restorePurchases(receipts: Record<string, string | boolean>[]): Promise<string[]> {
    return this.request<Record<string, string[]>>(
      '/api/v1/purchases/restore', http.RequestMethod.POST, { receipts }
    ).then(result => result['entitlements'] ?? [])
  }

  membershipCurrent(): Promise<MembershipCurrent> {
    return this.request<MembershipCurrent>('/api/v1/membership/current', http.RequestMethod.GET)
  }

  entitlements(): Promise<string[]> {
    return this.request<Record<string, string[]>>(
      '/api/v1/membership/entitlements', http.RequestMethod.GET
    ).then(result => result['keys'] ?? [])
  }
```
> The `request<T>` body type is `ApiRequestBody` (defined in ApiTransport as a union of Records + input types). `{ planId }`, `{ receipt }`, `{ receipts }` are plain Records — verify they satisfy `ApiRequestBody`. `verifyPurchase`'s `body` uses `Record<string, Object | null>` — if that doesn't fit `ApiRequestBody`, widen the union in ApiTransport or cast to a compatible type. Update `ApiClient`'s imports to add: `CreateOrderResult`, `MembershipCurrent`, `OrderStatus`, `parseOrderStatus` from `../domain/Models`.

- [ ] **Step 5: Build gate** — `assembleHap` → PASS (ERROR=0). Fix ArkTS type complaints (e.g. `ApiRequestBody` union, `Record` value types) within ApiTransport/ApiClient.

- [ ] **Step 6: Commit**
```bash
git add arkts/entry/src/main/ets/payment/PaymentProvider.ets arkts/entry/src/main/ets/payment/MockPaymentProvider.ets arkts/entry/src/main/ets/data/ApiClient.ets arkts/entry/src/main/ets/data/ApiTransport.ets
git commit -m "feat(arkts): PaymentProvider + MockPaymentProvider + apiClient payment methods"
```

---

## Task 4: AppStore purchase action + purchaseState

**Files:**
- Modify: `arkts/entry/src/main/ets/state/AppStore.ets`

- [ ] **Step 1: Read `AppStore.ets`** — understand its structure (observable fields, `initialize`, `navigateByName`, how auth/session is handled, how `apiClient` is wired).

- [ ] **Step 2: Add purchase state** — ArkTS-idiomatic (enums + nullable fields, matching the codebase's state patterns). Add to `AppStore`:
```ts
  // payment
  purchaseStatus: PurchaseStatus = PurchaseStatus.Idle
  purchaseOrder: OrderView | null = null
  purchaseMessage: string = ''
  pendingPlanId: string = ''
```
with a `PurchaseStatus` enum at the top of the file (or in Models.ets):
```ts
export enum PurchaseStatus {
  Idle = 'idle',
  Loading = 'loading',
  Success = 'success',
  Failed = 'failed',
  Error = 'error',
  Offline = 'offline',
  Unauthorized = 'unauthorized'
}
```
(If `AppStore.ets` uses `@Observed`/`@ObjectLink` or plain fields, match the existing pattern.)

- [ ] **Step 3: Add the `purchase` action** (mirror the RN/Flutter flow exactly — this is the correctness-critical piece):
```ts
  async purchase(planId: string): Promise<boolean> {
    this.purchaseStatus = PurchaseStatus.Loading
    this.purchaseOrder = null
    this.purchaseMessage = ''
    try {
      const idempotencyKey: string =
        `ark-${Date.now()}-${Math.random().toString(36).slice(2)}`
      const order = await this.apiClient.createOrder(planId, idempotencyKey)
      const provider: MockPaymentProvider = new MockPaymentProvider()
      const result = await provider.purchase(order.storeProductId)
      const verified = await this.apiClient.verifyPurchase(order.orderId, result.receipt)
      this.purchaseOrder = verified
      this.purchaseStatus =
        verified.status === OrderStatus.Success ? PurchaseStatus.Success : PurchaseStatus.Failed
      if (verified.status === OrderStatus.Success) {
        try { await this.initialize() } catch (e) { /* best-effort membership refresh */ }
      }
      return verified.status === OrderStatus.Success
    } catch (error) {
      if (error instanceof ApiFailure && error.status === 401) {
        this.purchaseStatus = PurchaseStatus.Unauthorized
      } else if (error instanceof ApiFailure && error.status === 0) {
        this.purchaseStatus = PurchaseStatus.Offline
      } else {
        this.purchaseStatus = PurchaseStatus.Error
        this.purchaseMessage = error instanceof ApiFailure ? error.message : '订阅失败，请重试'
      }
      return false
    }
  }

  startCheckout(planId: string): void {
    this.purchaseStatus = PurchaseStatus.Idle
    this.pendingPlanId = planId
  }
```
> Requires imports: `MockPaymentProvider` from `../payment/MockPaymentProvider`, `PurchaseStatus`/`OrderStatus`/`CreateOrderResult`/`OrderView` from `../domain/Models`, `ApiFailure` from `../data/ApiTransport`. Verify `this.apiClient` exists (AppStore already holds one) and `initialize()` is the refresh method (check its name/signature).

- [ ] **Step 4: Build gate** — `assembleHap` → PASS (ERROR=0). Fix any ArkTS `catch (e)` unused-var / type issues (ArkTS may require `catch (error)` typed or an explicit untyped catch).

- [ ] **Step 5: Commit**
```bash
git add arkts/entry/src/main/ets/state/AppStore.ets
# plus Models.ets if you put PurchaseStatus there
git commit -m "feat(arkts): AppStore purchase action + purchaseState (mirror RN/Flutter flow)"
```

---

## Task 5: CheckoutPage + MembershipPage + Index wiring

**Files:**
- Create: `arkts/entry/src/main/ets/pages/CheckoutPage.ets`
- Modify: `arkts/entry/src/main/ets/pages/ProfilePages.ets` (MembershipPage), `arkts/entry/src/main/ets/pages/Index.ets` (ProfileHost)

- [ ] **Step 1: Create `pages/CheckoutPage.ets`** — an ArkUI component matching the existing page patterns (read `ProfilePages.ets` for the component/build/AppStore wiring idiom):
```ts
import { AppStore } from '../state/AppStore'
import { PurchaseStatus } from '../domain/Models'

@Component
export struct CheckoutPage {
  @Link store: AppStore

  private get planId(): string {
    return this.store.pendingPlanId
  }

  build() {
    Column() {
      // header + plan card (name/price from store.config.plans by planId) + mock notice
      // then branch on store.purchaseStatus:
      //   Loading -> disabled button "正在确认…"
      //   Success -> "完成" -> store.navigateByName('membership.home')
      //   Failed  -> "重试" -> store.purchase(planId)
      //   else    -> "确认订阅" -> store.purchase(planId)
    }
  }
}
```
> Match the existing page structure (Column/Row/AppButton equivalents — read `ProfilePages.ets` for the actual buttons/components used). Show the plan name/price from `store.config.plans.find(p => p.id === planId)`; show "演示支付" when `provider === 'mock'`. Loading disables the button; Success shows a success state; Failed shows retry. **The correct ArkUI `build()` for the branching must match the codebase's conditional-render idiom (read how other pages branch on state).**

- [ ] **Step 2: Modify `MembershipPage`** (in `ProfilePages.ets`) — add a "可订阅方案" section rendering `config.plans` (name/price), with a "确认订阅" button that calls `store.startCheckout(plan.id)` then `store.navigateByName('membership.checkout')`. Read the current `MembershipPage` (lines ~161-228) and add the plans section + button matching its existing card/row idiom. Keep the existing tier cards + links.

- [ ] **Step 3: Modify `Index.ets` `ProfileHost`** — the `membership.checkout` route currently falls through to `MembershipPage` (line ~116). Change it to render `CheckoutPage`. Read the route→component map and wire `CheckoutPage({ store })`.

- [ ] **Step 4: Build gate** — `assembleHap` → PASS (ERROR=0). Fix ArkUI syntax issues (the compiler is strict).

- [ ] **Step 5: Commit**
```bash
git add arkts/entry/src/main/ets/pages/CheckoutPage.ets arkts/entry/src/main/ets/pages/ProfilePages.ets arkts/entry/src/main/ets/pages/Index.ets
git commit -m "feat(arkts): CheckoutPage + MembershipPage plans rendering + checkout routing"
```

---

## Self-Review

**Spec coverage:**
- §2 baseline fixes (LaunchPages, ApiClient import, +1) → Task 1 ✓
- §3.1 models (storeProductMapping, OrderStatus, Entitlement/Subscription/MembershipCurrent/CreateOrderResult) → Task 2 ✓
- §3.2 ApiClient methods → Task 3 ✓
- §3.3 PaymentProvider + Mock → Task 3 ✓
- §3.4 AppStore purchase + purchaseState + pendingPlanId → Task 4 ✓
- §3.5 CheckoutPage + MembershipPage + Index → Task 5 ✓
- §4 data flow (createOrder→purchase→verify→status) → Task 4 (the action) ✓
- §6 build-gate verification → every task ✓

**Placeholder scan:** Task 5 (CheckoutPage/MembershipPage/Index) is specified structurally with the design + the required branching + the instruction to read the existing ArkUI idiom — the ArkUI DSL is verbose and file-specific, so complete-fidelity code would be thousands of lines; the plan gives the concrete structure + correctness requirements + the read-first instruction. This is the pragmatic middle ground for a UI-heavy third-mirror task. No TBD/TODO. All logic files (Models, ApiClient, ApiTransport, PaymentProvider, MockPaymentProvider, AppStore) have complete code.

**Type consistency:** `OrderStatus` enum (Task 2) used in Task 3 (`parseOrderStatus`) + Task 4 (`verified.status === OrderStatus.Success`) — consistent. `PurchaseStatus` enum (Task 4) used in CheckoutPage (Task 5) — consistent. `CreateOrderResult`/`MembershipCurrent`/`PurchaseResult` (Task 2) used in Tasks 3/4 — consistent. `MockPaymentProvider` (Task 3) used in Task 4 — consistent. `store.startCheckout`/`store.purchase`/`store.pendingPlanId` (Task 4) used in Task 5 — consistent.

**Known constraints (documented):** ArkTS `Record` type values (no `any`/`unknown`); `ApiRequestBody` union may need widening in ApiTransport; `catch` syntax in ArkTS; ArkUI `build()` forbids non-UI statements (the LaunchPages fix). Verification is compile-level only (no runtime tests) — agreed with the user.

---

## Execution Handoff

Plan saved to `docs/superpowers/plans/2026-08-11-payment-arkts-client.md`. Two options:

1. **Subagent-Driven (recommended)** — fresh subagent per task, two-stage review.
2. **Inline Execution** — batch with checkpoints.

Which approach?
