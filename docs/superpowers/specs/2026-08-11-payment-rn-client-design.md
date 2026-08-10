# P-1.3a React Native 支付客户端 — 设计

版本：1.0　日期：2026-08-11　状态：待评审
所属：MobileStarter 三商城 IAP · P-1 支付抽象 · RN 客户端契约对齐（镜像 Flutter P-1.2）。消费已上线的 P-1.1 服务端 API。

## 0. 背景与范围

P-1.1（服务端）与 P-1.2（Flutter 客户端）已合入 `main`。RN 客户端**当前是坏的**：`useDataActions.purchase(planId)` → `apiClient.purchase` → `POST /orders`（P-1.1 后只返回 pending），任何 2xx 都返回 true 并 toast「订阅已生效，权益已同步」——**假成功**，从不调 `/purchases/verify`。

P-1.3a 交付 RN 客户端：镜像 Flutter `payment/` 契约（模型 + API 方法 + store-provider 抽象 + 状态流），修掉假成功 bug，引入 **vitest 打真服务端**（仓库的 Next.js）的集成测试。

**范围：仅 React Native。** ArkTS 留 P-1.3b（无 DevEco，盲写 + 真机验证）。

### 设计依据（已确定）
- 镜像 Flutter `flutter/lib/payment/`（`payment_models.dart`/`payment_repository.dart`/`payment_provider.dart`/`mock_payment_provider.dart`/`payment_controller.dart`），落到 RN 对应层：`src/domain/models.ts`（模型）、`src/data/apiClient.ts`（HTTP）、`src/state/useDataActions.ts` + `AppStore.tsx`（状态）、`src/payment/*`（provider）。
- RN 现有 `apiClient` 已处理租户头、token、401 单飞刷新——**只加方法，不重建认证管道**。
- **真实环境测试**：vitest 打仓库的 Next.js 服务端 + `mobileui_dev` 库（同 Flutter/P-1.1 测试哲学，无业务 fake）。
- 独立 CheckoutScreen 镜像（与 P-1.2 Flutter 一致）。

## 1. 目标与非目标

### 目标
1. 模型契约对齐：`BillingPlan.storeProductMapping`、`OrderStatus` 枚举、`Entitlement`/`Subscription`/`MembershipCurrent`/`CreateOrderResult`。
2. `apiClient` 补方法：`createOrder`/`verifyPurchase`/`restore`/`membershipCurrent`/`entitlements`；废弃旧 `purchase(planId)`。
3. **重构 `apiClient` 使其可被 node/vitest 加载**（见 §2.2，这是真测的必经使能点）。
4. `PaymentProvider` 接口 + `MockPaymentProvider`（镜像 Flutter；真实商店 SDK 留 P-2/3/4）。
5. 状态流重写：`createOrder → provider.purchase → verifyPurchase → membershipCurrent`，按 `order.status` 判真成败；**修假成功 bug**。
6. 独立 CheckoutScreen（镜像 Flutter `membership.checkout` 路由语义）；MembershipScreen 接入。
7. vitest + 真服务端集成测试（含 ownership）。

### 非目标（P-1.3b / P-2+）
- ArkTS（P-1.3b）。真实 StoreKit/Play/HMS（P-2/3/4）。试用/升降级/多档额度 UI（P-5）。

## 2. 组件

### 2.1 模型（`src/domain/models.ts`）
- `BillingPlan` 加 `storeProductMapping?: { apple?: string; google?: string; hms?: string }`（`fromJson` 容错缺失）。
- `OrderStatus` 枚举：`pending | processing | success | failed | refunded`；`OrderView.status: OrderStatus`（解析失败默认 `pending`）。`embeddedConfig.ts` 的 plans 占位同步。
- 新增 `StoreProductMapping`/`StoreProduct`/`PurchaseResult`/`Entitlement`/`Subscription`/`MembershipCurrent`/`CreateOrderResult`（镜像 `flutter/lib/payment/payment_models.dart`）。
- 现有 `statusLabel()`（`DataScreens.tsx:129-136`）改用枚举。

