import assert from 'node:assert/strict';
import test, { after } from 'node:test';
type ApiError = { status: number; code: string };

// Google RTDN 全链路：Pub/Sub OIDC 传输鉴权 → 事件映射矩阵 → DB 级退款/
// 到期/取消语义 → tier 读时推导。真 Postgres，固定随机 id、用前清理。

const { database } = await import('../src/server/database.ts');
const { defaultConfig } = await import('../src/domain/config.ts');
const { googleAdapter } = await import('../src/server/google-adapter.ts');
const { verifyPubSubPush, pubsubAuthConfigured } = await import('../src/server/pubsub-auth.ts');
const {
  issueEntitlements, listActiveEntitlements, resolveTierIdFromEntitlementKeys,
} = await import('../src/server/entitlement-service.ts');
const {
  insertPendingOrder, completeOrder, upsertSubscription, findOrderById,
} = await import('../src/server/order-repository.ts');
const { applyWebhook } = await import('../src/server/webhook-service.ts');
const REG = await import('../src/server/payment-apps.ts');
const { generateKeyPair, exportJWK, createLocalJWKSet, SignJWT } = await import('jose');

after(async () => database.close());

// ── 夹具 ────────────────────────────────────────────────────────────────────

const PKG = 'tech.gtest.prod';
const APP = 'lofi-gtest';
// purchaseToken 是订单行的 store_transaction_id：每个 DB 用例独立 token，
// 否则 findOrderByStoreTransactionId 会命中前序用例的订单。
const makeToken = () => `tok-${process.pid}-${Math.random().toString(36).slice(2, 8)}`;

function withEnv(name: string, value: string | undefined, fn: () => void | Promise<void>) {
  const old = process.env[name];
  if (value === undefined) delete process.env[name];
  else process.env[name] = value;
  return Promise.resolve(fn()).finally(() => {
    if (old === undefined) delete process.env[name];
    else process.env[name] = old;
  });
}

/** 注册 packageName→app 路由（临时凭证文件；serviceAccountFile 不存在——
 *  映射/DB 用例不触发 Play API 拉取，路径只需存在于注册表）。 */
async function withRegisteredPackage(fn: () => Promise<void>) {
  const { writeFileSync, mkdtempSync, rmSync } = await import('node:fs');
  const { tmpdir } = await import('node:os');
  const { join } = await import('node:path');
  const dir = mkdtempSync(join(tmpdir(), 'greg-'));
  const file = join(dir, 'payments.json');
  writeFileSync(file, JSON.stringify({
    apps: { [APP]: { google: { packageName: PKG, serviceAccountFile: 'certs/gtest-no-such.json' } } },
  }));
  await withEnv('PAYMENTS_CONFIG_FILE', file, async () => {
    await withEnv('GOOGLE_PUBSUB_AUDIENCE', undefined, async () => {
      await withEnv('GOOGLE_PUBSUB_SERVICE_ACCOUNT', undefined, async () => {
        REG.__resetForTest();
        try { await fn(); } finally { REG.__resetForTest(); }
      });
    });
  });
  rmSync(dir, { recursive: true, force: true });
}

/** Pub/Sub push envelope：{ message: { data: base64(DeveloperNotification), messageId } } */
function envelope(notification: Record<string, unknown>, messageId: string): Buffer {
  return Buffer.from(JSON.stringify({
    message: {
      data: Buffer.from(JSON.stringify({ packageName: PKG, ...notification })).toString('base64'),
      messageId,
    },
  }));
}

function subNotif(nt: number, messageId: string, token: string): Buffer {
  return envelope({
    subscriptionNotification: { notificationType: nt, purchaseToken: token, subscriptionId: 'pro_monthly_001' },
  }, messageId);
}

