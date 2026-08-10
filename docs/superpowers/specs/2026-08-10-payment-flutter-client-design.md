# P-1.2 Flutter 支付客户端 — 设计

版本：1.0　日期：2026-08-10　状态：待评审
所属：MobileStarter 三商城 IAP · P-1 支付抽象 · 客户端参考实现（Flutter）。消费已上线的 P-1.1 服务端 API（main 分支）。

## 0. 背景与范围

P-1.1 已在 `main` 上交付服务端支付抽象（`/orders` 返回 pending、`/purchases/verify|restore`、`/membership/{current,entitlements}`、`PaymentAdapter` + mock）。**现有 Flutter 客户端的购买 UX 已因此失效**：`MembershipScreen._purchase` → `AppController.purchase` → `POST /orders` 期望 mock 自动完成，但 P-1.1 后 `/orders` 只返回 pending，必须再调 `/purchases/verify`。

P-1.2 交付 **Flutter 参考客户端**：在 `payment/` 子域实现 `PaymentProvider` 契约 + `MockPaymentProvider`（P-1.2 不引 `in_app_purchase`，真实商店 SDK 留 P-2）+ 服务端 `PaymentRepository` + scoped `PaymentController`/`PaymentScope` + 模型扩展 + 独立 `CheckoutScreen`，并把 MembershipScreen 接到新流程。

**范围：仅 Flutter。** RN / ArkTS 的契约对齐（模型字段、路由 ID、状态语义、错误码）留 P-1.3。

### 设计依据（已确定，不再重议）
- 镜像 `flutter/lib/support/` 子域模式（独立 repository/controller/scope），**不**往 `AppRepository`/`AppController` 两个 god-class 里塞。
- 状态用既有 sealed `AsyncState<T>`（`Idle/Loading/Success/Empty/Failure/Offline/Unauthorized`），禁多布尔组合。
- 真实环境测试：打真服务端 + 真 `mobileui_dev` 库，**不用 fake** repository/provider（见 §6）。

## 1. 目标与非目标

### 目标
1. 定义三端共享的客户端 `PaymentProvider` 契约（Flutter 实现；RN/ArkTS 在 P-1.3 镜像）。
2. `MockPaymentProvider`：不依赖商店 SDK，产出服务端可验证的 receipt，让本地与 CI 跑通完整链路。
3. `PaymentRepository`：覆盖 P-1.1 的 `/orders`、`/purchases/verify|restore`、`/membership/current|entitlements`、`GET /orders`，复用既有 401 单飞刷新语义。
4. scoped `PaymentController` + `PaymentScope`：`checkout(planId)` 编排 createOrder→purchase→verify→刷新，状态走 `AsyncState`。
5. 模型扩展：`BillingPlan.storeProductMapping`、`OrderView` 完整字段、`Entitlement`/`Subscription`。
6. 独立 `CheckoutScreen`（`membership.checkout` 路由），MembershipScreen 接入。
7. 移除被取代的 `AppController.purchase` + `AppRepository.purchase`。

### 非目标（P-1.3 / P-2+）
- RN / ArkTS 客户端对齐（P-1.3）。
- 真实 `in_app_purchase` / StoreKit / Play Billing / HMS IAP（P-2/3/4）。
- 试用、首购价、多档额度、升降级 UI（P-5）。
- 真实商店的恢复购买（P-1.2 的 restore 走 mock provider）。

## 2. 组件（`flutter/lib/payment/`）

### 2.1 `payment_provider.dart` — 商店抽象
```dart
abstract interface class PaymentProvider {
  /// 按 storeProductMapping 预加载商品（真实 SDK 在 P-2 查商店；mock 直接回填）。
  Future<List<StoreProduct>> loadProducts(StoreProductMapping? mapping);
  /// 发起购买，返回服务端可验证的 receipt。失败抛 ApiException。
  Future<PurchaseResult> purchase(String storeProductId);
  /// 恢复购买：返回本机已"拥有"的商品 receipts。
  Future<List<PurchaseResult>> restore();
}
```
- `StoreProduct {storeProductId, priceMinor, currency, title}`。
- `PurchaseResult {storeProductId, receipt}`（`receipt` 透传给服务端，类型 opaque）。
- P-1.2 实现 `MockPaymentProvider`：`purchase(id)` → `PurchaseResult(storeProductId:id, receipt:{'productId':id})`；用内存 `Set` 跟踪已购 productId，`restore()` 回放它们。`fail` 路径用于测试失败态：`purchase(id, fail:true)` 产 `receipt:{'productId':id,'fail':true}`，服务端 mock 返回 `{ok:false}`。