### 2.2 `apiClient` 重构（`src/data/apiClient.ts`）——真测使能点
当前 `apiClient` import `react-native`（`Platform`）与 `expo-secure-store`（经 `storage.ts`），node/vitest 无法加载。重构为**平台无关的纯 TS HTTP 层**：
- 平台标识：抽出 `getPlatformHeader(): string`，默认读 RN `Platform.OS`，可注入覆盖（测试设为 `'ios'`——服务端只把 ios/android/harmonyos 映射到商店 key）。
- token 来源：抽出可替换的 `sessionTokenProvider: () => Promise<string | null>`，默认走 `storage.ts.readSessionToken()`；测试注入真 signup 的真 token（RN 版 InMemoryTokenStore，非业务 fake）。
- `react-native` import 从 apiClient 的 import 路径移除（或包进惰性/可注入的 getter），保证 `import` 在 node 下不炸。
- 生产接线：`mobile_ui_app` 等入口处把默认 platform/storage 接回 RN 运行时。

### 2.3 API 方法（`apiClient`）
```ts
createOrder(planId: string, idempotencyKey: string): Promise<CreateOrderResult>  // POST /api/v1/orders
verifyPurchase(orderId: string | undefined, receipt: unknown): Promise<OrderView> // POST /api/v1/purchases/verify
restore(receipts: unknown[]): Promise<string[]>                                   // POST /api/v1/purchases/restore → entitlements keys
membershipCurrent(): Promise<MembershipCurrent>                                   // GET /api/v1/membership/current
entitlements(): Promise<string[]>                                                 // GET /api/v1/membership/entitlements → keys
orders(): Promise<OrderView[]>                                                    // GET /api/v1/orders（保留）
```
旧 `purchase(planId)` 删除。租户头/idempotency-key/Bearer/401 刷新沿用现有机制。

### 2.4 Store-provider 抽象（`src/payment/`）
- `paymentProvider.ts`：`loadProducts(mapping)` / `purchase(storeProductId): Promise<PurchaseResult>` / `restore(): Promise<PurchaseResult[]>`（镜像 Flutter 接口）。
- `mockPaymentProvider.ts`：内存 `Set` 跟踪已购，`purchase` 产 `receipt:{productId, fail?}`；`failPurchases` 布尔字段做沙箱失败模式（同 Flutter，不用测试替身子类）。

### 2.5 状态流（`src/state/useDataActions.ts` + `AppStore.tsx`）
- 新增 `purchaseState`（RN 的 discriminated-union AsyncState：`idle/loading/success/empty/error/offline/unauthorized`——对齐 CODE_RULES 状态机）。
- 重写 `purchase`：
  ```
  createOrder(planId, idempotencyKey=uuid) → provider.purchase(storeProductId) → verifyPurchase(orderId, receipt)
  → order.status==='success' 时 membershipCurrent() 刷新 + 返回真结果；否则返回 failed 结果（不假成功）
  ```
- `useApp()` 暴露 `purchase`/`purchaseState`/`restorePurchases`。修掉「任何 2xx 都 toast 成功」的假成功 bug。

### 2.6 CheckoutScreen（`src/screens/CheckoutScreen.tsx`）
独立确认页（`membership.checkout` 路由，路由已存在 `routes.ts`）。展示方案名/周期/价格（`config.plans` 按 planId）、确认按钮 → `purchase` → 按 `purchaseState` + `order.status` 渲染：success→成功、failed→重试、loading→进度+禁用、offline/error→重试、unauthorized→回登录。mock provider 显示「演示支付」角标。MembershipScreen `buy()` 改为 push Checkout（带 planId），不再直接 toast 假成功。

## 3. 数据流（checkout）
```text
MembershipScreen → push Checkout(planId)
  → purchase(planId)
    → apiClient.createOrder(planId, idempotencyKey)     // POST /orders → {orderId, storeProductId}
    → mockProvider.purchase(storeProductId)              // receipt
    → apiClient.verifyPurchase(orderId, receipt)         // POST /purchases/verify → OrderView
    → order.status==='success' ? membershipCurrent() : (failed 结果)
  → purchaseState = success(order) | failed(order) | error/offline/unauthorized
```
`restorePurchases()`：`provider.restore()` → `apiClient.restore(receipts)`。

