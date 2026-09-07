import assert from 'node:assert/strict';
import test, { after } from 'node:test';
import { createSign } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
type ApiError = { status: number; code: string; message: string };

const here = dirname(fileURLToPath(import.meta.url));
const FIXTURES = join(here, 'fixtures', 'hms');

// HMS env 兜底配置（payment-apps 在每次调用时读取 env，测试内设置即可生效）
process.env.HMS_APP_ID = 'hms-app-123';
process.env.HMS_PACKAGE_NAME = 'com.test.hmsapp';
process.env.HMS_CLIENT_ID = 'legacy-client';
process.env.HMS_CLIENT_SECRET = 'legacy-secret';
process.env.HMS_ROOT_CA_FILE = 'tests/fixtures/hms/root.pem';

const { database } = await import('../src/server/database.ts');
const { defaultConfig } = await import('../src/domain/config.ts');
const { verifyHmsJws } = await import('../src/server/hms-adapter.ts');
const { applyWebhook } = await import('../src/server/webhook-service.ts');
const { findOrderById } = await import('../src/server/order-repository.ts');
const { issueEntitlements, listActiveEntitlements } = await import('../src/server/entitlement-service.ts');

const ROOT_PEM = readFileSync(join(FIXTURES, 'root.pem'), 'utf8');
const WRONG_ROOT_PEM = readFileSync(join(FIXTURES, 'intermediate.pem'), 'utf8');
const LEAF_KEY = readFileSync(join(FIXTURES, 'leaf.key'), 'utf8');
const LEAF_DER_B64 = readFileSync(join(FIXTURES, 'leaf.pem'))
  .toString()
  .replace(/-----[^-]+-----/g, '')
  .replace(/\s+/g, '');
const INTERMEDIATE_DER_B64 = readFileSync(join(FIXTURES, 'intermediate.pem'))
  .toString()
  .replace(/-----[^-]+-----/g, '')
  .replace(/\s+/g, '');

function b64url(input: string | Buffer): string {
  return Buffer.from(input).toString('base64url');
}

function buildNotificationJws(
  payload: object,
  opts: Readonly<{ key?: string; leafB64?: string }> = {},
): string {
  const header = b64url(JSON.stringify({
    alg: 'ES256',
    typ: 'JWT',
    x5c: [opts.leafB64 ?? LEAF_DER_B64, INTERMEDIATE_DER_B64],
  }));
  const body = b64url(JSON.stringify(payload));
  const signingInput = `${header}.${body}`;
  const sig = createSign('sha256')
    .update(signingInput)
    .sign({ key: opts.key ?? LEAF_KEY, dsaEncoding: 'ieee-p1363' }, 'base64url');
  return `${signingInput}.${sig}`;
}

function notificationPayload(overrides: object = {}): object {
  return {
    notificationType: 'REVOKE',
    notificationSubtype: 'REFUND_TRANSACTION',
    notificationRequestId: `req-${Math.random().toString(36).slice(2, 10)}`,
    notificationMetaData: {
      environment: 'NORMAL',
      applicationId: 'hms-app-123',
      packageName: 'com.test.hmsapp',
      type: 2,
      purchaseToken: 'token-default',
      purchaseOrderId: 'order-default',
    },
    notificationVersion: 'v3',
    signedTime: 1702607152698,
    ...overrides,
  };
}

