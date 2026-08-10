# P-1 支付抽象地基（Payment Abstraction Foundation）— 设计

版本：1.0　日期：2026-08-10　状态：待评审
所属：MobileStarter 三商城（Apple/Google/HMS）真实 IAP 收费产品 · 路线 A（自建契约式）

## 0. 背景与定位

MobileStarter 是可派生产品的跨端母模板，目标是派生出在 鸿蒙 / 安卓 / 苹果 三大商城上架的 **免费下载 + 应用内订阅/内购（IAP）** 收费产品。整体采用 **路线 A：自建契约式**（不引入 RevenueCat 等第三方计费），能力沉淀进模板，所有派生产品零成本继承。

三商城真实 IAP 工程量大，已分解为 5 个子项目，**构建内部串行、上线三商城同步**：

| 子项目 | 内容 | 状态 |
|---|---|---|
| **P-1 抽象地基（本 spec）** | 模板定义客户端 `PaymentProvider` + 服务端 `PaymentAdapter` 契约，补齐数据模型与 API，用 Mock 适配器跑通完整链路 | 本文档 |
| P-2 Apple 参考实现 | Flutter `in_app_purchase`(iOS) + App Store Server API v2 验票 + ASSN V2 webhook | 后续 spec |
| P-3 Google | Flutter `in_app_purchase`(Android) + Play Developer API + RTDN | 后续 spec |
| P-4 HMS / 鸿蒙 | ArkTS HMS IAP Kit + HMS 服务端验票 + HMS webhook | 后续 spec |
| P-5 派生第一个产品 | `mobileui` CLI 补齐 ArkTS profile → 派生产品 → 三端上架 | 后续 spec |

**P-1 只定"形状"并用 Mock 跑通，不接任何真实商店 SDK。** P-2/3/4 只需替换 adapter 实现，契约与状态机不动。

### 当前代码现状（P-1 的增量基线）

- 服务端 `server/src/server/payment-providers.ts:16-19` 已有 `PaymentProviderPort { id; start(input) → {complete} }`，`mockProvider` 已实现，apple/google/wechat/alipay 为 503 桩（`PAYMENT_PROVIDER_NOT_CONFIGURED`），生产禁用 mock。
- `order-service.ts` 已有幂等下单（`findOrder(userId, idempotencyKey)` 命中即返回既有单）。
- 路由只有 `POST /api/v1/orders` 与 `GET /api/v1/membership/catalog`。`/purchases/verify`、`/purchases/restore`、`/membership/current`、`/membership/entitlements`、全部 `/webhooks/*` **均不存在**。
- `BillingPlan`（`server/src/domain/config.ts`、`flutter/lib/app/runtime_models.dart`）**没有 `storeProductMapping`**，`provider` 仅为路由提示。
- Flutter 端 `OrderView` 极简（`{id, planId, status, amountMinor, currency}`）；`support/*` 是 scoped controller 的现成模板；`membership.checkout/orders` 路由别名已存在；`in_app_purchase` 未引入，无任何购买代码。

## 1. 目标与非目标

### 目标

1. 定义三端共享的客户端 `PaymentProvider` 契约与服务端 `PaymentAdapter` 契约（verify/restore/webhook）。
2. 补齐数据模型：`storeProductMapping`、Order 状态机、`UserEntitlement`、`WebhookEvent`、`Subscription`。
3. 补齐 API：`/purchases/verify`、`/purchases/restore`、`/membership/current`、`/membership/entitlements`、`/webhooks/{apple,google,hms}`。
4. **Order 确认 ↔ `UserEntitlement` 发放必须在同一数据库事务**；幂等下单；Webhook 去重（同一事件处理 10 次只生效 1 次）。
5. Mock 适配器驱动完整 E2E：下单 → 支付 → 验票 → 发权益 → webhook 续订/退款，无真实商店也可在本地与 CI 全绿。
6. 三端契约测试：从服务端 Zod schema 导出 JSON Schema 快照，三端模型按快照校验。

