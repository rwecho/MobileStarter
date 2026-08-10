# P-1.3b ArkTS 支付客户端 — 设计

版本：1.0　日期：2026-08-11　状态：待评审
所属：MobileStarter 三商城 IAP · P-1 支付抽象 · ArkTS 客户端契约对齐（镜像 Flutter P-1.2 / RN P-1.3a）。消费已上线的 P-1.1 服务端 API。

## 0. 背景与范围

P-1.1（服务端）、P-1.2（Flutter）、P-1.3a（RN）已合入 `main`。ArkTS 是客户端契约对齐的最后一块，**当前完全没有购买路径**（`ApiClient` 只有 `orders()` GET；`AppStore` 无 purchase action；`membership.checkout` 路由重新渲染 `MembershipPage`，无 plans/购买 UI）。

**额外基线问题**：本机 `hvigorw 6.23.6`（DevEco Studio 内置）+ HarmonyOS SDK 可本地构建验证，但**当前 arkts 基线 `assembleHap` 编译不过（3 个错误）**：
- `LaunchPages.ets:99`「Only UI component syntax」—— **splash 提交 `500e7e7` 引入的回归**（提交时未跑 ArkTS 构建）。
- `ApiClient.ets:10`「import statements after other statements」—— 既有问题（`export { ApiFailure } from './ApiTransport'` 夹在 import 之间）。
- 第 3 个错误在构建输出尾部未完整显示，需修复任务中定位。

P-1.3b 交付：① 修基线编译错误；② 镜像支付契约到 ArkTS（模型 + ApiClient 方法 + PaymentProvider/Mock + AppStore 购买 action + CheckoutPage）。

### 验证标准（已与用户确认）
每个 Task 以 **`hvigorw assembleHap` 构建通过**为闸门（能抓 ArkTS 类型/语法错误）。**无 hypium/模拟器 → 不做运行时测试**；运行时行为镜像真测过的 RN/Flutter 流程（服务端逻辑已由 P-1.1/RN/Flutter 覆盖），ArkTS 特有行为需用户真机验证。**验证 = 编译级 + 代码评审对齐，非运行时。**

## 1. 目标与非目标

### 目标
1. 修基线 3 个 ArkTS 编译错误，`hvigorw assembleHap` 先绿。
2. 模型契约对齐：`BillingPlan.storeProductMapping`、`OrderStatus` 枚举、`Entitlement`/`Subscription`/`MembershipCurrent`/`CreateOrderResult`。
3. `ApiClient` 补 `createOrder`/`verifyPurchase`/`restore`/`membershipCurrent`/`entitlements`（复用 `ApiTransport` 的 token/401 刷新/x-platform:harmonyos）。
4. `PaymentProvider` 接口 + `MockPaymentProvider`（`failPurchases` 沙箱模式，镜像 RN/Flutter）。
5. `AppStore` 加 `purchase` action（createOrder→provider.purchase→verify→membershipCurrent）+ `purchaseState`（7 态），对齐契约语义。
6. `CheckoutPage` 独立确认页；`MembershipPage` 渲染 plans + 购买入口。
7. hvigor build 闸门验证每个 Task。

### 非目标（P-2+ / 本 spec 之外）
- 真实 HMS IAP SDK（P-4）。hypium/模拟器运行时测试（本机无）。试用/升降级/多档额度 UI（P-5）。Web 平台（ArkTS 无）。

## 2. 基线修复（前置 Task）

- `LaunchPages.ets:99`：`if (splash) { Stack({...}) { ... } }` 触发「Only UI component syntax」——排查 `const splash = this.store.config!.splash` 语句在 `build()` 内 + `if` 块内 UI 的 ArkUI 约束，改为符合 ArkUI 的写法（可能需要把声明移到 build 外、或用 `if (this.store.config?.splash != null)` 直接条件渲染）。
- `ApiClient.ets:10`：把 `export { ApiFailure } from './ApiTransport'` 移到所有 import 之后（或改用 `export type` 统一位置）。
- 第 3 个错误：跑 `assembleHap` 定位修复。
- 验收：`hvigorw assembleHap` 编译通过（WARN 可留，ERROR=0）。

## 3. 组件

### 3.1 模型（`domain/Models.ets`）
- `BillingPlan` 加 `storeProductMapping?: StoreProductMapping`（ArkTS interface）。
- `OrderView.status: OrderStatus`（枚举 `pending | processing | success | failed | refunded`）+ `parseOrderStatus()` 兜底 pending。
- 新增 `StoreProductMapping`/`StoreProduct`/`PurchaseResult`/`Entitlement`/`Subscription`/`MembershipCurrent`/`CreateOrderResult`（镜像 `flutter/lib/payment/payment_models.dart`）。

### 3.2 `ApiClient`（`data/ApiClient.ets`）
加方法（复用 `ApiTransport` 的 `request`/token/401/x-platform:harmonyos）：
```text
createOrder(planId, idempotencyKey)  → POST /api/v1/orders + Idempotency-Key 头 → CreateOrderResult
verifyPurchase(orderId?, receipt)    → POST /api/v1/purchases/verify → OrderView（status 归一化）
restore(receipts)                    → POST /api/v1/purchases/restore → { entitlements }
membershipCurrent()                  → GET /api/v1/membership/current → MembershipCurrent
entitlements()                       → GET /api/v1/membership/entitlements → { keys }
```
删除/替换无（ArkTS 本来就没有旧 `purchase`）。

