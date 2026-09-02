import assert from 'node:assert/strict';
import test, { after } from 'node:test';
const { database, getRuntimeConfig, saveRuntimeConfig } = await import('../src/server/database.ts');
const { defaultConfig } = await import('../src/domain/config.ts');
const { runtimeConfigSchema } = await import('../src/server/schemas.ts');
const { resolvePublicLocale } = await import('../src/server/public-locale.ts');
after(async () => database.close());

const APP = 'zhongbei';

test('defaultConfig 满足 runtimeConfigSchema（webPresence 默认值与 schema 保持同步）', () => {
  const parsed = runtimeConfigSchema.parse(defaultConfig);
  assert.equal(parsed.webPresence.contactEmail, defaultConfig.webPresence.contactEmail);
  assert.equal(parsed.webPresence.appStoreUrl, null);
  assert.equal(parsed.webPresence.googlePlayUrl, null);
});

test('存量配置（无 webPresence 段）读取时自动补齐默认值', async () => {
  const legacy = { ...defaultConfig } as Record<string, unknown>;
  delete legacy.webPresence;
  await saveRuntimeConfig(legacy as typeof defaultConfig, APP);
  const upgraded = await getRuntimeConfig(APP);
  assert.deepEqual(upgraded.webPresence, defaultConfig.webPresence);
  await saveRuntimeConfig(defaultConfig, APP);
});

test('resolvePublicLocale：显式 ?locale= 优先，未知显式值回落 Accept-Language', () => {
  assert.equal(resolvePublicLocale('zh-CN', 'en-US,en;q=0.9'), 'zh-CN');
  assert.equal(resolvePublicLocale('en-US', 'zh-CN'), 'en-US');
  assert.equal(resolvePublicLocale('zh', 'en-US'), 'zh-CN');
  assert.equal(resolvePublicLocale('en', null), 'en-US');
  // 显式值不受支持（如 fr）→ 交给 Accept-Language 协商，仍无命中 → 英文兜底
  assert.equal(resolvePublicLocale('fr', 'zh-CN,zh;q=0.9'), 'zh-CN');
  assert.equal(resolvePublicLocale('fr', 'en-GB,en;q=0.9'), 'en-US');
});

test('resolvePublicLocale：Accept-Language 协商 + 英文兜底（美区审核员场景）', () => {
  assert.equal(resolvePublicLocale(undefined, 'zh-CN,zh;q=0.9,en;q=0.8'), 'zh-CN');
  assert.equal(resolvePublicLocale(undefined, 'en-US,en;q=0.9'), 'en-US');
  assert.equal(resolvePublicLocale(undefined, 'ja-JP,ja;q=0.9'), 'en-US');
  assert.equal(resolvePublicLocale(undefined, null), 'en-US');
  // 权重与空格容错
  assert.equal(resolvePublicLocale(undefined, ' zh-TW ; q=0.8 , en ; q=0.9 '), 'zh-CN');
});