### 非目标（归属后续子项目）

- 真实 StoreKit 2 / Play Billing / HMS IAP Kit 客户端集成（P-2/3/4）。
- 真实 App Store Server API v2 / Play Developer API / HMS 服务端验票与签名校验（P-2/3/4）。
- 对账任务、WeChat/Alipay 真实适配、完整 P5 矩阵（试用/首购价/多档额度/升降级）（P-5 及以后）。
- 全量 OpenAPI（归属 P-0；P-1 仅对支付子集导出 JSON Schema 快照用于契约测试）。

## 2. 架构：购买流程从"服务端 start"改为"客户端驱动 + 服务端验票"

当前 mock 流程是 `client POST /orders → provider.start() → order.complete`。真实 IAP 必须反过来：**客户端先与商店交易拿到票据，再上传服务端验票**。P-1 用 Mock 适配器模拟这套真实流程，使 P-2/3/4 只替换 adapter 实现，流程不变。

```text
客户端                            服务端控制面                        商店
  │ 1. POST /orders (idempotent) ──▶ createOrder → pending            │
  │ ◀── orderId + storeProductId ──── (from plan.storeProductMapping) │
  │ 2. PaymentProvider.purchase(storeProductId) ─────────────────────▶│ 商店交易
  │ ◀── receipt / transaction ───────────────────────────────────────│
  │ 3. POST /purchases/verify {orderId, receipt} ─▶ processing        │
  │                                               adapter.verify()   │
  │                                  TX{ Order→succeeded,            │
  │                                       UserEntitlement 发放,      │
  │                                       Subscription upsert }      │
  │ ◀── membership/current ───────────                                │
  │                                                                   │
商店 webhook (续订/退款/取消) ──▶ POST /webhooks/{apple|google|hms}   │
                                  adapter.parseWebhook() → 去重       │
                                  TX{ Order/Subscription/Entitlement }│
```

## 3. 数据模型增量（服务端）

### 3.1 `domain/config.ts` — BillingPlan

- 新增 `storeProductMapping?: Readonly<{ apple?: string; google?: string; hms?: string }>`。
- `provider` 联合类型新增 `'hms'`（保留 `'wechat' | 'alipay'` 为桩，本子项目不实现）。
- `planSchema`（`schemas.ts`）同步增加 `storeProductMapping`，校验"启用商店必须有商品 ID"。

### 3.2 `orders` 表扩展（`database-schema-product.ts`）

```text
status: 'pending'|'processing'|'succeeded'|'failed'|'closed'|'refunded'
provider: 'mock'|'apple'|'google'|'hms'|'wechat'|'alipay'
store_transaction_id: text nullable
receipt_hash: text nullable              -- sha256(receipt)，便于幂等/审计
idempotency_key: text not null           -- (user_id, idempotency_key) unique
expires_at: timestamptz nullable         -- 订阅到期（一次性购买为 null）
```

### 3.3 新表 `user_entitlements`

```text
user_id, app_id, entitlement_key, source_order_id,
active: bool, acquired_at: timestamptz, expires_at: timestamptz nullable
unique(user_id, entitlement_key) where active   -- 同一权益同一用户只一条 active
```

### 3.4 新表 `subscriptions`（订阅态，与订单解耦）

```text
user_id, app_id, plan_id, platform,
status: 'active'|'expired'|'grace'|'canceled',
current_order_id, renew_at: timestamptz nullable
```

### 3.5 新表 `webhook_events`（去重）

```text
provider, event_id, received_at, payload_hash, processed: bool
unique(provider, event_id)   -- 第二次到达即跳过（PAY-06）
```

## 4. 服务端契约

### 4.1 `PaymentAdapter`（替换并扩展现 `PaymentProviderPort`）