### 2.2 `payment_repository.dart` — 服务端客户端（镜像 `support_repository.dart`）
自带 `_request`、租户头（`x-app-id`/`x-app-environment` 来自 `MOBILEUI_APP_ID`/`MOBILEUI_APP_ENVIRONMENT` dart-define）、`x-platform`、`accept-language`；base URL 来自 `MOBILEUI_API_URL`（默认 `http://localhost:3210`）；从 `TokenStore` 读 bearer；401 单飞刷新 + 会话过期回调。
```dart
Future<CreateOrderResult> createOrder(String planId, {required String idempotencyKey}); // POST /orders → {orderId, storeProductId, status}
Future<OrderView> verifyPurchase({String? orderId, required Object receipt});            // POST /purchases/verify
Future<List<String>> restore(List<Object> receipts);                                     // POST /purchases/restore → entitlement keys
Future<MembershipCurrent> membershipCurrent();                                           // GET /membership/current
Future<List<String>> entitlements();                                                     // GET /membership/entitlements
Future<List<OrderView>> orders();                                                        // GET /orders
```
错误：非 2xx 抛 `ApiException(code, message, status, fieldErrors)`（与 `AppRepository` 同契约）。

### 2.3 `TokenStore`（token 读写抽象）
```dart
abstract interface class TokenStore { Future<String?> read(); Future<void> write(String? token); }
```
- 生产：`SecureTokenStore`（`flutter_secure_storage`，key 与 `AppRepository` 一致：`mobileui.sessionToken`）。
- 测试：`InMemoryTokenStore`（见 §6 关于 VM 无 keychain 的说明）。
> 这是平台依赖在 Dart VM 测试环境下的适配器，**不 fake 任何业务/服务端/provider**——测试里存的是真 signup 拿到的真 token、打真服务端。

### 2.4 `payment_controller.dart` + `payment_scope.dart`
`PaymentController extends ChangeNotifier`，构造注入 `(PaymentRepository, PaymentProvider)`，经 `PaymentScope`（`InheritedNotifier`）暴露，挂在 `MobileUiApp.build` 与 `AppScope` 同级（镜像 `support_scope` 挂载点）。
```dart
AsyncState<OrderView> purchaseState;   // Idle/Loading/Success/Empty/Failure/Offline/Unauthorized
AsyncState<List<String>> restoreState;
Future<bool> checkout(String planId);  // 见 §3 数据流
Future<bool> restorePurchases();
```
Loading 期间 `checkout` 禁用（幂等、不可重复提交，QLT-08）。`Unauthorized` → 触发会话过期（回 SignIn，与 AppController 同机制）。

### 2.5 `payment_models.dart` — 模型扩展
- `StoreProductMapping {apple?, google?, hms?}`（`fromJson` 容错缺失键）。
- `BillingPlan` 增 `storeProductMapping`（在 `runtime_models.dart` 现有 `BillingPlan` 上加字段 + fromJson）。
- `OrderView` 扩为 `{id, planId, status(OrderStatus 枚举), amountMinor, currency, provider, storeTransactionId, expiresAt}`（对齐 P-1.1 `OrderView`，客户端用子集）。
- `Entitlement {key, expiresAt}`、`Subscription {planId, status, renewAt}`、`MembershipCurrent {tier, entitlements, subscription}`。
> `runtime_models.dart` 已被刚提交的 splash 工作（tagline/nullable splash）改过；P-1.2 只**新增** `BillingPlan.storeProductMapping` 字段，不动 splash 相关字段，互不冲突。

### 2.6 `CheckoutScreen`（`screens/checkout_screen.dart`）
独立确认页（`membership.checkout` 路由）。展示：方案名、周期、价格（来自 `controller.config.plans` 按 planId 查）、权益摘要（tier.entitlements）、"确认订阅"按钮 → `PaymentScope.of(context).checkout(planId)`。按 `purchaseState` 切换：Loading→进度 + 禁用按钮；Success→成功态 + 跳订单/会员页；Failure/Offline→重试；Unauthorized→回登录。Mock provider 显示"演示支付"角标（沿用 MembershipScreen 现有 mock 分支语义）。

## 3. 数据流（checkout）

```text
CheckoutScreen 确认
  → PaymentController.checkout(planId)
    → repo.createOrder(planId, idempotencyKey=uuid)        // POST /orders → {orderId, storeProductId}
    → provider.purchase(storeProductId)                    // MockPaymentProvider → receipt
    → repo.verifyPurchase(orderId, receipt)                // POST /purchases/verify → OrderView(success)
    → repo.membershipCurrent()                             // 刷新本地 membership 缓存
    → purchaseState = Success(order)
  失败任意一步 → purchaseState = Failure/Offline/Unauthorized（不发权益、不假成功）
```
`restorePurchases()`：`provider.restore()` → `repo.restore(receipts)` → `restoreState`。

## 4. 接入点改动
- `app_router.dart`：`AppRoute.checkout` → `CheckoutScreen()`（当前指向 MembershipScreen，改为独立页）。
- `profile_screens.dart` MembershipScreen：`_purchase` 改为 `Navigator.push(checkout)`（带 planId），不再直接调 `controller.purchase`。
- 移除 `AppController.purchase` + `AppRepository.purchase` + 其 `orders` 字段中由 purchase 维护的部分（`loadOrders`/`orders` 改由 `PaymentRepository.orders` 提供；MembershipScreen 的订单列表改读 PaymentScope）。
- `mobile_ui_app.dart`：挂载 `PaymentScope`（同级 `AppScope`/`SupportScope`）。

