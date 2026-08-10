# P-1.1 服务端支付抽象 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 MobileStarter 模板的服务端支付能力从"mock 自动完成"升级为"客户端驱动 + 服务端验票"的契约式抽象，用 Mock 适配器跑通完整链路（下单→验票→发权益→webhook 续订/退款），让真实 Apple/Google/HMS（P-2/3/4）只需替换 adapter。

**Architecture:** 复用既有 `orders` 表 + `payment-providers.ts` + `order-service.ts`，扩展为：`PaymentAdapter` 接口（verifyReceipt/parseWebhook）+ Order 状态机（pending→processing→success/failed→refunded）+ 三张新表（`user_entitlements`/`subscriptions`/`webhook_events`）+ 7 个新路由。Order 确认与权益发放在同一数据库事务；webhook 按 `(provider,event_id)` 去重。客户端实现（Flutter/RN/ArkTS）在 P-1.2。

**Tech Stack:** Next.js 16 App Router · TypeScript 5.9 · Zod 4.1（`z.toJSONSchema()` 出契约快照）· Postgres（经 `PostgresDatabase` 的 SQLite 风格 `prepare().run/get/all` + `runTransaction`）· `node:test`。

**前置条件（执行前必须满足）：** Postgres 已启动且 `server/` 环境变量可连（与现有 `npm test` 相同基线）。当前分支 `spec/payment-p1-foundation`。

**重要约定（贯穿全计划）：**
- 状态值沿用既有代码：订单终态用 `success`（不是 `succeeded`），不用 `closed`。
- DB 写入走 `database.prepare(sql).run/get/all(...)` + `?` 占位符；建表在 `initializeProductSchema`（`CREATE TABLE IF NOT EXISTS`），加列在 `applyIdempotentMigrations`（`ALTER TABLE ... ADD COLUMN IF NOT EXISTS`）+ 同步更新 CREATE 语句。
- 所有业务表写入带 `app_id`。
- 单测文件 `tests/payment.test.ts`，沿用 `auth.test.ts` 模式：`import test from 'node:test'` + `node:assert/strict` + `await import('../src/server/*.ts')` + 真实 `database`，`after(() => database.close())`。
- 单文件运行命令（变量 `$RUN`）：`node --import ./tests/register.mjs --test --experimental-transform-types tests/payment.test.ts`（在 `server/` 目录执行）。
- 本计划会改变 `POST /api/v1/orders` 的行为：mock 不再自动完成，只返回 `pending`。现有 Flutter 客户端的 mock 购买 UX 会因此暂停工作，直到 P-1.2 接入新的 verify 流程。本计划的"可用软件"= 服务端 + `tests/payment.test.ts` 全绿 + 契约快照 + `typecheck`/`lint` 通过。

---

## 文件结构

**修改**
- `server/src/domain/config.ts` — `BillingPlan` 加 `storeProductMapping` + provider 联合加 `'hms'`；`defaultConfig.plans` 补映射样例。
- `server/src/server/schemas.ts` — `planSchema` 加 `storeProductMapping` + provider 加 `'hms'` + superRefine 规则；新增 `verifyPurchaseSchema`、`restorePurchasesSchema`。
- `server/src/server/payment-providers.ts` — 重写为 `PaymentAdapter` 接口 + `mockAdapter` + `unavailableAdapter` + `storeKeyForPlatform`。
- `server/src/server/order-service.ts` — 重写：`createOrder`（pending + storeProductId）、新增 `verifyPurchase`/`restorePurchases`；移除旧 `provider.start()` 自动完成。
- `server/src/server/order-repository.ts` — 扩展 `OrderView` + 新增 `insertPendingOrder`/`completeOrder`/`findOrderById`/`findOrderByReceiptHash`/`insertWebhookEventIfNew`/entitlement/subscription 读写。
- `server/src/server/database-schema-product.ts` — `orders` 加列；新增 3 张表。
- `server/src/server/database.ts` — `applyIdempotentMigrations` 加 `orders` 的 ALTER。
- `server/package.json` — `test` 脚本加 `tests/payment.test.ts`。

**新建**
- `server/src/server/entitlement-service.ts` — 权益发放/撤销（与订单同事务）。
- `server/src/server/webhook-service.ts` — webhook 去重 + 续订/退款应用。
- `server/src/server/contract-snapshot.ts` — `z.toJSONSchema()` 导出支付契约快照。
- `server/src/app/api/v1/purchases/verify/route.ts`
- `server/src/app/api/v1/purchases/restore/route.ts`
- `server/src/app/api/v1/membership/current/route.ts`
- `server/src/app/api/v1/membership/entitlements/route.ts`
- `server/src/app/api/v1/webhooks/apple/route.ts`
- `server/src/app/api/v1/webhooks/google/route.ts`
- `server/src/app/api/v1/webhooks/hms/route.ts`
- `server/tests/payment.test.ts`

---

## Task 1: Schema 层 —— storeProductMapping、hms provider、购买请求 schema

**Files:**
- Modify: `server/src/domain/config.ts`
- Modify: `server/src/server/schemas.ts`
- Test: `server/tests/payment.test.ts`（新建）

- [ ] **Step 1: 写失败测试**（新建 `tests/payment.test.ts`）

```ts
import assert from 'node:assert/strict';
import test from 'node:test';
const { database } = await import('../src/server/database.ts');
const { defaultConfig } = await import('../src/domain/config.ts');
const { runtimeConfigSchema, verifyPurchaseSchema, restorePurchasesSchema } = await import('../src/server/schemas.ts');
after(async () => database.close());

test('BillingPlan 支持 storeProductMapping 与 hms provider', () => {
  const plan = {
    id: 'pro-monthly', tierId: 'pro', name: 'Pro 月度', interval: 'month',
    priceMinor: 1800, currency: 'CNY', provider: 'hms' as const,
    storeProductMapping: { hms: 'pro.monthly_001' },
  };
  const parsed = runtimeConfigSchema.parse({ ...defaultConfig, plans: [plan] });
  assert.equal(parsed.plans[0].storeProductMapping?.hms, 'pro.monthly_001');
});

test('provider 为 apple/google/hms 但缺对应映射时 schema 拒绝', () => {
  const plan = {
    id: 'bad', tierId: 'pro', name: 'Bad', interval: 'month',
    priceMinor: 100, currency: 'CNY', provider: 'apple' as const,
    storeProductMapping: { google: 'x' }, // 缺 apple
  };
  assert.throws(() => runtimeConfigSchema.parse({ ...defaultConfig, plans: [plan] }));
});

test('购买请求 schema 校验', () => {
  assert.ok(verifyPurchaseSchema.safeParse({ receipt: { productId: 'p' } }).success);
  assert.ok(verifyPurchaseSchema.safeParse({ orderId: 'o1', receipt: {} }).success);
  assert.equal(verifyPurchaseSchema.safeParse({}).success, false);
  assert.ok(restorePurchasesSchema.safeParse({ receipts: [{ productId: 'p' }] }).success);
  assert.equal(restorePurchasesSchema.safeParse({ receipts: [] }).success, false);
});
```

- [ ] **Step 2: 运行确认失败**

Run (in `server/`): `node --import ./tests/register.mjs --test --experimental-transform-types tests/payment.test.ts`
Expected: FAIL — `storeProductMapping` 不存在 / `verifyPurchaseSchema` 未导出。

- [ ] **Step 3: 实现 —— `domain/config.ts`**

在 `BillingPlan` 类型上方加映射类型，并扩展 `BillingPlan`：

```ts
export type StoreProductMapping = Readonly<{ apple?: string; google?: string; hms?: string }>;

export type BillingPlan = Readonly<{
  id: string;
  tierId: string;
  name: string;
  interval: 'month' | 'year' | 'lifetime' | 'one_time';
  priceMinor: number;
  currency: string;
  originalPriceMinor?: number;
  provider: 'mock' | 'apple' | 'google' | 'hms' | 'wechat' | 'alipay';
  storeProductMapping?: StoreProductMapping;
}>;
```

