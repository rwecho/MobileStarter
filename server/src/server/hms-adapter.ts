import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { createHash, sign as cryptoSign, verify as cryptoVerify, X509Certificate } from 'node:crypto';
import { ApiError } from './http';
import { findOrderByStoreTransactionId } from './order-repository';
import { appIdForHmsPackage, paymentsForApp } from './payment-apps';
import type { HmsPaymentsConfig } from './payment-apps';
import type {
  PaymentAdapter,
  PaymentProviderId,
  VerifyResult,
  WebhookEvent,
} from './payment-providers';

const HMS_TOKEN_URL = 'https://oauth-login.cloud.huawei.com/oauth2/v3/token';

// HarmonyOS NEXT（IAP Kit）订单/订阅服务（REST，JWT ES256 鉴权）
const DEFAULT_SERVER_API = 'https://iap.cloud.huawei.com';
const URL_ORDER_STATUS_QUERY = '/order/harmony/v1/application/order/status/query';
const URL_SUB_STATUS_QUERY = '/subscription/harmony/v1/application/subscription/status/query';
const URL_ORDER_SHIPPED_CONFIRM = '/order/harmony/v1/application/purchase/shipped/confirm';
const URL_SUB_SHIPPED_CONFIRM = '/subscription/harmony/v1/application/purchase/shipped/confirm';

// 通知/查询回包 JWS 的 x5c 证书链锚定华为 CBG Root CA G2，叶子证书必须带
// 华为 IAP 服务专用 OID 扩展 1.3.6.1.4.1.2011.2.415.1.1（DER：06 0C + 12 字节内容编码）。
const LEAF_CERT_OID_HEX = '060c2b060104018f5b02831f0101';

interface CachedToken {
  token: string;
  expiresAt: number;
}

// ── v3 通知 / 查询回包数据模型（ Huawei IAP Kit Server API）──────────────────

export type HmsNotificationPayload = Readonly<{
  notificationType?: string;
  notificationSubtype?: string;
  notificationRequestId?: string;
  notificationVersion?: string;
  notificationMetaData?: Readonly<{
    environment?: string;
    applicationId?: string;
    packageName?: string;
    type?: number;
    purchaseToken?: string;
    purchaseOrderId?: string;
    subscriptionId?: string;
  }>;
  signedTime?: number;
}>;

export type HmsPurchaseOrderPayload = Readonly<{
  environment?: string;
  purchaseOrderId?: string;
  purchaseToken?: string;
  applicationId?: string;
  productId?: string;
  productType?: string;
  purchaseTime?: number;
  revocationTime?: number;
  needFinish?: boolean;
}>;

type SubscriptionStatus = Readonly<{
  purchaseToken?: string;
  status?: string;
  expiresTime?: number;
}>;

type SubGroupStatusPayload = Readonly<{
  lastSubscriptionStatus?: SubscriptionStatus;
  historySubscriptionStatusList?: readonly SubscriptionStatus[];
}>;

function signatureInvalid(reason: string): ApiError {
  return new ApiError(401, 'WEBHOOK_SIGNATURE_INVALID', `hms webhook 验签失败: ${reason}`, false);
}

function b64urlToBuffer(segment: string): Buffer {
  return Buffer.from(segment, 'base64url');
}