## 5. 错误与状态
- 全部走 `ApiException` + `AsyncState`；新错误码透传服务端：`PRODUCT_NOT_MAPPED`、`ORDER_NOT_FOUND`、`PURCHASE_VERIFY_FAILED`。
- `purchaseState`/`restoreState` Loading 时禁用按钮、不重复提交。
- 网络层：超时/断网 → `Offline`；401（刷新后仍）→ `Unauthorized` → 会话过期回 SignIn。

## 6. 测试（真实环境，无 fake）

**哲学**：与服务端 `payment.test.ts` 一致——打真服务端 + 真 `mobileui_dev` 库，业务逻辑零 fake。唯一适配：`TokenStore` 用 `InMemoryTokenStore`（Dart VM 无 keychain）。

**前置**（测试运行前）：
1. 服务端在跑：`cd server && AUTH_DATABASE_URL='postgresql://mediagrab:mediagrab_dev@newmedia:5432/mobileui_dev' npm run dev`（监听 :3210）。
2. 重置库（避免 fixed-key 污染）：`DROP SCHEMA public CASCADE; CREATE SCHEMA public;`（schema 在服务端首次请求时自动重建）。
3. `flutter test` 用 `--dart-define=MOBILEUI_API_URL=http://localhost:3210 --dart-define=MOBILEUI_APP_ID=zhongbei --dart-define=MOBILEUI_APP_ENVIRONMENT=development`。

**测试套件** `flutter/test/payment/`：
- `checkout_flow_test.dart`：signup（`POST /api/v1/auth/sign-up`）拿真 token → `InMemoryTokenStore` 注入真 `PaymentRepository` + 真 `MockPaymentProvider` → `checkout(planId)`：断言 `purchaseState` `Idle→Loading→Success`，`OrderView.status=='success'`，`membershipCurrent().entitlements` 非空。
- `verify_failure_test.dart`：`MockPaymentProvider.purchase(id, fail:true)` → `purchaseState==Failure`，membership entitlements 为空（不发权益）。
- `idempotent_checkout_test.dart`：同一 `idempotencyKey` 两次 `createOrder` 返回同一 orderId。
- `ownership_test.dart`（对齐服务端）：A 用户的 orderId 拿去 B 用户 verify → 失败。
- `restore_test.dart`：`MockPaymentProvider` 先 purchase 再 restore → entitlements 恢复。
- `payment_models_test.dart`：`BillingPlan.fromJson` 含 `storeProductMapping`；`OrderView` status 枚举。

`flutter analyze` 全绿。CI 顺序：起服务端 → 重置库 → `flutter test`（带 dart-define）→ `flutter analyze`。

## 7. 文件清单
**新建**：`lib/payment/{payment_provider,payment_repository,payment_controller,payment_scope,payment_models}.dart`、`lib/payment/mock_payment_provider.dart`、`lib/payment/token_store.dart`、`lib/screens/checkout_screen.dart`、`test/payment/{checkout_flow,verify_failure,idempotent_checkout,ownership,restore,payment_models}_test.dart`。

**修改**：`lib/app/runtime_models.dart`（`BillingPlan` 加 `storeProductMapping` 字段、`OrderView` 加 status/provider/storeTransactionId/expiresAt 字段——原地扩展，不搬迁）、`lib/app/app_router.dart`（checkout→CheckoutScreen）、`lib/app/app_controller.dart`（删 `purchase`）、`lib/app/app_repository.dart`（删 `purchase`，`orders` 改读 `PaymentRepository`）、`lib/screens/profile_screens.dart`（MembershipScreen 接 checkout）、`lib/app/mobile_ui_app.dart`（挂 `PaymentScope`）。

> 模型归属：`BillingPlan`/`OrderView` 在 `runtime_models.dart` 原地扩展（它们本就在那）；`StoreProductMapping`/`Entitlement`/`Subscription`/`MembershipCurrent`/`StoreProduct`/`PurchaseResult` 等新类型放 `lib/payment/payment_models.dart`。

## 8. 验收（对应客户端侧）
- MEM-09/10（方案/价格从服务端 + storeProductMapping 渲染）、MEM-14（当前订阅从 `/membership/current`）、MEM-16（恢复购买）的 Flutter 侧落地。
- PAY-03/04（mock 成功/失败 E2E，客户端→服务端）、PAY-05（中断恢复：订单状态可查询重试）的客户端侧。
- QLT-07（网络异常可恢复）、QLT-08（防重复提交）、QLT-09（token 不入 UI/日志）。

## 9. 风险与未决
1. **VM 无 keychain**：`TokenStore` 抽象 + `InMemoryTokenStore` 测试适配（见 §6）。若要求连 keychain 一起打，改 `integration_test` 上模拟器（重得多，留作备选）。
2. **服务端必须运行**：`flutter test` 是集成测试，依赖 :3210 在跑 + 库可达。CI 需先起服务端。
3. **mock provider 的 restore 语义**：P-1.2 用内存 Set 跟踪"已购"；真机 restore 由商店 SDK 驱动（P-2+），契约不变。
4. **删除 `AppRepository.purchase`/`AppController.purchase`** 可能影响其他引用——实现时 grep 确认无残留调用。
