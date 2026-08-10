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