`defaultConfig.plans` 把第一个方案补上映射（保持 provider 为 `mock`，供本地与 mock 客户端使用）：

```ts
  plans: [
    {
      id: 'pro-monthly',
      tierId: 'pro',
      name: 'Pro 月度',
      interval: 'month',
      priceMinor: 1800,
      currency: 'CNY',
      provider: 'mock',
      storeProductMapping: { apple: 'com.zhongbei.pro.monthly', google: 'pro_monthly_001', hms: 'pro_monthly_001' },
    },
    // ...其余两个方案保持不变
  ],
```

- [ ] **Step 4: 实现 —— `schemas.ts`**

替换 `planSchema`，新增请求 schema，并在 `runtimeConfigSchema` 的 `superRefine` 里加映射规则：

```ts
const storeProductMappingSchema = z.object({
  apple: z.string().min(1).max(200).optional(),
  google: z.string().min(1).max(200).optional(),
  hms: z.string().min(1).max(200).optional(),
}).optional();

const planSchema = z.object({
  id: z.string().regex(/^[a-z0-9-]+$/),
  tierId: z.string().min(1),
  name: z.string().min(1).max(60),
  interval: z.enum(['month', 'year', 'lifetime', 'one_time']),
  priceMinor: z.number().int().nonnegative(),
  currency: z.string().length(3),
  originalPriceMinor: z.number().int().positive().optional(),
  provider: z.enum(['mock', 'apple', 'google', 'hms', 'wechat', 'alipay']),
  storeProductMapping: storeProductMappingSchema,
});

export const verifyPurchaseSchema = z.object({
  orderId: z.string().min(1).max(80).optional(),
  receipt: z.unknown(),
});

export const restorePurchasesSchema = z.object({
  receipts: z.array(z.unknown()).min(1).max(50),
});
```

在 `runtimeConfigSchema` 的 `.superRefine((config, context) => { ... })` 末尾（`for (const plan of config.plans)` 循环之后）追加：

```ts
  for (const plan of config.plans) {
    if (plan.provider === 'apple' || plan.provider === 'google' || plan.provider === 'hms') {
      const mapped = plan.storeProductMapping?.[plan.provider];
      if (!mapped) {
        context.addIssue({
          code: 'custom',
          path: ['plans'],
          message: `方案 ${plan.id} 的 provider=${plan.provider} 缺少 storeProductMapping.${plan.provider}`,
        });
      }
    }
  }
```

- [ ] **Step 5: 运行确认通过**

Run: `node --import ./tests/register.mjs --test --experimental-transform-types tests/payment.test.ts`
Expected: PASS（3 个用例）。

- [ ] **Step 6: 提交**

```bash
git add server/src/domain/config.ts server/src/server/schemas.ts server/tests/payment.test.ts
git commit -m "feat(payment): storeProductMapping + hms provider + purchase request schemas"
```

---

## Task 2: 数据库 schema —— orders 扩列 + 3 张新表

**Files:**
- Modify: `server/src/server/database-schema-product.ts`
- Modify: `server/src/server/database.ts`
- Test: `server/tests/payment.test.ts`（追加）

- [ ] **Step 1: 写失败测试**（追加到 `payment.test.ts`）

```ts
test('新表与 orders 新列存在', async () => {
  const tables = await database.prepare(`
    SELECT table_name FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name IN ('user_entitlements', 'subscriptions', 'webhook_events')
  `).all() as { table_name: string }[];
  const names = tables.map((t) => t.table_name).sort();
  assert.deepEqual(names, ['subscriptions', 'user_entitlements', 'webhook_events']);

  const cols = await database.prepare(`
    SELECT column_name FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name IN
      ('store_transaction_id', 'receipt_hash', 'expires_at', 'tier_id')
  `).all() as { column_name: string }[];
  assert.deepEqual(cols.map((c) => c.column_name).sort(),
    ['expires_at', 'receipt_hash', 'store_transaction_id', 'tier_id']);
});
```

- [ ] **Step 2: 运行确认失败**

Run: `$RUN`
Expected: FAIL — 表/列不存在。

- [ ] **Step 3: 实现 —— `database-schema-product.ts`**

把现有 `CREATE TABLE IF NOT EXISTS orders (...)` 替换为含新列的版本，并在同文件 `initializeProductSchema` 的 `database.exec` 内、`orders` 表之后追加 3 张新表：

```sql
CREATE TABLE IF NOT EXISTS orders (
  id TEXT PRIMARY KEY, user_id TEXT NOT NULL, plan_id TEXT NOT NULL,
  tier_id TEXT, idempotency_key TEXT NOT NULL, status TEXT NOT NULL,
  amount_minor INTEGER NOT NULL, currency TEXT NOT NULL, provider TEXT NOT NULL,
  store_transaction_id TEXT, receipt_hash TEXT, expires_at TEXT,
  created_at TEXT NOT NULL, completed_at TEXT, UNIQUE(user_id, idempotency_key),
  FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS user_entitlements (
  id TEXT PRIMARY KEY, user_id TEXT NOT NULL, app_id TEXT NOT NULL,
  entitlement_key TEXT NOT NULL, source_order_id TEXT NOT NULL,
  active INTEGER NOT NULL DEFAULT 1, acquired_at TEXT NOT NULL, expires_at TEXT,
  FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY(source_order_id) REFERENCES orders(id) ON DELETE CASCADE
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_user_entitlement_active
  ON user_entitlements(user_id, entitlement_key) WHERE active = 1;
CREATE TABLE IF NOT EXISTS subscriptions (
  id TEXT PRIMARY KEY, user_id TEXT NOT NULL, app_id TEXT NOT NULL,
  plan_id TEXT NOT NULL, platform TEXT NOT NULL, status TEXT NOT NULL,
  current_order_id TEXT NOT NULL, renew_at TEXT,
  created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
  UNIQUE(user_id, app_id, plan_id),
  FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY(current_order_id) REFERENCES orders(id) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS webhook_events (
  id TEXT PRIMARY KEY, provider TEXT NOT NULL, event_id TEXT NOT NULL,
  payload_hash TEXT NOT NULL, processed INTEGER NOT NULL DEFAULT 0,
  received_at TEXT NOT NULL, UNIQUE(provider, event_id)
);
```

- [ ] **Step 4: 实现 —— `database.ts` 的 `applyIdempotentMigrations`**

在 `applyIdempotentMigrations` 的 `database.exec(`...`)` 模板里追加（给已存在的库补列）：

```sql
    ALTER TABLE orders ADD COLUMN IF NOT EXISTS tier_id TEXT;
    ALTER TABLE orders ADD COLUMN IF NOT EXISTS store_transaction_id TEXT;
    ALTER TABLE orders ADD COLUMN IF NOT EXISTS receipt_hash TEXT;
    ALTER TABLE orders ADD COLUMN IF NOT EXISTS expires_at TEXT;
```

- [ ] **Step 5: 运行确认通过**

Run: `$RUN`
Expected: PASS。

- [ ] **Step 6: 提交**

```bash
git add server/src/server/database-schema-product.ts server/src/server/database.ts server/tests/payment.test.ts
git commit -m "feat(payment): orders columns + user_entitlements/subscriptions/webhook_events tables"
```

---

## Task 3: PaymentAdapter 接口 + mock + unavailable 适配器

**Files:**
- Modify: `server/src/server/payment-providers.ts`（重写）
- Test: `server/tests/payment.test.ts`（追加）

- [ ] **Step 1: 写失败测试**（追加）