async function makeUser(appId: string): Promise<string> {
  const id = `u-g-${process.pid}-${Math.random().toString(36).slice(2, 8)}`;
  const ts = new Date().toISOString();
  await database.prepare(
    `INSERT INTO users(id, app_id, email, password_hash, username, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
  ).run(id, appId, `t-${id}@test.local`, 'hash', id, ts, ts);
  return id;
}

/** 成功订单（store_transaction_id = purchaseToken）+ pro 权益 + active 订阅行。 */
async function seedProOrder(userId: string, token: string): Promise<string> {
  const orderId = `o-g-${process.pid}-${Math.random().toString(36).slice(2, 8)}`;
  const order = await insertPendingOrder({
    userId, planId: 'pro-monthly', tierId: 'pro', idempotencyKey: `k-${orderId}`,
    amountMinor: 1800, currency: 'CNY', provider: 'google',
  });
  const proTier = defaultConfig.tiers.find((t) => t.id === 'pro')!;
  await completeOrder(order.id, {
    storeTransactionId: token, receiptHash: `h-${orderId}`, expiresAt: new Date(Date.now() + 30 * 86400_000).toISOString(),
  });
  await issueEntitlements({ userId, appId: 'app1', orderId: order.id, tier: proTier, expiresAt: null });
  await upsertSubscription({
    userId, appId: 'app1', planId: 'pro-monthly', platform: 'android',
    status: 'active', currentOrderId: order.id, renewAt: null,
  });
  return order.id;
}

async function subscriptionStatus(orderId: string): Promise<string | undefined> {
  const row = await database.prepare(
    `SELECT status FROM subscriptions WHERE current_order_id = ?`,
  ).get(orderId) as { status: string } | undefined;
  return row?.status;
}

// ── OIDC 传输鉴权（注入本地 JWKS）────────────────────────────────────────────

const { publicKey, privateKey } = await generateKeyPair('RS256');
const jwk = { ...(await exportJWK(publicKey)), kid: 'gtest-key', alg: 'RS256' };
const localJwks = createLocalJWKSet({ keys: [jwk] });

function signToken(opts: Readonly<{
  iss?: string; aud?: string; expSeconds?: number; email?: string;
}> = {}): Promise<string> {
  const claims: Record<string, unknown> = {
    email: opts.email ?? 'push@gtest.iam.gserviceaccount.com',
  };
  let builder = new SignJWT(claims)
    .setProtectedHeader({ alg: 'RS256', kid: 'gtest-key' })
    .setIssuer(opts.iss ?? 'https://accounts.google.com');
  if (opts.aud) builder = builder.setAudience(opts.aud);
  if (opts.expSeconds !== undefined) builder = builder.setExpirationTime(opts.expSeconds);
  else builder = builder.setExpirationTime('2h');
  return builder.sign(privateKey);
}

test('OIDC：合法 Google 签名 token 通过', async () => {
  const token = await signToken();
  await verifyPubSubPush({ authorization: `Bearer ${token}` }, { jwks: localJwks });
});

test('OIDC：缺少 Authorization 头 401', async () => {
  await assert.rejects(
    () => verifyPubSubPush({}, { jwks: localJwks }),
    (e: ApiError) => e.status === 401 && e.code === 'WEBHOOK_SIGNATURE_INVALID',
  );
});

test('OIDC：篡改签名 401', async () => {
  const token = await signToken();
  const tampered = token.slice(0, -4) + 'AAAA';
  await assert.rejects(
    () => verifyPubSubPush({ authorization: `Bearer ${tampered}` }, { jwks: localJwks }),
    (e: ApiError) => e.status === 401,
  );
});

test('OIDC：错误签发者 401', async () => {
  const token = await signToken({ iss: 'https://evil.example.com' });
  await assert.rejects(
    () => verifyPubSubPush({ authorization: `Bearer ${token}` }, { jwks: localJwks }),
    (e: ApiError) => e.status === 401,
  );
});

test('OIDC：过期 token 401', async () => {
  const token = await signToken({ expSeconds: Math.floor(Date.now() / 1000) - 600 });
  await assert.rejects(
    () => verifyPubSubPush({ authorization: `Bearer ${token}` }, { jwks: localJwks }),
    (e: ApiError) => e.status === 401,
  );
});

test('OIDC：audience 绑定——不匹配 401、匹配通过', async () => {
  const aud = 'https://auth.example.com/webhooks/google';
  const token = await signToken({ aud });
  await assert.rejects(
    () => verifyPubSubPush({ authorization: `Bearer ${token}` }, { jwks: localJwks, audience: 'https://other.example.com/x' }),
    (e: ApiError) => e.status === 401,
  );
  await verifyPubSubPush({ authorization: `Bearer ${token}` }, { jwks: localJwks, audience: aud });
});

test('OIDC：service account 绑定——email 不匹配 401、匹配通过', async () => {
  const token = await signToken({ email: 'push@gtest.iam.gserviceaccount.com' });
  await assert.rejects(
    () => verifyPubSubPush({ authorization: `Bearer ${token}` },
      { jwks: localJwks, serviceAccount: 'other@gtest.iam.gserviceaccount.com' }),
    (e: ApiError) => e.status === 401,
  );
  await verifyPubSubPush({ authorization: `Bearer ${token}` },
    { jwks: localJwks, serviceAccount: 'push@gtest.iam.gserviceaccount.com' });
});

test('env 未配置时 pubsubAuthConfigured 为 false（灰度放行开关）', () => {
  // 本文件所有用例都在 withRegisteredPackage（显式清空两个 env）内运行
  assert.equal(pubsubAuthConfigured(), false);
});

// ── 事件映射矩阵（无默认 renew；未识别一律忽略）──────────────────────────────

const MAPPING: readonly { nt: number | 'voided' | 'oneTime'; kind: string | null }[] = [
  { nt: 'voided', kind: 'refund' },
  { nt: 1, kind: 'renew' },   // RECOVERED
  { nt: 2, kind: 'renew' },   // RENEWED
  { nt: 3, kind: null },      // CANCELED：保留权益至到期
  { nt: 4, kind: 'renew' },   // PURCHASED（自愈）
  { nt: 5, kind: 'expire' },  // ON_HOLD：冻结挂起
  { nt: 6, kind: null },      // IN_GRACE：保持现状
  { nt: 7, kind: 'renew' },   // RESTARTED：恢复
  { nt: 8, kind: 'refund' },  // REVOKED
  { nt: 12, kind: 'expire' }, // EXPIRED
  { nt: 13, kind: null },     // PRICE_CHANGE_CONFIRMED
  { nt: 20, kind: null },     // 未识别类型
];

for (const { nt, kind } of MAPPING) {
  test(`映射：nt=${nt} → ${kind ?? 'null'}`, async () => {
    await withRegisteredPackage(async () => {
      const token = makeToken();
      const body = nt === 'voided'
        ? envelope({ voidedPurchaseNotification: { purchaseToken: token } }, `mid-voided-${nt}`)
        : nt === 'oneTime'
          ? envelope({ oneTimeProductNotification: { notificationType: 1, purchaseToken: token } }, `mid-ot-${nt}`)
          : subNotif(nt as number, `mid-${nt}`, token);
      const event = await googleAdapter.parseWebhook(body, {});
      if (kind === null) assert.equal(event, null);
      else {
        assert.equal(event?.kind, kind);
        assert.equal(event?.provider, 'google');
      }
    });
  });
}

test('映射：oneTimeProductNotification 忽略', async () => {
  await withRegisteredPackage(async () => {
    const body = envelope({ oneTimeProductNotification: { notificationType: 1, purchaseToken: makeToken() } }, 'mid-ot');
    assert.equal(await googleAdapter.parseWebhook(body, {}), null);
  });
});

test('映射：坏 JSON / 缺 data / 未知 packageName 一律 401', async () => {
  await withRegisteredPackage(async () => {
    await assert.rejects(
      () => googleAdapter.parseWebhook(Buffer.from('{ not json'), {}),
      (e: ApiError) => e.status === 401,
    );
    await assert.rejects(
      () => googleAdapter.parseWebhook(Buffer.from(JSON.stringify({ message: {} })), {}),
      (e: ApiError) => e.status === 401,
    );
    const unknown = Buffer.from(JSON.stringify({
      message: { data: Buffer.from(JSON.stringify({ packageName: 'tech.unknown.app' })).toString('base64'), messageId: 'm' },
    }));
    await assert.rejects(
      () => googleAdapter.parseWebhook(unknown, {}),
      (e: ApiError) => e.status === 401,
    );
  });
});

test('env 配置后 parseWebhook 强制 OIDC（无 Bearer 401）；未配置放行', async () => {
  const { writeFileSync, mkdtempSync, rmSync } = await import('node:fs');
  const { tmpdir } = await import('node:os');
  const { join } = await import('node:path');
  const dir = mkdtempSync(join(tmpdir(), 'greg-'));
  const file = join(dir, 'payments.json');
  writeFileSync(file, JSON.stringify({
    apps: { [APP]: { google: { packageName: PKG, serviceAccountFile: 'certs/gtest-no-such.json' } } },
  }));
  const body = subNotif(3, 'mid-gated', makeToken());
  await withEnv('PAYMENTS_CONFIG_FILE', file, async () => {
    REG.__resetForTest();
    // 配置 audience → 强制：无 token 401
    await withEnv('GOOGLE_PUBSUB_AUDIENCE', 'https://auth.example.com/webhooks/google', async () => {
      assert.equal(pubsubAuthConfigured(), true);
      await assert.rejects(
        () => googleAdapter.parseWebhook(body, {}),
        (e: ApiError) => e.status === 401 && e.code === 'WEBHOOK_SIGNATURE_INVALID',
      );
    });
    // 未配置 → 灰度放行（映射本身：nt3 → null 忽略）
    await withEnv('GOOGLE_PUBSUB_AUDIENCE', undefined, async () => {
      assert.equal(pubsubAuthConfigured(), false);
      assert.equal(await googleAdapter.parseWebhook(body, {}), null);
    });
    REG.__resetForTest();
  });
  rmSync(dir, { recursive: true, force: true });
});

// ── DB 级：退款 / 到期 / 取消 / 去重 ─────────────────────────────────────────

test('voided webhook：订单 refunded + 权益撤销 + tier 推导为 null', async () => {
  await withRegisteredPackage(async () => {
    const userId = await makeUser('app1');
    const token = makeToken();
    const orderId = await seedProOrder(userId, token);
    assert.equal((await findOrderById(orderId))?.status, 'success');

    const result = await applyWebhook('google',
      envelope({ voidedPurchaseNotification: { purchaseToken: token } }, `mid-refund-${orderId}`), {});
    assert.equal(result.applied, true);
    assert.equal((await findOrderById(orderId))?.status, 'refunded');
    const active = await listActiveEntitlements(userId, 'app1');
    assert.equal(active.length, 0);
    // 读时推导：退款用户立即拿不到 tier（无需任何 tier_id 清理）
    assert.equal(resolveTierIdFromEntitlementKeys(
      defaultConfig, active.map((e) => e.entitlement_key),
    ), null);
  });
});

test('EXPIRED(12)：订阅行翻 expired + 权益撤销', async () => {
  await withRegisteredPackage(async () => {
    const userId = await makeUser('app1');
    const token = makeToken();
    const orderId = await seedProOrder(userId, token);

    const result = await applyWebhook('google', subNotif(12, `mid-exp-${orderId}`, token), {});
    assert.equal(result.applied, true);
    assert.equal(await subscriptionStatus(orderId), 'expired');
    assert.equal((await listActiveEntitlements(userId, 'app1')).length, 0);
  });
});

test('CANCELED(3)：applied:false，权益与订阅完全不动', async () => {
  await withRegisteredPackage(async () => {
    const userId = await makeUser('app1');
    const token = makeToken();
    const orderId = await seedProOrder(userId, token);

    const result = await applyWebhook('google', subNotif(3, `mid-cancel-${orderId}`, token), {});
    assert.equal(result.applied, false);
    assert.equal((await findOrderById(orderId))?.status, 'success');
    assert.equal(await subscriptionStatus(orderId), 'active');
    assert.equal((await listActiveEntitlements(userId, 'app1')).length, 3);
  });
});

test('同 messageId 重放去重', async () => {
  await withRegisteredPackage(async () => {
    const userId = await makeUser('app1');
    const token = makeToken();
    await seedProOrder(userId, token);
    const body = subNotif(12, `mid-dedupe-${userId}`, token);
    const first = await applyWebhook('google', body, {});
    assert.equal(first.deduplicated, undefined);
    const replay = await applyWebhook('google', body, {});
    assert.equal(replay.deduplicated, true);
  });
});

// ── tier 读时推导（纯函数）────────────────────────────────────────────────────

test('resolveTierIdFromEntitlementKeys：全档位矩阵', () => {
  const proKeys = ['export.hd', 'templates.pro', 'cloud.100gb'];
  const teamKeys = [...proKeys, 'team.workspace'];
  // pro 权益 → pro
  assert.equal(resolveTierIdFromEntitlementKeys(defaultConfig, proKeys), 'pro');
  // team 权益 → team（pro 是 team 的子集）
  assert.equal(resolveTierIdFromEntitlementKeys(defaultConfig, teamKeys), 'team');
  // 双双满足 → 取 entitlements 数最多者（team）
  assert.equal(resolveTierIdFromEntitlementKeys(defaultConfig, [...proKeys, ...teamKeys]), 'team');
  // 部分满足不入选
  assert.equal(resolveTierIdFromEntitlementKeys(defaultConfig, ['export.hd']), null);
  // 空权益（含 free 的空 entitlements 档）永不由推导产生
  assert.equal(resolveTierIdFromEntitlementKeys(defaultConfig, []), null);
  // 退款（权益清空）后即时降级——无需 tier_id 写侧清理
  assert.equal(resolveTierIdFromEntitlementKeys(defaultConfig, ['unknown.key']), null);
});