async function makeUser(appId: string): Promise<string> {
  const id = `u-hms-${process.pid}-${Math.random().toString(36).slice(2, 8)}`;
  const ts = new Date().toISOString();
  await database.prepare(
    `INSERT INTO users(id, app_id, email, password_hash, username, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
  ).run(id, appId, `t-${id}@test.local`, 'hash', id, ts, ts);
  return id;
}

/** 建 success 订单（store_transaction_id=purchaseToken，模拟 verifyPurchase 完成后的形态）+ 激活权益。 */
async function seedHmsOrder(userId: string, purchaseToken: string): Promise<string> {
  const orderId = `o-hms-${process.pid}-${Math.random().toString(36).slice(2, 8)}`;
  const ts = new Date().toISOString();
  await database.prepare(
    `INSERT INTO orders(id, user_id, plan_id, tier_id, idempotency_key, status, amount_minor, currency, provider, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
  ).run(orderId, userId, 'pro-monthly', 'pro', `k-${orderId}`, 'processing', 1800, 'CNY', 'hms', ts);
  await database.prepare(
    `UPDATE orders SET status = 'success', store_transaction_id = ?, receipt_hash = ?, expires_at = ?, completed_at = ? WHERE id = ?`,
  ).run(purchaseToken, `hash-${purchaseToken}`, new Date(Date.now() + 86400_000).toISOString(), ts, orderId);
  // webhook 的 expire/renew 分支会更新 subscriptions 行——与 verifyPurchase 流程对齐预置
  await database.prepare(
    `INSERT INTO subscriptions(id, user_id, app_id, plan_id, platform, status, current_order_id, renew_at, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT(id) DO NOTHING`,
  ).run(`sub-${orderId}`, userId, 'app1', 'pro-monthly', 'harmonyos', 'active', orderId, new Date(Date.now() + 86400_000).toISOString(), ts, ts);
  const tier = defaultConfig.tiers.find((t) => t.id === 'pro')!;
  await issueEntitlements({ userId, appId: 'app1', orderId, tier, expiresAt: new Date(Date.now() + 86400_000).toISOString() });
  return orderId;
}

after(async () => database.close());

// ── verifyHmsJws ─────────────────────────────────────────────────────────────

test('hms JWS 验签：合法证书链 + ES256 签名通过并返回 payload', () => {
  const payload = verifyHmsJws(buildNotificationJws(notificationPayload()), ROOT_PEM);
  assert.equal(payload.notificationType, 'REVOKE');
  assert.equal(payload.notificationMetaData?.packageName, 'com.test.hmsapp');
});

test('hms JWS 验签：篡改 payload 拒绝', () => {
  const jws = buildNotificationJws(notificationPayload());
  const parts = jws.split('.');
  const forged = `${parts[0]}.${b64url(JSON.stringify(notificationPayload({ notificationType: 'DID_NEW_TRANSACTION' })))}.${parts[2]}`;
  assert.throws(
    () => verifyHmsJws(forged, ROOT_PEM),
    (err: ApiError) => err.status === 401 && err.code === 'WEBHOOK_SIGNATURE_INVALID',
  );
});

test('hms JWS 验签：根 CA 不匹配拒绝', () => {
  assert.throws(
    () => verifyHmsJws(buildNotificationJws(notificationPayload()), WRONG_ROOT_PEM),
    (err: ApiError) => err.status === 401,
  );
});

test('hms JWS 验签：叶子证书缺华为 IAP OID 拒绝（链合法但无扩展）', () => {
  const noOidLeafB64 = readFileSync(join(FIXTURES, 'leaf-nooid.pem'))
    .toString()
    .replace(/-----[^-]+-----/g, '')
    .replace(/\s+/g, '');
  assert.throws(
    () => verifyHmsJws(buildNotificationJws(notificationPayload(), { leafB64: noOidLeafB64 }), ROOT_PEM),
    (err: ApiError) => err.status === 401 && /OID/.test(err.message),
  );
});

test('hms JWS 验签：非 ES256 算法拒绝', () => {
  const header = b64url(JSON.stringify({ alg: 'RS256', x5c: [LEAF_DER_B64, INTERMEDIATE_DER_B64] }));
  const body = b64url(JSON.stringify(notificationPayload()));
  assert.throws(
    () => verifyHmsJws(`${header}.${body}.${b64url(Buffer.alloc(64))}`, ROOT_PEM),
    (err: ApiError) => err.status === 401 && /ES256/.test(err.message),
  );
});

// ── parseWebhook（经 applyWebhook 全链路）────────────────────────────────────

test('hms webhook：REVOKE 退款通知 → 订单翻 refunded + 权益撤销', async () => {
  const userId = await makeUser('app1');
  const token = `tok-refund-${Math.random().toString(36).slice(2, 8)}`;
  const orderId = await seedHmsOrder(userId, token);
  const jws = buildNotificationJws(notificationPayload({
    notificationType: 'REVOKE',
    notificationSubtype: 'REFUND_TRANSACTION',
    notificationMetaData: {
      environment: 'NORMAL', applicationId: 'hms-app-123', packageName: 'com.test.hmsapp',
      type: 2, purchaseToken: token, purchaseOrderId: 'po-1',
    },
  }));
  const result = await applyWebhook('hms', Buffer.from(JSON.stringify({ jwsNotification: jws })), {});
  assert.equal(result.applied, true);
  assert.equal((await findOrderById(orderId))!.status, 'refunded');
  assert.equal((await listActiveEntitlements(userId, 'app1')).length, 0);
});

test('hms webhook：EXPIRE 通知 → 订单翻 expired + 权益撤销', async () => {
  const userId = await makeUser('app1');
  const token = `tok-expire-${Math.random().toString(36).slice(2, 8)}`;
  const orderId = await seedHmsOrder(userId, token);
  const jws = buildNotificationJws(notificationPayload({
    notificationType: 'EXPIRE',
    notificationSubtype: 'BILLING_RETRY',
    notificationMetaData: {
      environment: 'NORMAL', applicationId: 'hms-app-123', packageName: 'com.test.hmsapp',
      type: 2, purchaseToken: token, purchaseOrderId: 'po-2',
    },
  }));
  await applyWebhook('hms', Buffer.from(JSON.stringify({ jwsNotification: jws })), {});
  // expire 语义：撤销权益 + 订阅行翻 expired；订单行保留 success 作历史
  assert.equal((await listActiveEntitlements(userId, 'app1')).length, 0);
  const sub = await database.prepare(
    'SELECT status FROM subscriptions WHERE current_order_id = ?',
  ).get(orderId) as { status: string };
  assert.equal(sub.status, 'expired');
});

test('hms webhook：DID_NEW_TRANSACTION（服务端 API 未配到期查询）→ ack 但不改权益', async () => {
  const userId = await makeUser('app1');
  const token = `tok-renew-${Math.random().toString(36).slice(2, 8)}`;
  const orderId = await seedHmsOrder(userId, token);
  const jws = buildNotificationJws(notificationPayload({
    notificationType: 'DID_NEW_TRANSACTION',
    notificationSubtype: 'DID_RENEW',
    notificationMetaData: {
      environment: 'NORMAL', applicationId: 'hms-app-123', packageName: 'com.test.hmsapp',
      type: 2, purchaseToken: token, purchaseOrderId: 'po-3',
    },
  }));
  const result = await applyWebhook('hms', Buffer.from(JSON.stringify({ jwsNotification: jws })), {});
  assert.equal(result.applied, true, 'renew 无 expiresAt 时 ack 但不延权');
  assert.equal((await findOrderById(orderId))!.status, 'success');
});

test('hms webhook：DID_CHANGE_RENEWAL_STATUS 不改权益（ack）', async () => {
  const userId = await makeUser('app1');
  const token = `tok-status-${Math.random().toString(36).slice(2, 8)}`;
  const orderId = await seedHmsOrder(userId, token);
  const jws = buildNotificationJws(notificationPayload({
    notificationType: 'DID_CHANGE_RENEWAL_STATUS',
    notificationSubtype: 'AUTO_RENEW_DISABLED',
    notificationMetaData: {
      environment: 'NORMAL', applicationId: 'hms-app-123', packageName: 'com.test.hmsapp',
      type: 2, purchaseToken: token, purchaseOrderId: 'po-4',
    },
  }));
  const result = await applyWebhook('hms', Buffer.from(JSON.stringify({ jwsNotification: jws })), {});
  assert.equal(result.applied, false);
  assert.equal((await findOrderById(orderId))!.status, 'success');
});

test('hms webhook：未知 packageName 拒绝（401）', async () => {
  const jws = buildNotificationJws(notificationPayload({
    notificationMetaData: {
      environment: 'NORMAL', applicationId: 'hms-app-123', packageName: 'com.other.app',
      type: 0, purchaseToken: 't', purchaseOrderId: 'o',
    },
  }));
  await assert.rejects(
    () => applyWebhook('hms', Buffer.from(JSON.stringify({ jwsNotification: jws })), {}),
    (err: ApiError) => err.status === 401,
  );
});

test('hms webhook：applicationId 与凭证不符拒绝（401）', async () => {
  const jws = buildNotificationJws(notificationPayload({
    notificationMetaData: {
      environment: 'NORMAL', applicationId: 'hms-app-999', packageName: 'com.test.hmsapp',
      type: 0, purchaseToken: 't', purchaseOrderId: 'o',
    },
  }));
  await assert.rejects(
    () => applyWebhook('hms', Buffer.from(JSON.stringify({ jwsNotification: jws })), {}),
    (err: ApiError) => err.status === 401 && /applicationId/.test(err.message),
  );
});

test('hms webhook：无 jwsNotification / 非 JSON 请求体拒绝（401）', async () => {
  await assert.rejects(
    () => applyWebhook('hms', Buffer.from('{}'), {}),
    (err: ApiError) => err.status === 401,
  );
  await assert.rejects(
    () => applyWebhook('hms', Buffer.from('not-json'), {}),
    (err: ApiError) => err.status === 401,
  );
});

test('hms webhook：未在订单库的 purchaseToken → ack 不处理（applied:false）', async () => {
  const jws = buildNotificationJws(notificationPayload({
    notificationMetaData: {
      environment: 'NORMAL', applicationId: 'hms-app-123', packageName: 'com.test.hmsapp',
      type: 0, purchaseToken: `tok-unknown-${Math.random().toString(36).slice(2, 8)}`, purchaseOrderId: 'po-x',
    },
  }));
  const result = await applyWebhook('hms', Buffer.from(JSON.stringify({ jwsNotification: jws })), {});
  assert.equal(result.applied, false);
});

test('hms webhook：重发同一条通知只处理一次（notificationRequestId 去重）', async () => {
  const userId = await makeUser('app1');
  const token = `tok-dup-${Math.random().toString(36).slice(2, 8)}`;
  await seedHmsOrder(userId, token);
  const jws = buildNotificationJws(notificationPayload({
    // 每次运行唯一（webhook_events 跨运行持久，固定 ID 会让重跑误判为重放）
    notificationRequestId: `fixed-req-${process.pid}-${Math.random().toString(36).slice(2, 8)}`,
    notificationMetaData: {
      environment: 'NORMAL', applicationId: 'hms-app-123', packageName: 'com.test.hmsapp',
      type: 2, purchaseToken: token, purchaseOrderId: 'po-dup',
    },
  }));
  const first = await applyWebhook('hms', Buffer.from(JSON.stringify({ jwsNotification: jws })), {});
  const second = await applyWebhook('hms', Buffer.from(JSON.stringify({ jwsNotification: jws })), {});
  assert.equal(first.applied, true);
  assert.equal(second.applied, false);
  assert.equal(second.deduplicated, true);
});