```ts
const { paymentProvider, storeKeyForPlatform } = await import('../src/server/payment-providers.ts');

test('mock 适配器 verifyReceipt 成功路径', async () => {
  const r = await paymentProvider('mock', 'development').verifyReceipt({
    appId: 'a', userId: 'u', receipt: { productId: 'p' },
  });
  assert.equal(r.ok, true);
  assert.equal(r.productId, 'p');
  assert.ok(r.storeTransactionId);
});

test('mock 适配器 verifyReceipt 失败路径', async () => {
  const r = await paymentProvider('mock', 'development').verifyReceipt({
    appId: 'a', userId: 'u', receipt: { fail: true },
  });
  assert.equal(r.ok, false);
});

test('未配置渠道 verifyReceipt 抛 503，parseWebhook 抛 401', async () => {
  await assert.rejects(
    () => paymentProvider('apple', 'development').verifyReceipt({ appId: 'a', userId: 'u', receipt: {} }),
    (err: any) => err.status === 503 && err.code === 'PAYMENT_PROVIDER_NOT_CONFIGURED',
  );
  await assert.rejects(
    () => paymentProvider('google', 'development').parseWebhook(Buffer.from('{}'), {}),
    (err: any) => err.status === 401 && err.code === 'WEBHOOK_SIGNATURE_INVALID',
  );
});

test('生产环境禁用 mock', () => {
  assert.throws(
    () => paymentProvider('mock', 'production'),
    (err: any) => err.status === 503 && err.code === 'MOCK_PAYMENT_FORBIDDEN',
  );
});

test('platform → storeKey 解析', () => {
  assert.equal(storeKeyForPlatform('ios'), 'apple');
  assert.equal(storeKeyForPlatform('android'), 'google');
  assert.equal(storeKeyForPlatform('harmonyos'), 'hms');
  assert.equal(storeKeyForPlatform('web'), undefined);
});
```

- [ ] **Step 2: 运行确认失败**

Run: `$RUN`
Expected: FAIL — `verifyReceipt`/`parseWebhook`/`storeKeyForPlatform` 不存在。

- [ ] **Step 3: 实现 —— 重写 `payment-providers.ts`**

```ts
import { randomUUID } from 'node:crypto';
import type { ClientPlatform } from './client-context';
import { ApiError } from './http';

export type StoreKey = 'apple' | 'google' | 'hms';
export type PaymentProviderId = 'mock' | 'apple' | 'google' | 'hms' | 'wechat' | 'alipay';

export function storeKeyForPlatform(platform: ClientPlatform): StoreKey | undefined {
  if (platform === 'ios') return 'apple';
  if (platform === 'android') return 'google';
  if (platform === 'harmonyos') return 'hms';
  return undefined;
}

export type VerifyResult = Readonly<{
  ok: boolean;
  storeTransactionId?: string;
  productId?: string;
  expiresAt?: string;
  refund?: boolean;
}>;

export type WebhookEvent = Readonly<{
  provider: PaymentProviderId;
  eventId: string;
  kind: 'renew' | 'refund';
  orderId: string;
}>;

export interface PaymentAdapter {
  readonly id: PaymentProviderId;
  verifyReceipt(input: Readonly<{
    appId: string; userId: string; orderId?: string; receipt: unknown;
  }>): Promise<VerifyResult>;
  parseWebhook(rawBody: Buffer, headers: Readonly<Record<string, string>>): Promise<WebhookEvent | null>;
}

const mockAdapter: PaymentAdapter = {
  id: 'mock',
  async verifyReceipt({ receipt }) {
    const r = (receipt ?? {}) as { productId?: string; fail?: boolean };
    if (r.fail) return { ok: false };
    return { ok: true, storeTransactionId: `mock-${randomUUID()}`, productId: r.productId };
  },
  async parseWebhook(rawBody) {
    const e = JSON.parse(rawBody.toString()) as Partial<WebhookEvent> & { eventId?: string };
    if (!e.eventId || !e.kind || !e.orderId) return null;
    return { provider: 'mock', eventId: e.eventId, kind: e.kind, orderId: e.orderId };
  },
};

function unavailable(id: PaymentProviderId): PaymentAdapter {
  return {
    id,
    async verifyReceipt() {
      throw new ApiError(503, 'PAYMENT_PROVIDER_NOT_CONFIGURED', `${id} 支付尚未配置`, true);
    },
    async parseWebhook() {
      throw new ApiError(401, 'WEBHOOK_SIGNATURE_INVALID', `${id} webhook 验签失败或未配置`, false);
    },
  };
}

const adapters = new Map<PaymentProviderId, PaymentAdapter>([
  ['mock', mockAdapter],
  ['apple', unavailable('apple')],
  ['google', unavailable('google')],
  ['hms', unavailable('hms')],
  ['wechat', unavailable('wechat')],
  ['alipay', unavailable('alipay')],
]);

export function paymentProvider(id: PaymentProviderId, environment: string): PaymentAdapter {
  if (id === 'mock' && environment === 'production') {
    throw new ApiError(503, 'MOCK_PAYMENT_FORBIDDEN', '生产环境禁止使用模拟支付', true);
  }
  const adapter = adapters.get(id);
  if (!adapter) throw new ApiError(400, 'PAYMENT_PROVIDER_UNSUPPORTED', '不支持的支付渠道');
  return adapter;
}
```

- [ ] **Step 4: 运行确认通过**

Run: `$RUN`
Expected: PASS（追加的 5 个用例）。

- [ ] **Step 5: 提交**

```bash
git add server/src/server/payment-providers.ts server/tests/payment.test.ts
git commit -m "feat(payment): PaymentAdapter interface with mock + unavailable providers"
```

---

## Task 4: Entitlement 服务（与订单同事务发/撤权益）

**Files:**
- Create: `server/src/server/entitlement-service.ts`
- Test: `server/tests/payment.test.ts`（追加）

- [ ] **Step 1: 写失败测试**（追加；先加一个建用户 helper）

```ts
import { createId } from '../src/server/ids.ts';
const { issueEntitlements, revokeEntitlementsForOrder, listActiveEntitlements } =
  await import('../src/server/entitlement-service.ts');
const { defaultConfig: cfg } = await import('../src/domain/config.ts');

async function makeUser(appId: string): Promise<string> {
  const id = `u-${process.pid}-${Math.random().toString(36).slice(2, 8)}`;
  const ts = new Date().toISOString();
  await database.prepare(
    `INSERT INTO users(id, app_id, email, password_hash, username, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
  ).run(id, appId, `t-${id}@test.local`, 'hash', id, ts, ts);
  return id;
}

test('issueEntitlements 按 tier 发放权益且幂等', async () => {
  const userId = await makeUser('app1');
  const tier = cfg.tiers.find((t) => t.id === 'pro')!;
  await issueEntitlements({ userId, appId: 'app1', orderId: 'o1', tier, expiresAt: null });
  await issueEntitlements({ userId, appId: 'app1', orderId: 'o1', tier, expiresAt: null });
  const keys = (await listActiveEntitlements(userId, 'app1')).map((e) => e.entitlement_key).sort();
  assert.deepEqual(keys, ['cloud.100gb', 'export.hd', 'templates.pro']);
});

test('revokeEntitlementsForOrder 撤销该订单权益', async () => {
  const userId = await makeUser('app1');
  const tier = cfg.tiers.find((t) => t.id === 'pro')!;
  await issueEntitlements({ userId, appId: 'app1', orderId: 'o2', tier, expiresAt: null });
  await revokeEntitlementsForOrder('o2');
  const keys = await listActiveEntitlements(userId, 'app1');
  assert.equal(keys.length, 0);
});
```

- [ ] **Step 2: 运行确认失败**

Run: `$RUN`
Expected: FAIL — `entitlement-service` 模块不存在。

- [ ] **Step 3: 实现 —— 新建 `entitlement-service.ts`**

```ts
import { database, nowIso, runTransaction } from './database';
import { createId } from './ids';
import type { MembershipTier } from '@/domain/config';

export type EntitlementRow = Readonly<{
  id: string; user_id: string; app_id: string; entitlement_key: string;
  source_order_id: string; active: number; acquired_at: string; expires_at: string | null;
}>;

export async function issueEntitlements(input: Readonly<{
  userId: string; appId: string; orderId: string; tier: MembershipTier; expiresAt: string | null;
}>) {
  await runTransaction(async () => {
    const ts = nowIso();
    for (const key of input.tier.entitlements) {
      await database.prepare(
        `UPDATE user_entitlements SET active = 0 WHERE user_id = ? AND entitlement_key = ? AND active = 1`,
      ).run(input.userId, key);
      await database.prepare(
        `INSERT INTO user_entitlements(id, user_id, app_id, entitlement_key, source_order_id, active, acquired_at, expires_at)
         VALUES (?, ?, ?, ?, ?, 1, ?, ?)`,
      ).run(createId(), input.userId, input.appId, key, input.orderId, ts, input.expiresAt);
    }
  });
}

