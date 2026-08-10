import assert from 'node:assert/strict';
import test, { after } from 'node:test';
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

const { issueEntitlements, revokeEntitlementsForOrder, listActiveEntitlements } =
  await import('../src/server/entitlement-service.ts');

async function makeUser(appId: string): Promise<string> {
  const id = `u-${process.pid}-${Math.random().toString(36).slice(2, 8)}`;
  const ts = new Date().toISOString();
  await database.prepare(
    `INSERT INTO users(id, app_id, email, password_hash, username, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
  ).run(id, appId, `t-${id}@test.local`, 'hash', id, ts, ts);
  return id;
}

async function makeOrder(orderId: string, userId: string): Promise<string> {
  const ts = new Date().toISOString();
  await database.prepare(
    `INSERT INTO orders(id, user_id, plan_id, tier_id, idempotency_key, status, amount_minor, currency, provider, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
  ).run(orderId, userId, 'pro-monthly', 'pro', `k-${orderId}`, 'success', 1800, 'CNY', 'mock', ts);
  return orderId;
}

test('issueEntitlements 按 tier 发放权益且幂等', async () => {
  const userId = await makeUser('app1');
  await makeOrder('o1', userId);
  const tier = defaultConfig.tiers.find((t) => t.id === 'pro')!;
  await issueEntitlements({ userId, appId: 'app1', orderId: 'o1', tier, expiresAt: null });
  await issueEntitlements({ userId, appId: 'app1', orderId: 'o1', tier, expiresAt: null });
  const keys = (await listActiveEntitlements(userId, 'app1')).map((e) => e.entitlement_key).sort();
  assert.deepEqual(keys, ['cloud.100gb', 'export.hd', 'templates.pro']);
});

test('revokeEntitlementsForOrder 撤销该订单权益', async () => {
  const userId = await makeUser('app1');
  await makeOrder('o2', userId);
  const tier = defaultConfig.tiers.find((t) => t.id === 'pro')!;
  await issueEntitlements({ userId, appId: 'app1', orderId: 'o2', tier, expiresAt: null });
  await revokeEntitlementsForOrder('o2');
  const keys = await listActiveEntitlements(userId, 'app1');
  assert.equal(keys.length, 0);
});
