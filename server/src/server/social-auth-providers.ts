// 各 provider 的身份凭证校验（Apple/Google 走 OIDC JWKT，GitHub 走 OAuth 换
// token 后读 profile，华为走 Account Kit 一键登录换手机号）。
// 从 social-auth.ts 拆出以服从 CI 350 行硬上限；类型经 import type 回引无环。
import { createLocalJWKSet, createRemoteJWKSet, jwtVerify } from 'jose';
import type { JSONWebKeySet, JWTVerifyGetKey } from 'jose';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { ApiError } from './http';
import type { SocialInput, SocialProfile } from './social-auth';

const appleKeys = createRemoteJWKSet(new URL('https://appleid.apple.com/auth/keys'));

// Google JWKS：googleapis.com 自中国大陆服务器不可达，createRemoteJWKSet 首拉
// 即挂且 jose 不支持自定义 fetch。改为「中转优先 → 磁盘缓存 → 镜像内 seed 兜
// 底」：GOOGLE_JWKS_URL 可指向可信中转（如 CF Worker 反代 googleapis）；远端
// 不可达时用缓存/seed 的 createLocalJWKSet 验签，Google 轮换密钥（kid 未命中）
// 时再刷一次远端，刷不动则维持缓存（keys 极少轮换，够稳）。
const GOOGLE_JWKS_URL = process.env.GOOGLE_JWKS_URL ?? 'https://www.googleapis.com/oauth2/v3/certs';
const GOOGLE_JWKS_SEED = path.join(process.cwd(), 'certs/google-jwks-seed.json');
const GOOGLE_JWKS_CACHE = path.join(process.cwd(), 'certs/google-jwks-cache.json');

let googleKeys: JWTVerifyGetKey | null = null;

function readCachedGoogleJwks(): JSONWebKeySet | null {
  for (const file of [GOOGLE_JWKS_CACHE, GOOGLE_JWKS_SEED]) {
    try {
      const parsed = JSON.parse(readFileSync(file, 'utf8')) as JSONWebKeySet;
      if (Array.isArray(parsed.keys) && parsed.keys.length > 0) return parsed;
    } catch {
      // 缺文件/坏 JSON 依次回落下一个来源
    }
  }
  return null;
}

async function refreshGoogleJwks(): Promise<boolean> {
  try {
    const response = await fetch(GOOGLE_JWKS_URL, { signal: AbortSignal.timeout(4000) });
    if (!response.ok) return false;
    const jwks = (await response.json()) as JSONWebKeySet;
    if (!Array.isArray(jwks.keys) || jwks.keys.length === 0) return false;
    mkdirSync(path.dirname(GOOGLE_JWKS_CACHE), { recursive: true });
    writeFileSync(GOOGLE_JWKS_CACHE, JSON.stringify(jwks));
    googleKeys = createLocalJWKSet(jwks);
    return true;
  } catch {
    return false;
  }
}

async function resolveGoogleKeys(): Promise<JWTVerifyGetKey> {
  if (googleKeys) return googleKeys;
  if (await refreshGoogleJwks()) return googleKeys!;
  const cached = readCachedGoogleJwks();
  if (!cached) {
    throw new ApiError(503, 'GOOGLE_JWKS_UNAVAILABLE', 'Google 登录公钥暂不可用');
  }
  googleKeys = createLocalJWKSet(cached);
  return googleKeys;
}

function ensureNonce(actual: unknown, expected?: string) {
  if (expected && actual !== expected) {
    throw new ApiError(401, 'OIDC_NONCE_INVALID', '身份令牌校验失败');
  }
}

export async function verifyApple(
  idToken: string | undefined,
  clientId: string,
  nonce?: string,
): Promise<SocialProfile> {
  if (!idToken) throw new ApiError(400, 'ID_TOKEN_REQUIRED', '缺少 Apple 身份令牌');
  const { payload } = await jwtVerify(idToken, appleKeys, {
    issuer: 'https://appleid.apple.com',
    audience: clientId,
  });
  ensureNonce(payload.nonce, nonce);
  return {
    subject: String(payload.sub),
    email: typeof payload.email === 'string' ? payload.email : null,
    emailVerified: payload.email_verified === true || payload.email_verified === 'true',
    name: 'Apple 用户',
  };
}

export async function verifyGoogle(
  idToken: string | undefined,
  audiences: string[],
  nonce?: string,
): Promise<SocialProfile> {
  if (!idToken) throw new ApiError(400, 'ID_TOKEN_REQUIRED', '缺少 Google 身份令牌');
  const verifyOptions = {
    issuer: ['https://accounts.google.com', 'accounts.google.com'],
    audience: audiences,
  };
  let payload: Awaited<ReturnType<typeof jwtVerify>>['payload'];
  try {
    ({ payload } = await jwtVerify(idToken, await resolveGoogleKeys(), verifyOptions));
  } catch (error) {
    // kid 未命中（Google 轮换密钥）→ 刷一次远端重试；仍失败（含签名错/过期/
    // 格式坏）统一归 401，避免 jose 裸错误漏成 500 INTERNAL_ERROR
    const isKidMiss = (error as { code?: string }).code === 'JWKSNoMatchingKey';
    if (isKidMiss && (await refreshGoogleJwks())) {
      try {
        ({ payload } = await jwtVerify(idToken, await resolveGoogleKeys(), verifyOptions));
      } catch {
        throw new ApiError(401, 'ID_TOKEN_INVALID', '身份令牌校验失败');
      }
    } else {
      throw new ApiError(401, 'ID_TOKEN_INVALID', '身份令牌校验失败');
    }
  }
  ensureNonce(payload.nonce, nonce);
  return {
    subject: String(payload.sub),
    email: typeof payload.email === 'string' ? payload.email : null,
    emailVerified: payload.email_verified === true,
    name: typeof payload.name === 'string' ? payload.name : 'Google 用户',
  };
}