export async function revokeEntitlementsForOrder(orderId: string) {
  await database.prepare(
    `UPDATE user_entitlements SET active = 0 WHERE source_order_id = ? AND active = 1`,
  ).run(orderId);
}

export async function listActiveEntitlements(
  userId: string, appId: string,
): Promise<readonly EntitlementRow[]> {
  return await database.prepare(
    `SELECT * FROM user_entitlements WHERE user_id = ? AND app_id = ? AND active = 1`,
  ).all(userId, appId) as readonly EntitlementRow[];
}
```

- [ ] **Step 4: 运行确认通过**

Run: `$RUN`
Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add server/src/server/entitlement-service.ts server/tests/payment.test.ts
git commit -m "feat(payment): entitlement service issuing/revoke within order transaction"
```

---

## Task 5: Order repository 扩展（pending 插入 / 完成 / 反查 / webhook 去重 / subscription）

**Files:**
- Modify: `server/src/server/order-repository.ts`（重写，保留旧 `listOrders` 语义）
- Test: `server/tests/payment.test.ts`（追加）

> 说明：本任务重写 `order-repository.ts`。`order-service.ts`（依赖它）在 Task 6 同步重写，因此本任务结束后 `order-service.ts` 会暂时编译失败；Task 6 修复。两个任务在同一提交节奏内完成，中间状态不要求 typecheck 全绿。

- [ ] **Step 1: 写失败测试**（追加）

```ts
const {
  insertPendingOrder, completeOrder, findOrderById, findOrderByReceiptHash,
  insertWebhookEventIfNew, upsertSubscription, getCurrentSubscription,
} = await import('../src/server/order-repository.ts');

test('insertPendingOrder 创建 pending 订单', async () => {
  const userId = await makeUser('app1');
  const order = await insertPendingOrder({
    userId, appId: 'app1', planId: 'pro-monthly', tierId: 'pro',
    idempotencyKey: 'k1', amountMinor: 1800, currency: 'CNY', provider: 'mock',
  });
  assert.equal(order.status, 'pending');
  assert.equal(order.userId, userId);
});

test('completeOrder 置 success 并写入票据字段', async () => {
  const userId = await makeUser('app1');
  const order = await insertPendingOrder({
    userId, appId: 'app1', planId: 'pro-monthly', tierId: 'pro',
    idempotencyKey: 'k2', amountMinor: 1800, currency: 'CNY', provider: 'mock',
  });
  const done = await completeOrder(order.id, {
    storeTransactionId: 't1', receiptHash: 'h1', expiresAt: null,
  });
  assert.equal(done.status, 'success');
  const found = await findOrderByReceiptHash(userId, 'h1');
  assert.ok(found);
  assert.equal(found.id, order.id);
});

test('insertWebhookEventIfNew 第二次返回 false（去重）', async () => {
  const first = await insertWebhookEventIfNew({ provider: 'mock', eventId: 'e1', payloadHash: 'p' });
  const second = await insertWebhookEventIfNew({ provider: 'mock', eventId: 'e1', payloadHash: 'p' });
  assert.equal(first, true);
  assert.equal(second, false);
});

test('upsertSubscription 同 plan 幂等更新', async () => {
  const userId = await makeUser('app1');
  await upsertSubscription({
    userId, appId: 'app1', planId: 'pro-monthly', platform: 'ios',
    status: 'active', currentOrderId: 'o1', renewAt: null,
  });
  await upsertSubscription({
    userId, appId: 'app1', planId: 'pro-monthly', platform: 'ios',
    status: 'active', currentOrderId: 'o2', renewAt: null,
  });
  const sub = await getCurrentSubscription(userId, 'app1', 'pro-monthly');
  assert.ok(sub);
  assert.equal(sub.current_order_id, 'o2');
});
```

- [ ] **Step 2: 运行确认失败**

Run: `$RUN`
Expected: FAIL — 新函数未导出。

- [ ] **Step 3: 实现 —— 重写 `order-repository.ts`**

```ts
import { database, nowIso, runTransaction } from './database';
import { createId } from './ids';
import type { ClientPlatform } from './client-context';
import type { PaymentProviderId } from './payment-providers';

export type OrderStatus = 'pending' | 'processing' | 'success' | 'failed' | 'refunded';

export type OrderView = Readonly<{
  id: string; userId: string; appId: string; planId: string; tierId: string | null;
  status: OrderStatus; amountMinor: number; currency: string; provider: string;
  storeTransactionId: string | null; receiptHash: string | null; expiresAt: string | null;
  createdAt: string; completedAt: string | null;
}>;

const COLUMNS = `
  id, user_id AS userId, app_id AS appId, plan_id AS planId, tier_id AS tierId,
  status, amount_minor AS amountMinor, currency, provider,
  store_transaction_id AS storeTransactionId, receipt_hash AS receiptHash,
  expires_at AS expiresAt, created_at AS createdAt, completed_at AS completedAt
