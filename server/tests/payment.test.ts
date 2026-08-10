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