export async function verifyGitHub(input: SocialInput, providerClientId: string): Promise<SocialProfile> {
  if (!input.authorizationCode || !input.redirectUri) {
    throw new ApiError(400, 'AUTHORIZATION_CODE_REQUIRED', '缺少 GitHub 授权码');
  }
  const token = await exchangeGitHubCode(input, providerClientId);
  const headers = { Authorization: `Bearer ${token}`, Accept: 'application/vnd.github+json' };
  const [userResponse, emailResponse] = await Promise.all([
    fetch('https://api.github.com/user', { headers }),
    fetch('https://api.github.com/user/emails', { headers }),
  ]);
  if (!userResponse.ok || !emailResponse.ok) {
    throw new ApiError(401, 'GITHUB_PROFILE_FAILED', '无法读取 GitHub 身份');
  }
  const user = await userResponse.json() as { id: number; login: string; name?: string };
  const emails = await emailResponse.json() as Array<{
    email: string;
    primary: boolean;
    verified: boolean;
  }>;
  const email = emails.find((item) => item.primary && item.verified);
  return {
    subject: String(user.id),
    email: email?.email ?? null,
    emailVerified: Boolean(email),
    name: user.name || user.login,
  };
}

async function exchangeGitHubCode(input: SocialInput, providerClientId: string) {
  const response = await fetch('https://github.com/login/oauth/access_token', {
    method: 'POST',
    headers: { Accept: 'application/json', 'Content-Type': 'application/json' },
    body: JSON.stringify({
      client_id: providerClientId,
      client_secret: process.env.GITHUB_CLIENT_SECRET,
      code: input.authorizationCode,
      redirect_uri: input.redirectUri,
      code_verifier: input.codeVerifier,
    }),
  });
  const body = await response.json() as { access_token?: string };
  if (!response.ok || !body.access_token) {
    throw new ApiError(401, 'GITHUB_CODE_INVALID', 'GitHub 授权码无效');
  }
  return body.access_token;
}

/**
 * 华为一键登录：用授权码换手机号（Account Kit quickLogin）。
 * 请求 https://account-api.cloud.huawei.com/oauth2/v6/quickLogin/getPhoneNumber，
 * body { code, clientId, clientSecret }，无需 token 交换，一步到位。
 */
export async function verifyHuawei(input: SocialInput): Promise<SocialProfile> {
  const code = input.authorizationCode;
  if (!code) {
    throw new ApiError(400, 'AUTHORIZATION_CODE_REQUIRED', '缺少华为授权码');
  }
  const clientId = process.env.HUAWEI_OAUTH_CLIENT_ID;
  const clientSecret = process.env.HUAWEI_OAUTH_CLIENT_SECRET;
  if (!clientId || !clientSecret) {
    throw new ApiError(503, 'HUAWEI_OAUTH_NOT_CONFIGURED', '华为登录尚未配置');
  }
  let body: Record<string, unknown>;
  try {
    const response = await fetch(
      'https://account-api.cloud.huawei.com/oauth2/v6/quickLogin/getPhoneNumber',
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ code, clientId, clientSecret }),
      },
    );
    body = await response.json() as Record<string, unknown>;
    if (!response.ok) {
      throw new ApiError(401, 'HUAWEI_PHONE_FAILED', '无法获取华为账号手机号');
    }
  } catch (error) {
    if (error instanceof ApiError) throw error;
    throw new ApiError(502, 'HUAWEI_PHONE_NETWORK', '华为登录服务暂不可用');
  }
  const resultCode = body['resultCode'] as number | undefined;
  if (resultCode !== undefined && resultCode !== 0) {
    const desc = typeof body['resultDesc'] === 'string' ? body['resultDesc'] : '';
    throw new ApiError(401, 'HUAWEI_PHONE_FAILED', `无法获取华为账号手机号 (${resultCode}${desc ? ` ${desc}` : ''})`);
  }
  const phoneNumber = typeof body['phoneNumber'] === 'string' ? body['phoneNumber'] : null;
  const purePhoneNumber = typeof body['purePhoneNumber'] === 'string' ? body['purePhoneNumber'] : null;
  const countryCode = typeof body['phoneCountryCode'] === 'string' ? body['phoneCountryCode'] : '';
  const phone = phoneNumber ?? (purePhoneNumber ? `+${countryCode || '86'}${purePhoneNumber}` : '');
  if (!phone) {
    throw new ApiError(401, 'HUAWEI_PHONE_FAILED', '华为账号未返回手机号');
  }
  return { subject: phone, email: null, emailVerified: false, name: '华为用户' };
}