`;

function mapStatus(s: string): OrderStatus {
  return (['pending', 'processing', 'success', 'failed', 'refunded'].includes(s) ? s : 'pending') as OrderStatus;
}

function toView(row: any): OrderView {
  return { ...row, status: mapStatus(row.status) };
}

export async function listOrders(userId: string): Promise<readonly OrderView[]> {
  const rows = await database.prepare(`SELECT ${COLUMNS} FROM orders WHERE user_id = ? ORDER BY created_at DESC`).all(userId) as any[];
  return rows.map(toView);
}

export async function findOrder(userId: string, idempotencyKey: string): Promise<OrderView | undefined> {
  const row = await database.prepare(
    `SELECT ${COLUMNS} FROM orders WHERE user_id = ? AND idempotency_key = ?`,
  ).get(userId, idempotencyKey) as any | undefined;
  return row ? toView(row) : undefined;
}

export async function findOrderById(orderId: string): Promise<OrderView | undefined> {
  const row = await database.prepare(`SELECT ${COLUMNS} FROM orders WHERE id = ?`).get(orderId) as any | undefined;
  return row ? toView(row) : undefined;
}

export async function findOrderByReceiptHash(userId: string, receiptHash: string): Promise<OrderView | undefined> {
  const row = await database.prepare(
    `SELECT ${COLUMNS} FROM orders WHERE user_id = ? AND receipt_hash = ?`,
  ).get(userId, receiptHash) as any | undefined;
  return row ? toView(row) : undefined;
}

type NewPending = Readonly<{
  userId: string; appId: string; planId: string; tierId: string;
  idempotencyKey: string; amountMinor: number; currency: string; provider: PaymentProviderId;
}>;

export async function insertPendingOrder(input: NewPending): Promise<OrderView> {
  const orderId = createId();
  const ts = nowIso();
  await database.prepare(
    `INSERT INTO orders(id, user_id, app_id, plan_id, tier_id, idempotency_key, status,
       amount_minor, currency, provider, created_at)
     VALUES (?, ?, ?, ?, ?, ?, 'pending', ?, ?, ?, ?)`,
  ).run(orderId, input.userId, input.appId, input.planId, input.tierId, input.idempotencyKey,
    input.amountMinor, input.currency, input.provider, ts);
  const row = await database.prepare(`SELECT ${COLUMNS} FROM orders WHERE id = ?`).get(orderId) as any;
  return toView(row);
}

export async function markProcessing(orderId: string): Promise<void> {
  await database.prepare(`UPDATE orders SET status = 'processing' WHERE id = ?`).run(orderId);
}

export async function completeOrder(orderId: string, input: Readonly<{
  storeTransactionId: string; receiptHash: string; expiresAt: string | null;
}>): Promise<OrderView> {
  const ts = nowIso();
  await database.prepare(
    `UPDATE orders SET status = 'success', store_transaction_id = ?, receipt_hash = ?,
       expires_at = ?, completed_at = ? WHERE id = ?`,
  ).run(input.storeTransactionId, input.receiptHash, input.expiresAt, ts, orderId);
  const row = await database.prepare(`SELECT ${COLUMNS} FROM orders WHERE id = ?`).get(orderId) as any;
  return toView(row);
}

export async function failOrder(orderId: string): Promise<void> {
  await database.prepare(`UPDATE orders SET status = 'failed', completed_at = ? WHERE id = ?`).run(nowIso(), orderId);
}

export async function refundOrder(orderId: string): Promise<void> {
  await database.prepare(`UPDATE orders SET status = 'refunded' WHERE id = ?`).run(orderId);
}

export async function insertWebhookEventIfNew(input: Readonly<{
  provider: string; eventId: string; payloadHash: string;
}>): Promise<boolean> {
  return await runTransaction(async () => {
    const existing = await database.prepare(
      `SELECT id FROM webhook_events WHERE provider = ? AND event_id = ?`,
    ).get(input.provider, input.eventId);
    if (existing) return false;
    await database.prepare(
      `INSERT INTO webhook_events(id, provider, event_id, payload_hash, processed, received_at)
       VALUES (?, ?, ?, ?, 1, ?)`,
    ).run(createId(), input.provider, input.eventId, input.payloadHash, nowIso());
    return true;
  });
}

type SubInput = Readonly<{
  userId: string; appId: string; planId: string; platform: ClientPlatform | string;
  status: string; currentOrderId: string; renewAt: string | null;
}>;

export async function upsertSubscription(input: SubInput): Promise<void> {
  const ts = nowIso();
  await database.prepare(
    `INSERT INTO subscriptions(id, user_id, app_id, plan_id, platform, status, current_order_id, renew_at, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT(user_id, app_id, plan_id) DO UPDATE SET
       status = excluded.status, current_order_id = excluded.current_order_id,
       renew_at = excluded.renew_at, updated_at = excluded.updated_at`,
  ).run(createId(), input.userId, input.appId, input.planId, input.platform,
    input.status, input.currentOrderId, input.renewAt, ts, ts);
}

export async function getCurrentSubscription(
  userId: string, appId: string, planId: string,
): Promise<{ current_order_id: string; status: string; renew_at: string | null } | undefined> {
  return await database.prepare(
    `SELECT current_order_id, status, renew_at FROM subscriptions
     WHERE user_id = ? AND app_id = ? AND plan_id = ?`,
  ).get(userId, appId, planId) as any | undefined;
}
```

> 旧 `insertOrder`（自动完成 + 改 `users.tier_id`）已移除；调用方 `order-service.ts` 在 Task 6 重写。`createId` 已从 `./ids` 导入（与原文件一致）。

- [ ] **Step 4: 运行确认通过**

Run: `$RUN`
Expected: PASS（本任务的用例）。

- [ ] **Step 5: 提交**

```bash
git add server/src/server/order-repository.ts server/tests/payment.test.ts
git commit -m "feat(payment): order repository — pending/complete/refund + webhook dedup + subscriptions"
```

---

## Task 6: Order 服务 —— createOrder(pending) / verifyPurchase(TX) / restorePurchases

**Files:**
- Modify: `server/src/server/order-service.ts`（重写）
- Test: `server/tests/payment.test.ts`（追加）

- [ ] **Step 1: 写失败测试**（追加；加一个测试 config helper）

```ts
import { createHash } from 'node:crypto';
const { createOrder, verifyPurchase, restorePurchases, ordersForUser } =
  await import('../src/server/order-service.ts');

function configWith(mappedPlan = true) {
  return {
    ...cfg,
    plans: [{
      id: 'pro-monthly', tierId: 'pro', name: 'Pro', interval: 'month' as const,
      priceMinor: 1800, currency: 'CNY', provider: 'mock' as const,
      storeProductMapping: mappedPlan
        ? { apple: 'com.x.pro', google: 'pro_g', hms: 'pro_h' }
        : { google: 'pro_g' },
    }],
  };
}

test('createOrder 返回 pending + storeProductId，且幂等', async () => {
  const userId = await makeUser('app1');
  const a = await createOrder({ appId: 'app1', environment: 'development', userId, idempotencyKey: 'i1', planId: 'pro-monthly', platform: 'ios', config: configWith() });
  const b = await createOrder({ appId: 'app1', environment: 'development', userId, idempotencyKey: 'i1', planId: 'pro-monthly', platform: 'ios', config: configWith() });
  assert.equal(a.status, 'pending');
  assert.equal(a.storeProductId, 'com.x.pro');
  assert.equal(a.orderId, b.orderId);
});

test('createOrder 无对应平台映射 → PRODUCT_NOT_MAPPED', async () => {
  const userId = await makeUser('app1');
  await assert.rejects(
    () => createOrder({ appId: 'app1', environment: 'development', userId, idempotencyKey: 'i2', planId: 'pro-monthly', platform: 'ios', config: configWith(false) }),
    (err: any) => err.status === 404 && err.code === 'PRODUCT_NOT_MAPPED',
  );
});

test('verifyPurchase 成功 → order success + 发权益 + 幂等', async () => {
  const userId = await makeUser('app1');
  const { orderId } = await createOrder({ appId: 'app1', environment: 'development', userId, idempotencyKey: 'i3', planId: 'pro-monthly', platform: 'ios', config: configWith() });
  const receipt = { productId: 'com.x.pro' };
  const r1 = await verifyPurchase({ appId: 'app1', environment: 'development', userId, orderId, receipt, platform: 'ios', config: configWith() });
  const r2 = await verifyPurchase({ appId: 'app1', environment: 'development', userId, orderId, receipt, platform: 'ios', config: configWith() });
  assert.equal(r1.status, 'success');
  assert.equal(r2.status, 'success');
  const ents = (await listActiveEntitlements(userId, 'app1')).map((e) => e.entitlement_key).sort();
  assert.deepEqual(ents, ['cloud.100gb', 'export.hd', 'templates.pro']);
});

test('verifyPurchase 失败 → order failed，不发权益', async () => {
  const userId = await makeUser('app1');
  const { orderId } = await createOrder({ appId: 'app1', environment: 'development', userId, idempotencyKey: 'i4', planId: 'pro-monthly', platform: 'ios', config: configWith() });
  const r = await verifyPurchase({ appId: 'app1', environment: 'development', userId, orderId, receipt: { fail: true }, platform: 'ios', config: configWith() });
  assert.equal(r.status, 'failed');
  assert.equal((await listActiveEntitlements(userId, 'app1')).length, 0);
});

test('restorePurchases 按 productId 反查并补发（orderId 缺省）', async () => {
  const userId = await makeUser('app1');
  await restorePurchases({ appId: 'app1', environment: 'development', userId, receipts: [{ productId: 'com.x.pro' }], platform: 'ios', config: configWith() });
  const ents = (await listActiveEntitlements(userId, 'app1')).map((e) => e.entitlement_key).sort();
  assert.deepEqual(ents, ['cloud.100gb', 'export.hd', 'templates.pro']);
});
```

- [ ] **Step 2: 运行确认失败**

Run: `$RUN`
Expected: FAIL — 新签名/函数不存在。

- [ ] **Step 3: 实现 —— 重写 `order-service.ts`**

```ts
import { createHash } from 'node:crypto';
import type { RuntimeConfig } from '@/domain/config';
import type { ClientPlatform } from './client-context';
import { ApiError } from './http';
import { issueEntitlements, listActiveEntitlements } from './entitlement-service';
import { nowIso, runTransaction } from './database';
import {
  completeOrder, failOrder, findOrder, findOrderById, findOrderByReceiptHash,
  insertPendingOrder, markProcessing, ordersForUser, upsertSubscription, type OrderView,
} from './order-repository';
import { paymentProvider, storeKeyForPlatform, type PaymentProviderId } from './payment-providers';

type Plan = RuntimeConfig['plans'][number];

function planExpiry(plan: Plan): string | null {
  if (plan.interval === 'lifetime' || plan.interval === 'one_time') return null;
  const days = plan.interval === 'month' ? 30 : 365;
  return new Date(Date.now() + days * 86400_000).toISOString();
}

function resolvePlan(config: RuntimeConfig, planId: string): Plan {
  const plan = config.plans.find((p) => p.id === planId);
  if (!plan) throw new ApiError(404, 'PLAN_NOT_FOUND', '订阅方案不存在');
  return plan;
}

function findPlanByProductId(config: RuntimeConfig, productId: string): Plan {
  const plan = config.plans.find((p) =>
    p.storeProductMapping && Object.values(p.storeProductMapping).includes(productId));
  if (!plan) throw new ApiError(404, 'PRODUCT_NOT_MAPPED', '找不到商品对应的方案');
  return plan;
}

function providerFromPlan(plan: Plan): PaymentProviderId {
  return plan.provider;
}

export async function ordersForUserExport(userId: string) {
  return await ordersForUser(userId);
}

type CreateOrderInput = Readonly<{
  appId: string; environment: string; userId: string; idempotencyKey: string;
  planId: string; platform: ClientPlatform; config: RuntimeConfig;
}>;

export async function createOrder(input: CreateOrderInput): Promise<{
  orderId: string; storeProductId: string; status: 'pending';
}> {
  const existing = await findOrder(input.userId, input.idempotencyKey);
  if (existing) {
    const plan = resolvePlan(input.config, input.planId);
    const storeKey = storeKeyForPlatform(input.platform);
    const storeProductId = plan.storeProductMapping?.[storeKey ?? 'apple'] ?? '';
    return { orderId: existing.id, storeProductId, status: 'pending' };
  }
  const plan = resolvePlan(input.config, input.planId);
  const storeKey = storeKeyForPlatform(input.platform);
  if (!storeKey) throw new ApiError(404, 'PRODUCT_NOT_MAPPED', '当前平台不支持商店内购');
  const storeProductId = plan.storeProductMapping?.[storeKey];
  if (!storeProductId) throw new ApiError(404, 'PRODUCT_NOT_MAPPED', `方案未配置 ${storeKey} 商品 ID`);
  const order = await insertPendingOrder({
    userId: input.userId, appId: input.appId, planId: plan.id, tierId: plan.tierId,
    idempotencyKey: input.idempotencyKey, amountMinor: plan.priceMinor,
    currency: plan.currency, provider: providerFromPlan(plan),
  });
  return { orderId: order.id, storeProductId, status: 'pending' };
}

type VerifyInput = Readonly<{
  appId: string; environment: string; userId: string; orderId?: string;
  receipt: unknown; platform: ClientPlatform; config: RuntimeConfig;
}>;

export async function verifyPurchase(input: VerifyInput): Promise<OrderView> {
  const receiptHash = createHash('sha256').update(JSON.stringify(input.receipt)).digest('hex');

  let plan: Plan;
  let orderId: string;
  if (input.orderId) {
    const order = await findOrderById(input.orderId);
    if (!order || order.userId !== input.userId) throw new ApiError(404, 'ORDER_NOT_FOUND', '订单不存在');
    const existing = await findOrderByReceiptHash(input.userId, receiptHash);
    if (existing && existing.status === 'success') return existing;
    plan = resolvePlan(input.config, order.planId);
    orderId = order.id;
    await markProcessing(orderId);
  } else {
    const r = (input.receipt ?? {}) as { productId?: string };
    if (!r.productId) throw new ApiError(400, 'PRODUCT_NOT_MAPPED', 'receipt 缺少 productId');
    const existing = await findOrderByReceiptHash(input.userId, receiptHash);
    if (existing && existing.status === 'success') return existing;
    plan = findPlanByProductId(input.config, r.productId);
    const order = await insertPendingOrder({
      userId: input.userId, appId: input.appId, planId: plan.id, tierId: plan.tierId,
      idempotencyKey: `restore-${receiptHash.slice(0, 24)}`, amountMinor: plan.priceMinor,
      currency: plan.currency, provider: providerFromPlan(plan),
    });
    orderId = order.id;
    await markProcessing(orderId);
  }

  const provider = paymentProvider(providerFromPlan(plan), input.environment);
  const result = await provider.verifyReceipt({
    appId: input.appId, userId: input.userId, orderId, receipt: input.receipt,
  });

  return await runTransaction(async () => {
    if (!result.ok) {
      await failOrder(orderId);
      const failed = await findOrderById(orderId);
      return failed!;
    }
    const expiresAt = result.expiresAt ?? planExpiry(plan);
    const done = await completeOrder(orderId, {
      storeTransactionId: result.storeTransactionId ?? '',
      receiptHash, expiresAt,
    });
    const tier = input.config.tiers.find((t) => t.id === plan.tierId)!;
    await issueEntitlements({
      userId: input.userId, appId: input.appId, orderId, tier, expiresAt,
    });
    await upsertSubscription({
      userId: input.userId, appId: input.appId, planId: plan.id, platform: input.platform,
      status: 'active', currentOrderId: orderId,
      renewAt: expiresAt,
    });
    return done;
  });
}

type RestoreInput = Readonly<{
  appId: string; environment: string; userId: string; receipts: readonly unknown[];
  platform: ClientPlatform; config: RuntimeConfig;
}>;

export async function restorePurchases(input: RestoreInput): Promise<readonly OrderView[]> {
  const results: OrderView[] = [];
  for (const receipt of input.receipts) {
    try {
      results.push(await verifyPurchase({
        appId: input.appId, environment: input.environment, userId: input.userId,
        receipt, platform: input.platform, config: input.config,
      }));
    } catch {
      // 单条失败不阻断其余；已记录 failed 订单
    }
  }
  return results;
}

export { ordersForUser };
```

> `createOrder` 不再调用 `provider.start()`、不再自动完成；`ordersForUser` 重新导出以保持 `orders/route.ts` 现有 import 不破。

- [ ] **Step 4: 修复 `orders/route.ts` 对新签名的调用**

`POST` 现在需要传 `platform`，且不再期待自动完成。修改 `server/src/app/api/v1/orders/route.ts` 的 POST：

```ts
    const order = await createOrder({
      appId: user.app_id,
      environment: client.environment,
      userId: user.id,
      idempotencyKey,
      planId: input.planId,
      platform: client.platform,
      config,
    });
    return ok(order, 201);
```

- [ ] **Step 5: 运行确认通过**

Run: `$RUN`
Expected: PASS（追加的 5 个用例）。

- [ ] **Step 6: typecheck 确认无残留旧引用**

Run: `npm run typecheck`
Expected: 通过（无 `PaymentStart`/`PaymentProviderPort`/旧 `insertOrder` 残留）。

- [ ] **Step 7: 提交**

```bash
git add server/src/server/order-service.ts server/src/app/api/v1/orders/route.ts server/tests/payment.test.ts
git commit -m "feat(payment): client-driven verify + restore with idempotent entitlement issuance"
```

---

## Task 7: Webhook 服务 —— 去重 + 续订/退款应用

**Files:**
- Create: `server/src/server/webhook-service.ts`
- Test: `server/tests/payment.test.ts`（追加）

- [ ] **Step 1: 写失败测试**（追加）

```ts
const { applyWebhook } = await import('../src/server/webhook-service.ts');

async function seedSucceededOrder(userId: string): Promise<string> {
  const { orderId } = await createOrder({ appId: 'app1', environment: 'development', userId, idempotencyKey: `w-${Math.random()}`, planId: 'pro-monthly', platform: 'ios', config: configWith() });
  return (await verifyPurchase({ appId: 'app1', environment: 'development', userId, orderId, receipt: { productId: 'com.x.pro' }, platform: 'ios', config: configWith() })).id;
}

test('同一 webhook 投递 10 次只处理 1 次', async () => {
  const userId = await makeUser('app1');
  const orderId = await seedSucceededOrder(userId);
  const body = Buffer.from(JSON.stringify({ eventId: 'e10', kind: 'refund', orderId }));
  for (let i = 0; i < 10; i++) {
    await applyWebhook('mock', body, {});
  }
  const order = await findOrderById(orderId);
  assert.equal(order.status, 'refunded');
  assert.equal((await listActiveEntitlements(userId, 'app1')).length, 0);
});

test('非 mock 渠道 webhook 在 P-1 返回 401（验签骨架）', async () => {
  await assert.rejects(
    () => applyWebhook('apple', Buffer.from('{}'), {}),
    (err: any) => err.status === 401 && err.code === 'WEBHOOK_SIGNATURE_INVALID',
  );
});
```

- [ ] **Step 2: 运行确认失败**

Run: `$RUN`
Expected: FAIL — `applyWebhook` 不存在。

- [ ] **Step 3: 实现 —— 新建 `webhook-service.ts`**

```ts
import { createHash } from 'node:crypto';
import { runTransaction } from './database';
import { revokeEntitlementsForOrder } from './entitlement-service';
import { findOrderById, insertWebhookEventIfNew, refundOrder } from './order-repository';
import { paymentProvider, type PaymentProviderId } from './payment-providers';

export async function applyWebhook(
  provider: PaymentProviderId,
  rawBody: Buffer,
  headers: Readonly<Record<string, string>>,
): Promise<{ applied: boolean; deduplicated?: boolean }> {
  const adapter = paymentProvider(provider, 'development');
  const event = await adapter.parseWebhook(rawBody, headers);
  if (!event) return { applied: false };

  const payloadHash = createHash('sha256').update(rawBody).digest('hex');
  return await runTransaction(async () => {
    const inserted = await insertWebhookEventIfNew({
      provider: event.provider, eventId: event.eventId, payloadHash,
    });
    if (!inserted) return { applied: false, deduplicated: true };

    const order = await findOrderById(event.orderId);
    if (!order) return { applied: false };

    if (event.kind === 'refund') {
      await refundOrder(event.orderId);
      await revokeEntitlementsForOrder(event.orderId);
    }
    // kind === 'renew'：subscription 已由 verifyPurchase 写入 renew_at；P-1 不额外延长，真实续订在 P-2/3/4。
    return { applied: true };
  });
}
```

- [ ] **Step 4: 运行确认通过**

Run: `$RUN`
Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add server/src/server/webhook-service.ts server/tests/payment.test.ts
git commit -m "feat(payment): webhook service with provider+event_id dedup and refund application"
```

---

## Task 8: 路由 —— verify / restore / membership / webhooks

**Files:**
- Create: 7 个 route.ts
- Test: 手动 HTTP（smoke，见 Step 4）

> 这些路由都是薄封装，直接委托给已在 Task 6/7 测试过的服务。验收靠 typecheck + smoke.mjs 扩展。

- [ ] **Step 1: 创建路由文件**

> 各路由 import 沿用 `orders/route.ts` 的确切来源：`requireAuth` from `@/server/auth`、`getClientContext` from `@/server/client-context`、`getRuntimeConfig` from `@/server/database`、`ok`/`handleError`/`ApiError` from `@/server/http`、schema from `@/server/schemas`。

`server/src/app/api/v1/purchases/verify/route.ts`：

```ts
import { NextRequest } from 'next/server';
import { requireAuth } from '@/server/auth';
import { getClientContext } from '@/server/client-context';
import { getRuntimeConfig } from '@/server/database';
import { handleError, ok } from '@/server/http';
import { verifyPurchase } from '@/server/order-service';
import { verifyPurchaseSchema } from '@/server/schemas';

export async function POST(request: NextRequest) {
  try {
    const { user } = await requireAuth(request);
    const client = getClientContext(request);
    const input = verifyPurchaseSchema.parse(await request.json());
    const config = await getRuntimeConfig(user.app_id, client.environment);
    const order = await verifyPurchase({
      appId: user.app_id, environment: client.environment, userId: user.id,
      orderId: input.orderId, receipt: input.receipt, platform: client.platform, config,
    });
    return ok(order);
  } catch (error) {
    return handleError(error);
  }
}
```

`server/src/app/api/v1/purchases/restore/route.ts`：

```ts
import { NextRequest } from 'next/server';
import { requireAuth } from '@/server/auth';
import { getClientContext } from '@/server/client-context';
import { getRuntimeConfig } from '@/server/database';
import { handleError, ok } from '@/server/http';
import { restorePurchases } from '@/server/order-service';
import { listActiveEntitlements } from '@/server/entitlement-service';
import { restorePurchasesSchema } from '@/server/schemas';

export async function POST(request: NextRequest) {
  try {
    const { user } = await requireAuth(request);
    const client = getClientContext(request);
    const input = restorePurchasesSchema.parse(await request.json());
    const config = await getRuntimeConfig(user.app_id, client.environment);
    await restorePurchases({
      appId: user.app_id, environment: client.environment, userId: user.id,
      receipts: input.receipts, platform: client.platform, config,
    });
    const entitlements = await listActiveEntitlements(user.id, user.app_id);
    return ok({ entitlements: entitlements.map((e) => e.entitlement_key) });
  } catch (error) {
    return handleError(error);
  }
}
```

`server/src/app/api/v1/membership/current/route.ts`：

```ts
import { NextRequest } from 'next/server';
import { requireAuth } from '@/server/auth';
import { handleError, ok } from '@/server/http';
import { listActiveEntitlements } from '@/server/entitlement-service';
import { database } from '@/server/database';

export async function GET(request: NextRequest) {
  try {
    const { user } = await requireAuth(request);
    const entitlements = await listActiveEntitlements(user.id, user.app_id);
    const sub = await database.prepare(
      `SELECT plan_id AS planId, status, renew_at AS renewAt FROM subscriptions
       WHERE user_id = ? AND app_id = ? ORDER BY updated_at DESC LIMIT 1`,
    ).get(user.id, user.app_id) as { planId: string; status: string; renewAt: string | null } | undefined;
    return ok({
      tier: user.tier_id,
      entitlements: entitlements.map((e) => ({ key: e.entitlement_key, expiresAt: e.expires_at })),
      subscription: sub ?? null,
    });
  } catch (error) {
    return handleError(error);
  }
}
```

`server/src/app/api/v1/membership/entitlements/route.ts`：

```ts
import { NextRequest } from 'next/server';
import { requireAuth } from '@/server/auth';
import { handleError, ok } from '@/server/http';
import { listActiveEntitlements } from '@/server/entitlement-service';

export async function GET(request: NextRequest) {
  try {
    const { user } = await requireAuth(request);
    const entitlements = await listActiveEntitlements(user.id, user.app_id);
    return ok({ keys: entitlements.map((e) => e.entitlement_key) });
  } catch (error) {
    return handleError(error);
  }
}
```

`server/src/app/api/v1/webhooks/apple/route.ts`、`.../google/route.ts`、`.../hms/route.ts` 三个文件内容同构（仅 provider 不同）：

```ts
import { NextRequest } from 'next/server';
import { handleError, ok } from '@/server/http';
import { applyWebhook } from '@/server/webhook-service';

export async function POST(request: NextRequest) {
  try {
    const rawBody = Buffer.from(await request.text());
    const headers = Object.fromEntries(request.headers.entries());
    const result = await applyWebhook('apple', rawBody, headers); // google/hms 文件分别用 'google'/'hms'
    return ok(result);
  } catch (error) {
    return handleError(error);
  }
}
```

- [ ] **Step 2: typecheck**

Run: `npm run typecheck`
Expected: 通过（确认 `user.tier_id`、`user.app_id` 字段存在；若 `requireAuth` 返回的 user 类型不含 `tier_id`，改为读取实际字段名——查 `src/server/auth.ts` 的 `requireAuth` 返回类型确认）。

- [ ] **Step 3: 若 typecheck 报 `user.tier_id` 不存在**

打开 `src/server/auth.ts`，确认 `requireAuth` 返回的 user 对象的字段名（可能是 `tierId` 而非 `tier_id`）。把 `membership/current/route.ts` 里的 `tier: user.tier_id` 改为实际字段名（如 `user.tierId`）。重新 `npm run typecheck` 至通过。

- [ ] **Step 4: 扩展 `tests/smoke.mjs` 的 HTTP 验收**

在 `smoke.mjs` 末尾追加一节（需先登录拿 token；沿用文件已有 `req`/`check` 与 token 变量模式）：

```js
console.log('P. createOrder 返回 pending + storeProductId');
const orderRes = await fetch(`${BASE}/api/v1/orders`, {
  method: 'POST', headers: { ...H, authorization: `Bearer ${accessToken}`, 'idempotency-key': `smoke-${stamp}`, 'x-platform': 'ios' },
  body: JSON.stringify({ planId: 'pro-monthly' }),
});
const orderJson = await orderRes.json();
check('order pending + storeProductId', orderRes.status === 201 && orderJson?.data?.status === 'pending' && !!orderJson?.data?.storeProductId);

console.log('Q. verifyPurchase 成功 + 发权益');
const verifyRes = await fetch(`${BASE}/api/v1/purchases/verify`, {
  method: 'POST', headers: { ...H, authorization: `Bearer ${accessToken}`, 'x-platform': 'ios' },
  body: JSON.stringify({ orderId: orderJson.data.orderId, receipt: { productId: orderJson.data.storeProductId } }),
});
const verifyJson = await verifyRes.json();
check('verify success', verifyRes.status === 200 && verifyJson?.data?.status === 'success');

console.log('R. membership/current 有权益');
const curRes = await fetch(`${BASE}/api/v1/membership/current`, { headers: { ...H, authorization: `Bearer ${accessToken}` } });
const curJson = await curRes.json();
check('current entitlements non-empty', Array.isArray(curJson?.data?.entitlements) && curJson.data.entitlements.length > 0);

console.log('S. webhook 去重（refund ×2 只生效一次）');
for (let i = 0; i < 2; i++) {
  await fetch(`${BASE}/api/v1/webhooks/apple`, {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ eventId: `smoke-refund-${stamp}`, kind: 'refund', orderId: orderJson.data.orderId }),
  });
}
```

> smoke.mjs 命中 mock webhook 路径需要 `applyWebhook('mock', ...)`；apple 路由在 P-1 会抛 401。因此 smoke 的 webhook 段在 P-1 应改打一个 dev-only mock webhook 入口，或把去重断言留给 `payment.test.ts`（Task 7 已覆盖 ×10）。**实际做法**：smoke 只断言 P/Q/R（HTTP 主链路），webhook 去重以 `payment.test.ts` 为准。删除上面 S 段，保留 P/Q/R。

- [ ] **Step 5: 提交**

```bash
git add server/src/app/api/v1/purchases server/src/app/api/v1/membership/current server/src/app/api/v1/membership/entitlements server/src/app/api/v1/webhooks tests/smoke.mjs
git commit -m "feat(payment): verify/restore/membership/webhook routes + smoke coverage"
```

---

## Task 9: 契约快照（z.toJSONSchema）+ 快照测试

**Files:**
- Create: `server/src/server/contract-snapshot.ts`
- Test: `server/tests/payment.test.ts`（追加）

- [ ] **Step 1: 写失败测试**（追加）

```ts
const { paymentContractSnapshot } = await import('../src/server/contract-snapshot.ts');

