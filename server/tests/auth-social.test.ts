// 华为一键登录相关测试——从 auth.test.ts 拆出以服从 CI 350 行硬上限。
// fetch 打桩与 HUAWEI_OAUTH_* 环境变量只影响本文件，独立 worker 运行互不干扰。
import assert from 'node:assert/strict';
import test, { after } from 'node:test';
const { socialSignInSchema, runtimeConfigSchema } = await import('../src/server/schemas.ts');
const { database, nowIso, getRuntimeConfig, saveRuntimeConfig } = await import('../src/server/database.ts');
const { defaultConfig } = await import('../src/domain/config.ts');
after(async () => database.close());

const APP = 'zhongbei';

test('socialSignInSchema accepts provider huawei with authorizationCode', () => {
  const parsed = socialSignInSchema.safeParse({
    provider: 'huawei', authorizationCode: 'abc123', deviceName: 'test',
  });
  assert.equal(parsed.success, true);
});

test('runtime config schema accepts a huawei auth provider', () => {
  // defaultConfig 已含 huawei provider；再叠加 per-app clientIds 验证 schema 接受
  const config = JSON.parse(JSON.stringify(defaultConfig));
  config.auth.providers = config.auth.providers.map((p: { id: string }) => (
    p.id === 'huawei'
      ? { ...p, enabled: true, platforms: ['harmonyos'], clientIds: { harmonyos: 'agc-client-id' } }
      : p
  ));
  const result = runtimeConfigSchema.safeParse(config);
  assert.equal(result.success, true);
});

test('huawei quick login exchanges auth code for phone and merges with phone account', async () => {
  const platform = 'harmonyos';
  const env = `hk-${process.pid}`;
  const cfg = JSON.parse(JSON.stringify(defaultConfig));
  cfg.auth.providers = cfg.auth.providers.map((p: { id: string }) => (
    { ...p, enabled: p.id === 'phone' || p.id === 'huawei' }
  ));
  await saveRuntimeConfig(cfg, APP, env);
  const config = await getRuntimeConfig(APP, env);
  const pid = String(process.pid);
  const phone = `+8613900${pid.padStart(4, '0')}`;
  // 独立的合并测试手机号（避免与上面新建测试的 phone identity 冲突）
  const mergePhone = `+8613800${pid.padStart(4, '0')}`;

  // 测试环境配置 HUAWEI_OAUTH_*（configuredProviders 校验需要）
  const savedClientId = process.env.HUAWEI_OAUTH_CLIENT_ID;
  const savedClientSecret = process.env.HUAWEI_OAUTH_CLIENT_SECRET;
  process.env.HUAWEI_OAUTH_CLIENT_ID = 'agc-test-client-id';
  process.env.HUAWEI_OAUTH_CLIENT_SECRET = 'agc-test-secret';

  // 打桩华为 getPhoneNumber：authCode-3 → mergePhone，其它 → phone
  const originalFetch = globalThis.fetch;
  globalThis.fetch = (async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = String(input);
    if (url.includes('account-api.cloud.huawei.com')) {
      const body = JSON.parse(String(init?.body)) as { code: string };
      const hit = body.code === 'authcode-3' ? mergePhone : phone;
      return new Response(JSON.stringify({
        resultCode: 0,
        phoneNumber: hit,
        purePhoneNumber: hit.replace('+86', ''),
        phoneCountryCode: '86',
      }), { status: 200, headers: { 'Content-Type': 'application/json' } });
    }
    return originalFetch(input, init);
  }) as typeof fetch;

  try {
    const { socialSignIn } = await import('../src/server/social-auth.ts');
    const session = await socialSignIn(
      { appId: APP, provider: 'huawei', authorizationCode: 'authcode-1', deviceName: 'test' },
      config, platform,
    );
    // 华为登录（无真实邮箱）→ email 为 NULL（issue #14：不再伪邮箱）
    assert.equal(session.user.email, null);

    // 再次华为登录 → 同一用户
    const again = await socialSignIn(
      { appId: APP, provider: 'huawei', authorizationCode: 'authcode-2', deviceName: 'test' },
      config, platform,
    );
    assert.equal(again.user.id, session.user.id);

    // 已有 phone identity（mergePhone）→ 华为登录合并到同一账号
    const mergeSubject = `${APP}:${mergePhone}`;
    const { createId } = await import('../src/server/ids.ts');
    const mergeUserEmail = `phone-merge-${process.pid}@phone.invalid`;
    await database.prepare(`
      INSERT INTO users(id, app_id, email, password_hash, username, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `).run(
      createId(), APP, mergeUserEmail, `external$${createId()}`,
      `手机用户 ${mergePhone.slice(-4)}`, nowIso(), nowIso(),
    );
    const mergeUser = await database.prepare(
      'SELECT id FROM users WHERE app_id = ? AND email = ?',
    ).get(APP, mergeUserEmail) as { id: string };
    await database.prepare(`
      INSERT INTO external_identities(id, user_id, provider, provider_subject, created_at)
      VALUES (?, ?, 'phone', ?, ?)
    `).run(createId(), mergeUser.id, mergeSubject, nowIso());

    const merged = await socialSignIn(
      { appId: APP, provider: 'huawei', authorizationCode: 'authcode-3', deviceName: 'test' },
      config, platform,
    );
    assert.equal(merged.user.id, mergeUser.id);
  } finally {
    globalThis.fetch = originalFetch;
    process.env.HUAWEI_OAUTH_CLIENT_ID = savedClientId;
    process.env.HUAWEI_OAUTH_CLIENT_SECRET = savedClientSecret;
  }
});