```ts
export interface PaymentAdapter {
  readonly id: 'mock' | 'apple' | 'google' | 'hms' | 'wechat' | 'alipay';
  // orderId 可缺省（如重装后的 restore 场景）：此时按 receipt.productId 反查 plan.storeProductMapping 解析归属方案
  verifyReceipt(input: {
    appId: string; userId: string; orderId?: string; receipt: unknown;
  }): Promise<VerifyResult>;
  parseWebhook(rawBody: Buffer, headers: Readonly<Record<string,string>>): Promise<WebhookEvent | null>;
}

export type VerifyResult = Readonly<{
  ok: boolean;
  storeTransactionId?: string;
  productId?: string;     // 用于 orderId 缺省时反查 plan
  expiresAt?: string;     // ISO；一次性购买为 undefined
  refund?: boolean;
}>;
```

- **没有服务端 `restore()`**：商店不允许服务端主动查询用户购买。恢复购买由客户端 `PaymentProvider.restore()`（商店 SDK）拿到 receipts 后批量提交 `/purchases/restore`，服务端逐条复用 `verifyReceipt`。
- P-1 实现：`mockAdapter` 全实现；apple/google/hms/wechat/alipay 为 `unavailableAdapter`，`verifyReceipt` 抛 `503 PAYMENT_PROVIDER_NOT_CONFIGURED`，`parseWebhook` 抛 `401 WEBHOOK_SIGNATURE_INVALID` 并记一条安全审计事件（满足 PAY-07 骨架）。
- `paymentProvider(id, environment)` 工厂保留"生产禁用 mock"语义。

### 4.2 Order 状态机与服务（`order-service.ts` 重写）

```text
pending ──verifyPurchase()─▶ processing ──ok──▶ succeeded ──refund webhook──▶ refunded
                                   └──fail──▶ failed
succeeded/refunded ──close──▶ closed
```

- `createOrder({userId, appId, idempotencyKey, planId})`：幂等（既有）；`platform` 取自请求已有的 `x-platform` 头（`client-context`，客户端不另传）；从 `plan.storeProductMapping[platform]` 取 `storeProductId`，返回 `{ orderId, storeProductId, status: 'pending' }`。若该 platform 无商品映射 → `404 PRODUCT_NOT_MAPPED`。
- `verifyPurchase({orderId?, receipt})`：置 `processing` → `adapter.verifyReceipt` → 同一事务内：成功则 `Order→succeeded`（orderId 缺省时先按 `receipt.productId` 反查 plan 创建 order）+ 发放/续期 `UserEntitlement` + upsert `Subscription`；失败则 `Order→failed`（不发权益）。重复 verify 同一 receipt（`receipt_hash` 命中已 succeeded）→ 幂等返回，不重复发权益。
- `restorePurchases({userId, receipts[]})`：对每条 receipt 调 `verifyPurchase`（orderId 缺省，走反查），幂等补发 entitlement（已存在则跳过）。
- `applyWebhook(provider, rawBody, headers)`：`parseWebhook` → 按 `(provider, event_id)` 入 `webhook_events` 去重 → 同一事务更新 order/subscription/entitlement。

> **硬门禁**：`verifyPurchase` 与 `applyWebhook` 中"确认 Order"与"发放/撤销 Entitlement"必须在同一 DB 事务，满足 IMPLEMENTATION_PLAN 硬门禁第 6 条。

### 4.3 新增路由（`src/app/api/v1/...`）

| 方法 | 路径 | 说明 |
|---|---|---|
| POST | `/purchases/verify` | body `{orderId?, receipt}`，返回更新后的 order + 是否发放权益 |
| POST | `/purchases/restore` | body `{receipts: unknown[]}`，逐条 `verifyPurchase`，返回当前权益列表 |
| GET | `/membership/current` | 当前 tier + active entitlements + subscription 状态 |
| GET | `/membership/entitlements` | 仅返回 active entitlement keys（客户端权限门用） |
| POST | `/webhooks/apple` `/webhooks/google` `/webhooks/hms` | `applyWebhook`；验签失败 401 |

`/membership/catalog`（已存在）不变。所有业务表写入必须带 `appId`（多租户）。