test('契约快照导出 order/verify/restore/membership 的 JSON Schema', () => {
  const snap = paymentContractSnapshot as Record<string, unknown>;
  assert.equal(snap.type, 'object');
  const props = snap.properties as Record<string, unknown>;
  for (const key of ['orderRequest', 'verifyRequest', 'restoreRequest']) {
    assert.ok(props[key], `missing ${key}`);
  }
});
```

- [ ] **Step 2: 运行确认失败**

Run: `$RUN`
Expected: FAIL — 模块不存在。

- [ ] **Step 3: 实现 —— 新建 `contract-snapshot.ts`**

```ts
import { z } from 'zod';
import { orderSchema, verifyPurchaseSchema, restorePurchasesSchema } from './schemas';

const membershipEntitlementsSchema = z.object({
  keys: z.array(z.string()),
});

export const paymentContractSnapshot = z.toJSONSchema(z.object({
  orderRequest: orderSchema,
  verifyRequest: verifyPurchaseSchema,
  restoreRequest: restorePurchasesSchema,
  membershipEntitlementsResponse: membershipEntitlementsSchema,
}));
```

> Zod 4 提供 `z.toJSONSchema(rootSchema)`，返回标准 JSON Schema 对象。P-1.2 的三端按此快照校验各自模型。

- [ ] **Step 4: 运行确认通过**

Run: `$RUN`
Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add server/src/server/contract-snapshot.ts server/tests/payment.test.ts
git commit -m "feat(payment): zod-based contract snapshot for cross-stack model validation"
```