## 4. 错误与状态
- 沿用 RN `ApiError`/异常模型；错误码透传（`PRODUCT_NOT_MAPPED`/`ORDER_NOT_FOUND`/`PURCHASE_VERIFY_FAILED`）。
- `purchaseState` 对齐 CODE_RULES 的 `idle/loading/success/empty/error/offline/unauthorized` 七态，禁多布尔。
- Loading 禁用按钮、幂等（idempotencyKey）；`order.status==='failed'` 不假成功。

## 5. 测试（vitest + 真服务端）
**前置**（与 P-1.1/Flutter 测试同一套）：
1. Next.js 服务端在跑：`cd server && AUTH_DATABASE_URL='postgresql://mediagrab:mediagrab_dev@newmedia:5432/mobileui_dev' npm run dev`（:3210）。
2. 重置库：`DROP SCHEMA public CASCADE; CREATE SCHEMA public;`（schema 首次请求自动重建）。
3. vitest 配置：`platformHeader='ios'` + 注入真 signup token（`POST /api/v1/auth/sign-up` → `data.token`）。

**测试套件** `react-native/src/__tests__/payment/`（vitest，node 环境）：
- `purchase_flow_test.ts`：signup → createOrder → mock purchase → verify → 断言 `order.status==='success'` + `membershipCurrent().entitlements` 非空。
- `verify_failure_test.ts`：`mockProvider.failPurchases=true` → 订单 `failed`、entitlements 空（断言真实语义：HTTP ok + order failed）。
- `idempotent_order_test.ts`：同一 idempotencyKey 两次 createOrder → 同 orderId。
- `ownership_test.ts`：A 的 orderId 用 B 的 token verify → 抛错（ORDER_NOT_FOUND）。
- `restore_test.ts`：mock 先 purchase 再 restore → entitlements 恢复。
- `payment_models_test.ts`：`BillingPlan.fromJson`（storeProductMapping）、`OrderView` status 枚举。

`npm run typecheck`（tsc）+ vitest 全绿。

## 6. 文件清单
**新建**：`src/payment/paymentProvider.ts`、`src/payment/mockPaymentProvider.ts`、`src/screens/CheckoutScreen.tsx`、`src/__tests__/payment/*`（5 个测试 + `testServer.ts` 辅助）、`vitest.config.ts`。
**修改**：`src/domain/models.ts`（契约）、`src/data/apiClient.ts`（重构 + 方法）、`src/state/useDataActions.ts` + `AppStore.tsx`（purchase 流 + purchaseState）、`src/screens/MembershipScreen.tsx`（接 Checkout）、`src/navigation/routes.ts` + 导航（checkout 路由接线）、`src/screens/DataScreens.tsx`（`statusLabel` 用枚举）、`package.json`（+ vitest 依赖 + test 脚本）、`src/data/storage.ts`（token 访问器可注入）。

## 7. 验收（RN 侧）
- MEM-09/10（方案价格 + storeProductMapping 渲染）、MEM-14（`/membership/current`）、MEM-16（恢复购买）。
- PAY-03/04（mock 成功/失败 E2E，RN→服务端）、PAY-05（中断恢复）、PAY-06（订单可查询）。
- QLT-07/08/09（可恢复/防重复/token 不入 UI）。
- **假成功 bug 修复**：订单 pending/failed 时不再 toast「订阅已生效」。

## 8. 风险与未决
1. **`apiClient` 平台无关重构**是最大改动的单点：要从 apiClient 摘掉 `react-native`/`expo-secure-store` 的直接依赖（改注入）。需确认生产接线（入口处接回 RN 运行时值）不破坏现有认证/导航。
2. **vitest 是 RN 首个测试框架**：node 环境对 RN 模块有限制（fetch 可用；`react-native`/`expo-*` 不可直接 import）——重构后 apiClient 纯 TS 即满足。若仍有隐藏 RN 依赖导致 node import 失败，需进一步解耦（属本 spec 使能点范围）。
3. **`statusLabel`/UI 其他 string-status 消费点**：`OrderView.status` 变枚举后，需 grep 全部消费点改用 `.name`/枚举映射。
4. ArkTS 留 P-1.3b（无 DevEco，不在本 spec）。
