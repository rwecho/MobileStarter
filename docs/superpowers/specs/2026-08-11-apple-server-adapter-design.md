# P-2a 服务端 Apple Adapter + ASSN V2 Webhook — 设计

版本：1.0　日期：2026-08-11　状态：待评审
所属：MobileStarter 三商城 IAP · P-2 Apple · 服务端第一半。把 P-1 的 `unavailable('apple')` 桩换成真实 Apple 验签 + ASSN V2 处理，复用 P-1.1 已建的订单/权益/去重/事务骨架。

## 0. 背景与范围

P-1.1 已在 `main` 上搭好支付抽象：`PaymentAdapter` 接口、`order-service.verifyPurchase`（同事务完成订单+发权益+订阅）、`webhook-service.applyWebhook`（`(provider,event_id)` 去重 + refund→撤权益）、`/webhooks/apple` 路由。但 Apple 渠道是 **503/401 桩**（`unavailable('apple')`）——`verifyReceipt` 抛 503、`parseWebhook` 抛 401。

P-2a 用 **Apple 官方库 `@apple/app-store-server-library`** 实现真实 `ApplePaymentAdapter`：
- `verifyReceipt`：验签客户端发来的 StoreKit 2 签名交易 JWS，提取商品/到期/退款。
- `parseWebhook`：验签 ASSN V2（App Store Server Notifications V2）的 `signedPayload`，映射 `notificationType` → `WebhookEvent`。

P-1.1 的订单/权益/去重/事务逻辑**不动**——P-2a 只补"Apple 这一份"的验签+解析。

### 验证标准（已与用户确认）
**本地真验证，无需 Apple 私钥/沙盒/设备。** 验签只用 **Apple 公开根 CA**（下载，非密钥）+ **Apple 官方库自带的签名测试 fixtures**（真 Apple 测试 CA 签的 JWS）。`node:test` 喂这些真签名 JWS 给 adapter，断言验签/解码/去重/权益发放。私钥（issuer ID/key ID/.p8）、Server API 权威复查、客户端 StoreKit、真机沙盒——**全部留 P-2b**。

## 1. 目标与非目标

### 目标
1. 真实 `ApplePaymentAdapter implements PaymentAdapter`（`verifyReceipt` + `parseWebhook`），基于 `@apple/app-store-server-library` 的 `SignedDataVerifier`。
2. `verifyReceipt`：验签 StoreKit 2 签名交易 JWS → `VerifyResult { ok, storeTransactionId, productId, expiresAt, refund }`。
3. `parseWebhook`：验签 ASSN V2 `signedPayload` → 提取 `originalTransactionId` + `notificationType` → 查我们订单（按 `store_transaction_id`）→ `WebhookEvent { kind, orderId, eventId }`。
4. `payment-providers.ts`：`apple` 从 `unavailable` 换成 `new ApplePaymentAdapter(...)`；`/webhooks/apple` 路由不变（已走 `applyWebhook('apple')`）。
5. Apple 根 CA 证书（公开）入 `server/certs/`；非密配置入 env（`APPLE_BUNDLE_ID`/`APPLE_APP_APPLE_ID`/`APPLE_ENVIRONMENT`）。
6. 真签名测试（Apple 测试 CA + 官方 fixtures）：验签有效/篡改、webhook 有效/×10 去重/refund→撤权益/坏签名 401。

### 非目标（P-2b 及以后）
- 客户端 `in_app_purchase` / `IapPaymentProvider` / iOS 签名 / 真机沙盒 E2E。
- App Store Server API v2 权威复查（`getAllSubscriptionStatuses`/`getTransactionInfo`——需 issuer 私钥）。
- 订阅状态的细粒度更新（`DID_CHANGE_RENEWAL_STATUS`/`GRACE_PERIOD`→只更新 `subscriptions.status`，留作 P-2b 增强；P-2a 把非-refund 映射成 `renew`，P-1.1 的 `applyWebhook` 对 renew 为 no-op+注释）。
- StoreKit Testing 自建 harness（若官方 fixtures 不足再说）。

## 2. 组件