---

## Task 10: 接入 npm test + 全量验收

**Files:**
- Modify: `server/package.json`

- [ ] **Step 1: 把 payment.test.ts 加入 test 脚本**

修改 `server/package.json` 的 `test`：

```json
    "test": "node --import ./tests/register.mjs --test --experimental-transform-types tests/core.test.ts tests/auth.test.ts tests/payment.test.ts"
```

- [ ] **Step 2: 全量测试**

Run: `npm test`
Expected: 全绿（core + auth + payment，payment 用例数 ≈ 本计划累计的 ~18 个）。

- [ ] **Step 3: typecheck + lint**

Run: `npm run typecheck && npm run lint`
Expected: 通过。

- [ ] **Step 4: 手动 smoke（可选但推荐）**

启动服务 `npm run dev`（或 `next start --port 3310`），跑 `node tests/smoke.mjs`（设好 `SMOKE_BASE` 与 token）。Expected: P/Q/R 段全 ✔。

- [ ] **Step 5: 提交**

```bash
git add server/package.json
git commit -m "test(payment): wire payment.test.ts into npm test; full suite green"
```

---

## Self-Review（计划作者自查记录）

- **Spec 覆盖**：spec 第 3 节（数据模型）→ Task 2；第 4.1（PaymentAdapter）→ Task 3；第 4.2（状态机/verify/restore）→ Task 5+6；第 4.3（路由）→ Task 8；第 5 节客户端 → 属 P-1.2（本计划不含，已声明）；第 6 节 Mock → Task 3+6+7；第 7 节错误码 → 散落各 Task（PRODUCT_NOT_MAPPED/ORDER_NOT_FOUND/WEBHOOK_SIGNATURE_INVALID/PAYMENT_PROVIDER_NOT_CONFIGURED/MOCK_PAYMENT_FORBIDDEN 均有 Task 落点）；第 8 节验收 PAY-01/02/03/04/06/12/14、MEM-14/16 → Task 6/7/8 覆盖。PAY-05（中断恢复）由 `findOrderByReceiptHash` 幂等覆盖（Task 5+6），PARTIAL。PAY-07 骨架 → Task 3+7。契约测试 → Task 9。
- **占位符**：无 TBD/TODO；Task 8 Step 2/3 对 `user.tier_id` 字段名的不确定性给了"查证后改"的明确指令（非占位，是真实未知）。Task 8 Step 4 的 smoke webhook 段已明确删除（以 payment.test.ts 为准），不留半截。
- **类型一致性**：`OrderView`、`PaymentProviderId`、`VerifyResult`、`WebhookEvent`、`storeKeyForPlatform` 在各 Task 间签名一致；`createOrder` 返回 `{orderId, storeProductId, status}`，路由与测试用法一致。
- **已知偏离 spec**：Order 终态 `success`（非 `succeeded`）、不引入 `closed`——已在 spec commit `0079448` 同步对齐。

---

## 执行交接

计划已保存到 `docs/superpowers/plans/2026-08-10-payment-server-abstraction.md`。两种执行方式：

1. **子代理驱动（推荐）** —— 每个 Task 派一个全新子代理执行，两阶段评审，迭代快。
2. **会话内执行** —— 用 superpowers:executing-plans 在本会话批量执行，带检查点。

选哪种？