## 5. 客户端契约（Flutter 为参考实现；RN / ArkTS 镜像同一契约）

### 5.1 `PaymentProvider` 接口（新 `payment/payment_provider.dart`）

```dart
abstract interface class PaymentProvider {
  Future<List<StoreProduct>> loadProducts(StoreProductMapping mapping);
  Future<PurchaseResult> purchase(String productId);
  Future<List<PurchaseResult>> restore();
  Stream<PurchaseUpdate> get transactions;
}
```

- `purchase()` 返回的 `PurchaseResult` 携带 `receipt`，由调用方上传 `/purchases/verify`。
- P-1 只接 `MockPaymentProvider`（不依赖 `in_app_purchase`）；P-2 起新增 `IapPaymentProvider`（包 `in_app_purchase`）实现同一接口。

### 5.2 接入模式（镜像 `support/*`）

新增独立子域，避免继续膨胀 `AppRepository`/`AppController` 两个 god-class：

- `payment/payment_repository.dart`：`Future<T>` + 抛 `ApiException`，复用 `AppRepository` 的 401 单飞刷新与租户头。
- `payment/payment_controller.dart` + `payment/payment_scope.dart`：`ChangeNotifier` + `InheritedNotifier`，持有 `AsyncState<PurchaseResult> purchaseState` 与 `AsyncState<List<Entitlement>> restoreState`。

### 5.3 模型扩展（`runtime_models.dart`）

- `BillingPlan` 增加 `storeProductMapping`。
- `OrderView` 扩为 `{id, planId, status(OrderStatus 枚举), amountMinor, currency, provider, storeTransactionId, expiresAt}`。
- 新增 `Entitlement {key, label, active, expiresAt}`、`Subscription {planId, status, renewAt}`、`StoreProduct`、`PurchaseResult`。

### 5.4 Checkout 流程（`membership.checkout` 屏幕）

`createOrder(idempotencyKey)` → 拿 `storeProductId` → `provider.purchase(storeProductId)` → `/purchases/verify` → 刷新 `/membership/current`。Loading 期间禁用按钮（QLT-08）。中断恢复：App 重启后查询既有 order 状态决定是否重新 verify（PAY-05 partial）。

## 6. Mock 适配器（三端共享语义）

- 服务端 `mockAdapter.verifyReceipt`：校验 receipt 结构 → 返回 `{ok, storeTransactionId, expiresAt}`；receipt 为 `{fail:true}` 时返回 `{ok:false}`（覆盖 PAY-04）。
- 服务端 `mockAdapter.parseWebhook`：识别 `{event:'renew'|'refund', orderId}` → 产出续订/退款事件（覆盖 PAY-03/12 mock 路径）。
- 客户端 `MockPaymentProvider`：不调真实商店，直接产出 receipt，让本地与 CI 跑通完整 E2E。
- 生产环境仍由 `paymentProvider()` 工厂禁用 mock（既有逻辑）。

## 7. 错误与状态（对齐统一模型）

- 所有支付错误走既有 `ApiError(code, messageKey, fieldErrors, traceId, retryable)`。
- 新增错误码：`PURCHASE_VERIFY_FAILED`、`PURCHASE_ALREADY_OWNED`、`WEBHOOK_SIGNATURE_INVALID`、`ORDER_NOT_FOUND`、`PRODUCT_NOT_MAPPED`、`PRODUCT_LOAD_FAILED`。
- 客户端 `purchaseState` / `restoreState` 走 sealed `AsyncState`（`Idle/Loading/Success/Empty/Failure/Offline/Unauthorized`），禁止用多布尔组合。

## 8. 测试与验收（对齐 `ACCEPTANCE_MATRIX.md`）

