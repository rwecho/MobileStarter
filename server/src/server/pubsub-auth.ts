import { jwtVerify, type JWTVerifyGetKey } from 'jose';
import { ApiError } from './http';
import { resolveGoogleKeys } from './social-auth-providers';

/**
 * Google Pub/Sub push 订阅的 OIDC 传输鉴权。
 *
 * RTDN 经 Pub/Sub push 投递到 /webhooks/google；在订阅上配置
 * authenticationInfo.serviceAccountEmail（可选 oidcToken.audience）后，
 * 每次推送会附带 Google 签发的 OIDC Bearer JWT（Authorization 头）。
 * 这里验证其签名（Google 公钥 JWKS）、签发者与可选的 audience/email 绑定，
 * 与 Apple（JWS 验签）、HMS（x5c 链验签）对齐——传输层不验签的 webhook
 * 可被伪造报文操纵权益撤销。
 *
 * 公钥解析复用登录侧 resolveGoogleKeys（中转优先→磁盘缓存→seed 兜底）：
 * googleapis.com 自大陆机房不可达，不能直连 createRemoteJWKSet。
 *
 * 灰度开关：GOOGLE_PUBSUB_AUDIENCE / GOOGLE_PUBSUB_SERVICE_ACCOUNT 任一
 * 设置即强制校验（pubsubAuthConfigured）；都未设置时放行并告警——先部署
 * 后配置不破坏现有 push 订阅。
 */

const GOOGLE_ISSUER = 'https://accounts.google.com';

export type PubSubAuthOptions = Readonly<{
  /** 测试注入：本地 JWKS（默认远端 Google 公钥） */
  jwks?: JWTVerifyGetKey;
  /** 期望 aud（默认取 GOOGLE_PUBSUB_AUDIENCE；未设则不校验 aud） */
  audience?: string;
  /** 期望 token.email（默认取 GOOGLE_PUBSUB_SERVICE_ACCOUNT；未设则不校验） */
  serviceAccount?: string;
}>;

export function pubsubAuthConfigured(): boolean {
  return Boolean(process.env.GOOGLE_PUBSUB_AUDIENCE || process.env.GOOGLE_PUBSUB_SERVICE_ACCOUNT);
}

let warnedUnconfigured = false;

/** 未配置 env 时的放行告警只打一次，避免日志刷屏。 */
export function warnPubsubAuthUnconfigured(): void {
  if (warnedUnconfigured) return;
  warnedUnconfigured = true;
  console.warn('[google-webhook] GOOGLE_PUBSUB_AUDIENCE/SERVICE_ACCOUNT 未配置：' +
    'Pub/Sub push 走无鉴权放行（灰度模式），请尽快在订阅上启用 OIDC 并设置 env');
}

/** 验证失败一律 401（Pub/Sub 对 4xx 不重投）；JWKS 暂不可用 503 让其稍后重投。 */
export async function verifyPubSubPush(
  headers: Readonly<Record<string, string>>, opts?: PubSubAuthOptions,
): Promise<void> {
  const token = (headers['authorization'] ?? '').replace(/^Bearer\s+/i, '');
  if (!token) {
    console.warn('[google-webhook] 拒绝推送：缺少 OIDC token');
    throw new ApiError(401, 'WEBHOOK_SIGNATURE_INVALID', 'google webhook 缺少 OIDC token', false);
  }
  const audience = opts?.audience ?? process.env.GOOGLE_PUBSUB_AUDIENCE;
  const serviceAccount = opts?.serviceAccount ?? process.env.GOOGLE_PUBSUB_SERVICE_ACCOUNT;
  try {
    const verifyOptions: Parameters<typeof jwtVerify>[2] = { issuer: GOOGLE_ISSUER };
    if (audience) verifyOptions.audience = audience;
    const keys = opts?.jwks ?? await resolveGoogleKeys();
    const { payload } = await jwtVerify(token, keys, verifyOptions);
    if (serviceAccount && payload.email !== serviceAccount) {
      console.warn('[google-webhook] 拒绝推送：OIDC email 不匹配', payload.email);
      throw new ApiError(401, 'WEBHOOK_SIGNATURE_INVALID', 'google webhook OIDC email 不匹配', false);
    }
  } catch (error) {
    if (error instanceof ApiError) throw error;
    // 验签失败必须留痕：401 静默会引发 Pub/Sub 重试风暴且无从排查
    console.warn('[google-webhook] OIDC 验证失败:',
      (error as Error)?.name, (error as Error)?.message);
    if (error instanceof Error && error.name === 'JWKSTemporarilyUnavailableError') {
      throw new ApiError(503, 'WEBHOOK_VERIFY_UNAVAILABLE', 'google JWKS 暂不可用', true);
    }
    throw new ApiError(401, 'WEBHOOK_SIGNATURE_INVALID', 'google webhook OIDC 验证失败', false);
  }
}