// ── JWS 验签（通知 jwsNotification / 查询回包 jwsPurchaseOrder、jwsSubGroupStatus 共用）──
//
// 华为签名方使用华为自有证书链（JWS header.x5c：叶子、中间、根），与开发者 IAP
// 密钥（.p8，仅用于服务端 API 请求 JWT 签名）无关。验证步骤（官方 Node.js 参考）：
//   1. x5c 前两级：叶子 + 中间证书
//   2. 证书链锚定 pinned 的华为 CBG Root CA G2（中间←根、叶子←中间）
//   3. 叶子证书带华为 IAP 服务 OID 扩展
//   4. 叶子公钥 + ES256 验 JWS 签名（JWS 签名为 r||s 裸格式，ieee-p1363）
// CRL 吊销检查省略（官方 Java 示例同样标注 TODO；吊销窗口内短暂信任可接受，
// 权益撤销有 webhook 的 REVOKE 事件兜底）。
export function verifyHmsJws(jws: string, rootCaPem: string): HmsNotificationPayload {
  const parts = jws.split('.');
  if (parts.length !== 3 || !parts[0] || !parts[1] || !parts[2]) {
    throw signatureInvalid('JWS 结构不完整');
  }
  let header: { alg?: string; x5c?: string[] };
  try {
    header = JSON.parse(b64urlToBuffer(parts[0]).toString('utf8')) as { alg?: string; x5c?: string[] };
  } catch {
    throw signatureInvalid('header 解码失败');
  }
  if (header.alg !== 'ES256') throw signatureInvalid('alg 必须为 ES256');
  const x5c = header.x5c;
  if (!Array.isArray(x5c) || x5c.length < 2) throw signatureInvalid('x5c 证书链缺失');

  let leaf: X509Certificate;
  let intermediate: X509Certificate;
  let root: X509Certificate;
  try {
    leaf = new X509Certificate(Buffer.from(x5c[0], 'base64'));
    intermediate = new X509Certificate(Buffer.from(x5c[1], 'base64'));
    root = new X509Certificate(rootCaPem);
  } catch {
    throw signatureInvalid('证书解析失败');
  }
  try {
    if (!intermediate.verify(root.publicKey) || !leaf.verify(intermediate.publicKey)) {
      throw new Error('chain verify false');
    }
  } catch {
    throw signatureInvalid('证书链未锚定华为根 CA');
  }
  if (!leaf.raw.toString('hex').includes(LEAF_CERT_OID_HEX)) {
    throw signatureInvalid('叶子证书缺少华为 IAP 服务 OID');
  }
  const now = Date.now();
  if (now < Date.parse(leaf.validFrom) || now > Date.parse(leaf.validTo)) {
    throw signatureInvalid('叶子证书不在有效期');
  }
  const signed = Buffer.from(`${parts[0]}.${parts[1]}`, 'utf8');
  let sigOk = false;
  try {
    sigOk = cryptoVerify('sha256', signed, { key: leaf.publicKey, dsaEncoding: 'ieee-p1363' }, b64urlToBuffer(parts[2]));
  } catch {
    sigOk = false;
  }
  if (!sigOk) throw signatureInvalid('ES256 签名不匹配');
  try {
    return JSON.parse(b64urlToBuffer(parts[1]).toString('utf8')) as HmsNotificationPayload;
  } catch {
    throw signatureInvalid('payload 解码失败');
  }
}

// ── 服务端 API：JWT（ES256，IAP 密钥）+ 状态查询 / 发货确认 ──────────────────

function b64url(input: Buffer | string): string {
  return Buffer.from(input).toString('base64url');
}

function requireServerApiConfig(cred: HmsPaymentsConfig): void {
  if (!cred.privateKeyFile || !cred.keyId || !cred.issuerId) {
    throw new ApiError(503, 'PAYMENT_PROVIDER_NOT_CONFIGURED', 'HMS 服务端 API 密钥未配置（privateKeyFile/keyId/issuerId）', true);
  }
}

function genServerApiJwt(cred: HmsPaymentsConfig, bodyJson: string): string {
  requireServerApiConfig(cred);
  const keyPath = join(process.cwd(), cred.privateKeyFile!);
  if (!existsSync(keyPath)) {
    throw new ApiError(503, 'PAYMENT_PROVIDER_NOT_CONFIGURED', `HMS 私钥文件不存在: ${cred.privateKeyFile}`, true);
  }
  const keyPem = readFileSync(keyPath, 'utf8');
  const iat = Math.floor(Date.now() / 1000);
  // exp-iat ≤ 1h（华为约束）；取 30min 留时钟漂移余量
  const header = b64url(JSON.stringify({ alg: 'ES256', typ: 'JWT', kid: cred.keyId }));
  const payload = b64url(JSON.stringify({
    iss: cred.issuerId,
    aud: 'iap-v1',
    aid: cred.appId,
    iat,
    exp: iat + 1800,
    // 请求体完整性：SHA-256 hex（华为服务端会校验 digest 与实际 body 一致）
    digest: createHash('sha256').update(bodyJson, 'utf8').digest('hex'),
  }));
  const signingInput = `${header}.${payload}`;
  const signature = cryptoSign('sha256', Buffer.from(signingInput, 'utf8'), { key: keyPem, dsaEncoding: 'ieee-p1363' });
  return `${signingInput}.${b64url(signature)}`;
}

type ServerApiResponse = Readonly<{
  responseCode?: string;
  responseMessage?: string;
  jwsPurchaseOrder?: string;
  jwsSubGroupStatus?: string;
}>;