| 验收 ID | P-1 落地 | 状态目标 |
|---|---|---|
| PAY-01 金额服务端算 | `createOrder` 用 `plan.priceMinor` | IMPLEMENTED |
| PAY-02 幂等下单 | `(userId, idempotencyKey)` 唯一 | IMPLEMENTED |
| PAY-03 mock 成功 | mock E2E 全链路 | IMPLEMENTED |
| PAY-04 mock 失败 | receipt `{fail:true}` | IMPLEMENTED |
| PAY-05 中断恢复 | 重启后查 order 状态 | PARTIAL |
| PAY-06 webhook 去重 | 同 event_id ×10 只处理 1 次 | IMPLEMENTED |
| PAY-07 验签失败 | unavailable adapter → 401 + 安全事件（骨架） | PARTIAL |
| PAY-12 退款 | mock refund webhook | IMPLEMENTED(mock) |
| MEM-14 当前订阅 | `/membership/current` | IMPLEMENTED |
| MEM-16 恢复购买 | `/purchases/restore` 幂等补发 | IMPLEMENTED |

新增自动化测试（服务端 `npm test`）：

- `webhook dedup`：同一 `(provider, event_id)` 投递 10 次，`webhook_events` 与权益只变化 1 次。
- `idempotent order`：同一 idempotencyKey 重复 `POST /orders` 只产生 1 单。
- `entitlement atomicity`：verify 成功时 Order 与 UserEntitlement 同事务（注入中途失败 → 两者都不落）。
- `mock E2E`：smoke 脚本跑 createOrder → verify → restore → webhook refund。
- 三端契约：Flutter/RN/ArkTS 模型对 JSON Schema 快照校验（analyzer/typecheck + 快照测试）。

## 9. 文件触点清单

**服务端**

- 改：`src/domain/config.ts`（storeProductMapping + provider 联合）、`src/server/schemas.ts`（order/plan/webhook schema）、`src/server/payment-providers.ts`（PaymentAdapter）、`src/server/order-service.ts`（状态机 + verify/restore/webhook）、`src/server/order-repository.ts`（状态/去重/权益）、`src/server/database-schema-product.ts`（表结构）。
- 新：`src/server/entitlement-service.ts`、`src/server/webhook-service.ts`、`src/server/contract-snapshot.ts`（Zod→JSON Schema）、`src/app/api/v1/purchases/verify/route.ts`、`.../purchases/restore/route.ts`、`.../membership/current/route.ts`、`.../membership/entitlements/route.ts`、`.../webhooks/apple/route.ts`、`.../webhooks/google/route.ts`、`.../webhooks/hms/route.ts`，及对应 `*.test.ts`。

**Flutter（参考实现）**

- 新：`lib/payment/payment_provider.dart`、`payment_repository.dart`、`payment_controller.dart`、`payment_scope.dart`、`payment_models.dart`、`mock_payment_provider.dart`、`checkout_screen.dart`。
- 改：`lib/app/runtime_models.dart`（BillingPlan/OrderView 扩展 + 新模型）、`lib/navigation/app_router.dart` + `app_route.dart`（checkout 独立屏幕）、`lib/screens/profile_screens.dart`（MembershipScreen 接 checkout）。

**React Native / ArkTS**

- P-1 阶段：镜像契约（模型字段、路由 ID、state 语义、错误码），保证三端一致；真实平台集成在 P-2/3/4 各自 spec。

## 10. 风险与未决

1. **HMS 商品 ID 体系**：`storeProductMapping.hms` 与华为 IAP Kit product id 的对应关系需在 P-4 真机验证；P-1 先按字符串建模。
2. **OpenAPI 缺位**：P-0 未做全量 OpenAPI；P-1 用 Zod→JSON Schema 快照兜底契约测试，后续迁到正式 OpenAPI 时可能要调整测试入口。
3. **订阅与一次性购买模型合一**：P-1 按"每笔 order 对应 entitlement/subscription 记录"建模；复杂升降级、价差、额度账本（`UsageLedger`）留 P-5。
4. **签名校验仅为骨架**：PAY-07 在 P-1 只对 unavailable provider 返回 401 + 安全事件；真实 Apple/Google/HMS 签名/证书校验在 P-2/3/4 落地。