### 3.3 `PaymentProvider` 抽象（`payment/`）
- `PaymentProvider.ets`：接口 `loadProducts(mapping)` / `purchase(storeProductId)` / `restore()`。
- `MockPaymentProvider.ets`：内存 Set 跟踪已购；`failPurchases` 布尔字段做沙箱失败模式（产 `receipt:{productId, fail?}`，服务端 mock 验证）。镜像 RN/Flutter。

### 3.4 `AppStore`（`state/AppStore.ets`）
- `purchaseState`：ArkTS 联合类型（`idle | loading | success(order) | failed(order) | error(msg) | offline | unauthorized`）。
- `purchase(planId)`：set loading → `apiClient.createOrder(planId, idempotencyKey)` → `provider.purchase(storeProductId)` → `apiClient.verifyPurchase(orderId, receipt)` → **按 `order.status` 设 success/failed**（假成功防护：`failed` 不当作成功）→ `status==='success'` 时刷新 membership。错误映射：网络→offline、ApiClientError→error、401→unauthorized。
- 重置 `purchaseState` 为 idle 于进入新 checkout 前（镜像 RN 的 `setPurchaseState({kind:'idle'})`）。
- `pendingPlanId`：记录待确认方案（镜像 Flutter `pendingPlanId`/RN）。

### 3.5 UI（`pages/`）
- `MembershipPage`（`ProfilePages.ets`）：渲染 `config.plans`（方案卡片：名称/价格/provider），点击「确认订阅」→ 设 pendingPlanId + 导航 `membership.checkout`。
- `CheckoutPage`（新）：独立确认页，读 pendingPlanId + 方案，按 `purchaseState` 渲染：loading→进度/禁用、success→成功+完成、failed→失败+重试、其他→确认按钮。mock provider 显示「演示支付」。
- `Index.ets` `ProfileHost`：`membership.checkout` 从「fall through 到 MembershipPage」改为 → `CheckoutPage`。

## 4. 数据流
```text
MembershipPage 选方案 → 设 pendingPlanId + navigate('membership.checkout')
  → CheckoutPage 确认 → AppStore.purchase(planId)
    → createOrder(planId, idempotencyKey) → { orderId, storeProductId }
    → MockPaymentProvider.purchase(storeProductId) → receipt
    → verifyPurchase(orderId, receipt) → OrderView
    → order.status==='success' ? 刷新 membership + success 态 : failed 态（不假成功）
```

## 5. 错误与状态
- 复用 `ApiTransport` 的 `ApiFailure` 模型；错误码透传（`PRODUCT_NOT_MAPPED`/`ORDER_NOT_FOUND`/`PURCHASE_VERIFY_FAILED`）。
- `purchaseState` 对齐三端语义（idle/loading/success/failed/error/offline/unauthorized），禁多布尔。
- Loading 禁用按钮、幂等（idempotencyKey）；`order.status==='failed'` 不假成功。

## 6. 验证（hvigor build 闸门）
- 每个 Task 完成后跑：`cd arkts && /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw assembleHap --no-daemon`
- 验收：`COMPILE RESULT: PASS`（ERROR=0；WARN 可接受）。
- **无运行时测试**（无 hypium/模拟器）。代码评审聚焦与 RN/Flutter 流程的语义一致性（服务端行为已由 P-1.1/RN/Flutter 真测覆盖）。ArkTS 特有运行时行为 → 用户真机验证。

## 7. 文件清单
**新建**：`arkts/entry/src/main/ets/payment/PaymentProvider.ets`、`arkts/entry/src/main/ets/payment/MockPaymentProvider.ets`、`arkts/entry/src/main/ets/pages/CheckoutPage.ets`。
**修改**：`domain/Models.ets`（契约）、`data/ApiClient.ets`（基线 import 修复 + 方法）、`state/AppStore.ets`（purchaseState + purchase + pendingPlanId）、`pages/ProfilePages.ets`（MembershipPage 渲染 plans + 购买）、`pages/LaunchPages.ets`（基线回归修复）、`pages/Index.ets`（checkout 路由 → CheckoutPage）、`navigation/AppRoute.ets`/路由守卫（如需 checkout 守卫确认）。

## 8. 验收（ArkTS 侧）
- MEM-09/10/14/16 契约对齐（方案/storeProductMapping/current/restore）。
- PAY-03/04（mock 成功/失败流程）、PAY-05/06 语义对齐。
- QLT-07/08/09（可恢复/防重复/token 不入 UI）。
- **基线修复**：`assembleHap` 编译通过（ERROR=0）。
- 三端一致性：模型字段、路由 ID、状态语义与 RN/Flutter 对齐。

## 9. 风险与未决
1. **验证弱**：仅编译级（无运行时测试），ArkTS 特有行为需真机验证——已与用户确认接受。
2. **基线回归**：LaunchPages 的 splash 回归是提交 splash 工作时的遗漏（当时未跑 ArkTS 构建）；修复需理解 ArkUI `if`/build 约束。
3. **第 3 个编译错误未完全显示**：修复任务中先跑构建定位完整错误清单。
4. **hvigor 首次构建可能下载依赖**（本机已验证可跑，6 秒编译 5000 行）；全量构建需内存/时间，每次 Task 闸门用 `assembleHap`。