async function callServerApi(cred: HmsPaymentsConfig, path: string, body: object): Promise<ServerApiResponse | null> {
  const bodyJson = JSON.stringify(body);
  try {
    const response = await fetch(`${cred.serverApiUrl ?? DEFAULT_SERVER_API}${path}`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${genServerApiJwt(cred, bodyJson)}`,
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: bodyJson,
      signal: AbortSignal.timeout(10_000),
    });
    if (!response.ok) return null;
    return await response.json() as ServerApiResponse;
  } catch {
    return null;
  }
}

function rootCaFor(cred: HmsPaymentsConfig): string {
  const file = cred.rootCaFile ?? 'certs/huawei-root-ca-g2.pem';
  const path = join(process.cwd(), file);
  if (!existsSync(path)) {
    throw new ApiError(503, 'PAYMENT_PROVIDER_NOT_CONFIGURED', `华为根 CA 证书不存在: ${file}`, true);
  }
  return readFileSync(path, 'utf8');
}

/** 订单状态查询（消耗型/非消耗型/非续期订阅）。回包 jwsPurchaseOrder 验签后解码。 */
async function queryPurchaseOrder(cred: HmsPaymentsConfig, purchaseOrderId: string, purchaseToken: string): Promise<HmsPurchaseOrderPayload | null> {
  const res = await callServerApi(cred, URL_ORDER_STATUS_QUERY, { purchaseOrderId, purchaseToken });
  if (!res || res.responseCode !== '0' || !res.jwsPurchaseOrder) return null;
  try {
    return verifyHmsJws(res.jwsPurchaseOrder, rootCaFor(cred)) as HmsPurchaseOrderPayload;
  } catch {
    return null;
  }
}

/**
 * 订阅状态查询（自动续期订阅）。取与 purchaseToken 匹配的订阅状态；
 * 历史列表优先（切换订阅后 last 可能指向新 token），status=1（生效中）才返回到期时刻。
 */
async function querySubscriptionExpiresAt(cred: HmsPaymentsConfig, purchaseOrderId: string, purchaseToken: string): Promise<string | undefined> {
  const res = await callServerApi(cred, URL_SUB_STATUS_QUERY, { purchaseOrderId, purchaseToken });
  if (!res || res.responseCode !== '0' || !res.jwsSubGroupStatus) return undefined;
  let payload: SubGroupStatusPayload;
  try {
    payload = verifyHmsJws(res.jwsSubGroupStatus, rootCaFor(cred)) as SubGroupStatusPayload;
  } catch {
    return undefined;
  }
  const history = payload.historySubscriptionStatusList ?? [];
  const matched =
    history.find((s) => s.purchaseToken === purchaseToken) ??
    (payload.lastSubscriptionStatus?.purchaseToken === purchaseToken ? payload.lastSubscriptionStatus : undefined);
  if (!matched || matched.status !== '1' || !matched.expiresTime) return undefined;
  return new Date(Number(matched.expiresTime)).toISOString();
}

/** 发货确认：needFinish=true 的订单必须确认才算完成购买；华为侧按 purchaseToken 幂等。 */
async function confirmShipment(cred: HmsPaymentsConfig, order: HmsPurchaseOrderPayload): Promise<void> {
  const path = order.productType === '2' ? URL_SUB_SHIPPED_CONFIRM : URL_ORDER_SHIPPED_CONFIRM;
  const res = await callServerApi(cred, path, {
    purchaseOrderId: order.purchaseOrderId ?? '',
    purchaseToken: order.purchaseToken ?? '',
  });
  if (!res || res.responseCode !== '0') {
    console.log(`[hms] shipment confirm failed: purchaseOrderId=${order.purchaseOrderId} code=${res?.responseCode ?? 'network'}`);
  }
}

// ── 适配器 ───────────────────────────────────────────────────────────────────

/**
 * HMS (Huawei) IAP server-side adapter（HarmonyOS NEXT / IAP Kit）。
 *
 * verifyReceipt：receipt 支持 `{purchaseToken, purchaseOrderId}`（NEXT 客户端）或裸
 * purchaseToken 字符串（旧客户端——无法调状态查询，直接验证失败）。服务端以
 * 订单状态查询 API 为准（JWT ES256 鉴权），回包 JWS 验签后校验归属与撤销状态。
 *
 * parseWebhook：v3 关键事件通知（AGC 配置的接收地址），body 为 {jwsNotification}。
 * 通知体不含 app 上下文，先解码（未验签）读 packageName 反查归属 app 选凭证，
 * 验签后再校验 applicationId 与凭证一致。
 */
export class HMSAdapter implements PaymentAdapter {
  readonly id: PaymentProviderId = 'hms';
  private cachedTokens = new Map<string, CachedToken>();

  private requireConfig(appId: string): HmsPaymentsConfig {
    const cred = paymentsForApp(appId).hms;
    if (!cred || !cred.appId || (!cred.clientId && !cred.privateKeyFile)) {
      throw new ApiError(503, 'PAYMENT_PROVIDER_NOT_CONFIGURED', `HMS 支付尚未配置（${appId}）`, true);
    }
    return cred;
  }

  /** 旧 Android HMS OAuth2 access token（client_credentials），按 HMS appId 缓存。 */
  private async getAccessToken(cred: HmsPaymentsConfig): Promise<string> {
    const cached = this.cachedTokens.get(cred.appId);
    if (cached && Date.now() < cached.expiresAt - 60000) {
      return cached.token;
    }
    const response = await fetch(HMS_TOKEN_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'client_credentials',
        client_id: cred.clientId,
        client_secret: cred.clientSecret,
      }),
      signal: AbortSignal.timeout(10_000),
    });
    if (!response.ok) {
      throw new ApiError(502, 'PAYMENT_PROVIDER_NOT_CONFIGURED', `HMS OAuth2 token 获取失败（${cred.appId}）`, true);
    }
    const data = await response.json() as { access_token?: string; expires_in?: number };
    if (!data.access_token) {
      throw new ApiError(502, 'PAYMENT_PROVIDER_NOT_CONFIGURED', `HMS OAuth2 无 access_token（${cred.appId}）`, true);
    }
    const expiresIn = (data.expires_in ?? 3600) * 1000;
    this.cachedTokens.set(cred.appId, { token: data.access_token, expiresAt: Date.now() + expiresIn });
    return data.access_token;
  }

  async verifyReceipt(input: Readonly<{
    appId: string; userId: string; orderId?: string; receipt: unknown;
  }>): Promise<VerifyResult> {
    // receipt 形态归一化：裸字符串（旧 Android HMS 客户端）或 {purchaseToken, purchaseOrderId}（NEXT）
    let purchaseToken = '';
    let purchaseOrderId = '';
    let isBareToken = false;
    if (typeof input.receipt === 'string') {
      purchaseToken = input.receipt.trim();
      isBareToken = true;
    } else if (input.receipt && typeof input.receipt === 'object') {
      const r = input.receipt as { purchaseToken?: unknown; purchaseOrderId?: unknown };
      if (typeof r.purchaseToken === 'string') purchaseToken = r.purchaseToken.trim();
      if (typeof r.purchaseOrderId === 'string') purchaseOrderId = r.purchaseOrderId.trim();
    }
    if (!purchaseToken) return { ok: false };

    const cred = this.requireConfig(input.appId);
    if (!purchaseOrderId || !cred.privateKeyFile || !cred.keyId || !cred.issuerId) {
      // HarmonyOS NEXT 服务端 API 不可用时，回退旧 Android HMS（OAuth2 + 区域订单服务）
      if (isBareToken && cred.clientId && cred.clientSecret) {
        return this.verifyLegacyAndroid(cred, purchaseToken);
      }
      return { ok: false };
    }

    try {
      const order = await queryPurchaseOrder(cred, purchaseOrderId, purchaseToken);
      if (!order) return { ok: false };
      // 防串扰：回包归属必须与请求一致
      if (order.purchaseToken !== purchaseToken) return { ok: false };
      if (order.purchaseOrderId !== purchaseOrderId) return { ok: false };
      // 已撤销/退款（revocationTime 有值即撤销）
      if (order.revocationTime) return { ok: false };

      // 自动续期订阅：查订阅组最新到期时刻（失败回退 plan 周期，不阻塞验证）
      const expiresAt = order.productType === '2'
        ? await querySubscriptionExpiresAt(cred, purchaseOrderId, purchaseToken)
        : undefined;

      // 发货确认异步执行：失败只记日志（购买仍有效，华为支持补确认）
      void confirmShipment(cred, order).catch(() => {});

      return {
        ok: true,
        storeTransactionId: purchaseToken,
        productId: order.productId ?? '',
        expiresAt,
      };
    } catch {
      return { ok: false };
    }
  }

  /** 旧 Android HMS Core IAP：OAuth2 client_credentials + 区域订单验证接口。 */
  private async verifyLegacyAndroid(cred: HmsPaymentsConfig, purchaseToken: string): Promise<VerifyResult> {
    try {
      const token = await this.getAccessToken(cred);
      const ordersUrl = cred.ordersUrl ?? 'https://orders-dre.iap.hicloud.com';
      const response = await fetch(
        `${ordersUrl}/applications/${cred.appId}/purchases/tokens/verify`,
        {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: JSON.stringify({ purchaseToken }),
          signal: AbortSignal.timeout(10_000),
        },
      );
      if (!response.ok) return { ok: false };
      const result = await response.json() as {
        responseCode?: string;
        purchaseTokenData?: { purchaseState?: number; productId?: string };
      };
      if (result.responseCode !== '0') return { ok: false };
      const data = result.purchaseTokenData;
      if (!data) return { ok: false };
      // purchaseState 0=Purchased, 1=Canceled, 2=Refunded
      if (data.purchaseState !== undefined && data.purchaseState !== 0) return { ok: false };
      return { ok: true, storeTransactionId: purchaseToken, productId: data.productId ?? '' };
    } catch {
      return { ok: false };
    }
  }

  async parseWebhook(
    rawBody: Buffer,
    _headers: Readonly<Record<string, string>>,
  ): Promise<WebhookEvent | null> {
    let jwsNotification = '';
    try {
      jwsNotification = (JSON.parse(rawBody.toString()) as { jwsNotification?: string }).jwsNotification ?? '';
    } catch {
      throw signatureInvalid('请求体非 JSON');
    }
    if (!jwsNotification) throw signatureInvalid('缺少 jwsNotification');

    // 先解码（未验签）读归属：packageName → app_id → 凭证（根证书按 app 配置）。
    // 归属字段只用于路由选择，真正信任建立在下方完整验签之后。
    let prePayload: HmsNotificationPayload;
    const preParts = jwsNotification.split('.');
    if (preParts.length !== 3 || !preParts[1]) throw signatureInvalid('JWS 结构不完整');
    try {
      prePayload = JSON.parse(b64urlToBuffer(preParts[1]).toString('utf8')) as HmsNotificationPayload;
    } catch {
      throw signatureInvalid('payload 预解码失败');
    }
    const packageName = prePayload.notificationMetaData?.packageName ?? '';
    const routedAppId = packageName ? appIdForHmsPackage(packageName) : undefined;
    if (!routedAppId) throw signatureInvalid(`未知 packageName: ${packageName}`);
    const cred = paymentsForApp(routedAppId).hms;
    if (!cred) throw signatureInvalid(`app 未配置 HMS 支付: ${routedAppId}`);

    // 完整验签（x5c 链锚定华为根 CA + OID + ES256）
    const payload = verifyHmsJws(jwsNotification, rootCaFor(cred));
    const meta = payload.notificationMetaData ?? {};
    // 归属校验：通知声称的 applicationId 必须与凭证一致
    if (meta.applicationId !== cred.appId) {
      throw signatureInvalid(`applicationId 不匹配: ${meta.applicationId}`);
    }

    const purchaseToken = meta.purchaseToken ?? '';
    if (!purchaseToken) throw signatureInvalid('缺少 purchaseToken');

    // DID_NEW_TRANSACTION(购买/续订/恢复) → renew；REVOKE(退款/撤销) → refund；
    // EXPIRE(到期/保留期) → expire；DID_CHANGE_RENEWAL_STATUS / SYNC / 未知 → 不改权益（ack）。
    let kind: WebhookEvent['kind'];
    if (payload.notificationType === 'REVOKE') kind = 'refund';
    else if (payload.notificationType === 'EXPIRE') kind = 'expire';
    else if (payload.notificationType === 'DID_NEW_TRANSACTION' || payload.notificationType === 'RENEWAL_TIME_MODIFIED') kind = 'renew';
    else return null;

    // renew 需要新到期时刻：订阅商品查订阅状态（查询失败不失败通知——服务端
    // 对缺 expiresAt 的 renew 只 ack 不延权，等下一条通知或下次购买兜底）
    let expiresAt: string | undefined;
    if (kind === 'renew' && meta.type === 2) {
      const orderId = meta.purchaseOrderId ?? '';
      if (orderId && cred.privateKeyFile && cred.keyId && cred.issuerId) {
        expiresAt = await querySubscriptionExpiresAt(cred, orderId, purchaseToken).catch(() => undefined);
      }
    }

    const order = await findOrderByStoreTransactionId(purchaseToken);
    // 幂等键：notificationRequestId 规范必有；缺失时退化为 通知内容哈希（同一条重发去重，
    // 不同通知不会碰撞——purchaseToken+类型+签名时间不同）
    const eventId = payload.notificationRequestId
      ?? createHash('sha256').update(jwsNotification).digest('hex').slice(0, 32);
    return {
      provider: 'hms',
      eventId,
      kind,
      orderId: order?.id ?? '',
      expiresAt,
    };
  }
}

export const hmsAdapter = new HMSAdapter();