### 2.1 `server/src/server/apple-adapter.ts`（新建）
构建一个**单例 `SignedDataVerifier`**（懒加载，用配置 + 根 CA）：
```ts
import { SignedDataVerifier } from '@apple/app-store-server-library'
// verifier = new SignedDataVerifier(appleRootCerts, enableOnlineChecks=false, environment, bundleId, appAppleId)
```
`ApplePaymentAdapter implements PaymentAdapter`：
- `id = 'apple'`
- `verifyReceipt({ receipt })`：`receipt` 是客户端发来的 **StoreKit 2 签名交易 JWS 字符串**。
  ```text
  const tx = await verifier.verifyAndDecodeTransaction(receipt)  // 库方法名以 writing-plans 核对为准
  // tx: { originalTransactionId, productId, expiresDateMs?, type, ... }
  return {
    ok: true,
    storeTransactionId: tx.originalTransactionId,
    productId: tx.productId,
    expiresAt: tx.expiresDateMs ? new Date(tx.expiresDateMs).toISOString() : null,  // 一次性购买为 null
    refund: false,  // 退款走 webhook,不在交易里
  }
  ```
  验签失败（库抛错）→ `catch` → `return { ok: false }`（不抛——P-1.1 的 verifyPurchase 据此把订单置 failed）。
- `parseWebhook(rawBody, headers)`：Apple POST 的 body 是 `{ signedPayload: <JWS> }`。
  ```text
  const payload = JSON.parse(rawBody).signedPayload
  const notif = await verifier.verifyAndDecodeNotification(payload)  // 库方法名以 writing-plans 为准
  // notif: { notificationType, subtype?, data: { signedTransactionInfo?, originalTransactionId?, ... } }
  // 解出 originalTransactionId（直接字段 或 decode data.signedTransactionInfo）
  const order = await findOrderByStoreTransactionId(originalTransactionId)  // 新 repo 查询
  const kind = notif.notificationType === 'REFUND' ? 'refund' : 'renew'
  return { provider: 'apple', eventId: notif.notificationUUID, kind, orderId: order?.id ?? '' }
  ```
  > `orderId` 用我们内部订单 id（按 `store_transaction_id` 反查）。若找不到订单（未验签过）→ 返回 `{applied:false}` 上游语义（webhook-service 已对 null/未知 order 安全处理）。
  验签失败 → 抛 `ApiError(401, 'WEBHOOK_SIGNATURE_INVALID', ...)`（P-1.1 webhook-service/路由 catch）。

### 2.2 订单反查（`order-repository.ts`，新增一个查询）
`findOrderByStoreTransactionId(storeTransactionId: string): Promise<OrderView | undefined>` —— `SELECT ... FROM orders WHERE store_transaction_id = ?`。P-1.1 的 `completeOrder` 已把 `result.storeTransactionId` 写进 `orders.store_transaction_id`，所以验签成功后这条关联就建立了。

### 2.3 `payment-providers.ts`
```ts
['apple', new ApplePaymentAdapter({ verifier })],
```
构造 verifier 的配置从 env 读：`APPLE_BUNDLE_ID`、`APPLE_APP_APPLE_ID`（数字）、`APPLE_ENVIRONMENT`（`'Sandbox'`/`'Production'`，库的枚举）。根 CA 从 `server/certs/*.cer` 加载（启动时读文件）。
> 库的 `SignedDataVerifier` 构造参数顺序/枚举名以 writing-plans 阶段用代理核对库 `.d.ts` 为准；上面是形状，不是精确签名。

### 2.4 配置
- env（非密，可入 `.env.local`/部署 env）：`APPLE_BUNDLE_ID`、`APPLE_APP_APPLE_ID`、`APPLE_ENVIRONMENT`。
- `server/certs/`：Apple 公开根 CA（3 个 `.cer`，从 Apple 下载，非密钥，提交进库）+ **测试用** Apple 测试根 CA（库 fixtures 用的）。
- **不引入私钥**（P-2a 验签不需要；Server API 权威复查留 P-2b）。

## 3. 数据流
```text
verify（客户端驱动，P-1.1 已建）:
  客户端 {orderId?, receipt:<StoreKit2 signedTx JWS>} → POST /purchases/verify
  → order-service.verifyPurchase → ApplePaymentAdapter.verifyReceipt(receipt)
  → SignedDataVerifier.verifyAndDecodeTransaction → {productId, originalTransactionId, expiresDateMs}
  → P-1.1 同事务: completeOrder(storeTransactionId=originalTransactionId) + findPlanByProductId + 发权益 + upsertSubscription
  → 返回 OrderView(success)

webhook（Apple 驱动）:
  Apple → POST /webhooks/apple {signedPayload:<JWS>} → applyWebhook('apple', body, headers)
  → ApplePaymentAdapter.parseWebhook → verifyAndDecodeNotification → {notificationType, originalTransactionId, notificationUUID}
  → findOrderByStoreTransactionId → WebhookEvent{kind, orderId, eventId}
  → P-1.1 webhook-service: (provider,eventId) 去重 → refund→refundOrder+revokeEntitlementsForOrder；renew→no-op
```

## 4. 错误与状态
- 交易 JWS 验签失败 → `verifyReceipt` 返回 `{ok:false}` → P-1.1 把订单置 `failed`、不发权益（**不假成功**）。
- ASSN V2 验签失败 → `parseWebhook` 抛 401 `WEBHOOK_SIGNATURE_INVALID` → 路由 handleError → 401。
- 找不到订单（originalTransactionId 未见过）→ `parseWebhook` 返回事件但 `orderId=''`；webhook-service 的 `findOrderById('')` 返回 undefined → `{applied:false}`，不崩。
- ASSN V2 `notificationType` 非 REFUND（DID_RENEW/EXPIRED/GRACE...）→ 映射 `renew`，P-1.1 当前 no-op（订阅状态细粒度更新留 P-2b）。

## 5. 测试（本地真验证）
**真 Apple 加密**：用 Apple 官方库自带的测试 fixtures（真 Apple 测试 CA 签的 JWS）+ Apple 测试根 CA。Verifier 配成测试链跑真签名校验。`node:test`：
- `verifyReceipt` 有效签名交易 JWS → `{ok:true, productId, expiresAt}`；篡改 JWS → `{ok:false}`。
- `/webhooks/apple` 有效 REFUND signedPayload → 订单 refunded + 权益撤销；×10 同 `notificationUUID` → 只生效 1 次（去重）。
- `/webhooks/apple` 坏签名 → 401。
- 订单反查：先 verify 一笔（写入 store_transaction_id），再喂对应 REFUND webhook → 撤到正确订单的权益。
- 测试向量来源：Apple 库 test/ 目录的 fixtures（signed transaction + notification + 测试根 CA）；writing-plans 阶段用代理核对库的 fixtures 文件名/路径并嵌入测试。若官方 fixtures 不含退款 notification，用 `signedTransactionInfo` 构造或退而用 StoreKit Testing harness（P-2a 备选）。
- 前置：与 P-1.1 同一套（reset `mobileui_dev` + `AUTH_DATABASE_URL`）。

## 6. 文件清单
**新建**：`server/src/server/apple-adapter.ts`、`server/certs/`（Apple 根 CA + 测试根 CA）。
**修改**：`server/src/server/payment-providers.ts`（apple→ApplePaymentAdapter）、`server/src/server/order-repository.ts`（+`findOrderByStoreTransactionId`）、`server/src/server/schemas.ts`（receipt 已是 opaque，无需改）、`server/tests/payment-apple.test.ts`（新建测试）、`server/package.json`（+`@apple/app-store-server-library`）。
**不改**：`order-service.ts`、`webhook-service.ts`、`entitlement-service.ts`、路由文件（P-1.1 已就绪）。

## 7. 验收
- PAY-08（Apple 校验）：真实 ApplePaymentAdapter 验签 StoreKit 2 JWS，productId/交易映射一致（用 Apple fixtures 真测，非桩）。
- PAY-06/07：webhook 去重 ×10→1；坏签名 401 + 安全事件。
- PAY-12：REFUND webhook → 订单 refunded + 权益撤销（通过 store_transaction_id 反查到正确订单）。
- P-1.1 全套（48）不回归 + 新增 Apple 测试。

## 8. 风险与未决
1. **测试向量可得性**：Apple 官方库 test/ 的 fixtures 是否包含「签名交易 + REFUND notification + 测试根 CA」三件套——writing-plans 阶段用代理核对；若缺 REFUND notification，备选 StoreKit Testing harness 或社区样本（仍是真 Apple 加密）。
2. **库 API 精确签名**：`SignedDataVerifier` 构造参数顺序、`verifyAndDecodeTransaction`/`verifyAndDecodeNotification` 方法名、环境枚举（`Sandbox`/`Production`）、named vs default export（已知坑：`SignedDataVerifier` 是 named export）——writing-plans 阶段用代理/Context7 核对库 `.d.ts`，不靠记忆。
3. **`store_transaction_id` 反查索引**：高频 webhook 下 `findOrderByStoreTransactionId` 可能需要索引；P-2a 量级不大，先不加，P-2b/上线前评估。
4. **ASSN V2 订阅状态细粒度更新**（renew/grace/expire → subscriptions.status）留 P-2b，P-2a 只 REFUND 可执行 + 其余 renew(no-op)。
