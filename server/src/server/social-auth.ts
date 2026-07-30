import { createRemoteJWKSet, jwtVerify } from 'jose';
import { database, nowIso } from './database';
import { ApiError } from './http';
import { createId } from './ids';
import { createUserSession, getUserRow } from './auth';
import { RuntimeConfig } from '@/domain/config';
import { ClientPlatform } from './client-context';

type Provider = 'apple' | 'google' | 'github';
type SocialInput = Readonly<{
  appId: string;
  provider: Provider;
  idToken?: string;
  authorizationCode?: string;
  redirectUri?: string;
  codeVerifier?: string;
  nonce?: string;
  deviceName: string;
}>;
type SocialProfile = Readonly<{
  subject: string;
  email: string | null;
  emailVerified: boolean;
  name: string;
}>;

const appleKeys = createRemoteJWKSet(new URL('https://appleid.apple.com/auth/keys'));
const googleKeys = createRemoteJWKSet(new URL('https://www.googleapis.com/oauth2/v3/certs'));

export function configuredProviders(config: RuntimeConfig, platform: ClientPlatform) {
  const policy = new Map(
    config.auth.providers.map((item) => [
      item.id,
      item.enabled && item.platforms.includes(platform),
    ]),
  );
  return {
    password: policy.get('password') === true,
    phone: policy.get('phone') === true,
    apple: policy.get('apple') === true && Boolean(clientId(config, 'apple', platform)),
    google: policy.get('google') === true && Boolean(clientId(config, 'google', platform)),
    github: policy.get('github') === true && Boolean(
      clientId(config, 'github', platform) && process.env.GITHUB_CLIENT_SECRET,
    ),
    wechat: false,
  };
}

export function providerPolicy(config: RuntimeConfig, platform: ClientPlatform) {
  return Object.fromEntries(config.auth.providers.map((provider) => [
    provider.id,
    provider.enabled && provider.platforms.includes(platform),
  ]));
}

export function publicProviderConfig(config: RuntimeConfig, platform: ClientPlatform) {
  return Object.fromEntries(
    (['apple', 'google', 'github'] as const)
      .map((provider) => [provider, clientId(config, provider, platform)])
      .filter((entry): entry is [string, string] => Boolean(entry[1]))
      .map(([provider, providerClientId]) => [
        provider,
        { clientId: providerClientId },
      ]),
  );
}

export async function socialSignIn(input: SocialInput, config: RuntimeConfig, platform: ClientPlatform) {
  ensureConfigured(input.provider, config, platform);
  const profile = await readProfile(input, config, platform);
  const identity = database.prepare(`
    SELECT user_id AS userId FROM external_identities
    WHERE provider = ? AND provider_subject = ?
  `).get(
    input.provider,
    scopedSubject(input.appId, profile.subject),
  ) as { userId: string } | undefined;
  if (identity) return createUserSession(identity.userId, input.deviceName);
  const userId = findOrCreateUser(input.appId, profile);
  database.prepare(`
    INSERT INTO external_identities(
      id, user_id, provider, provider_subject, email, created_at
    ) VALUES (?, ?, ?, ?, ?, ?)
  `).run(
    createId(),
    userId,
    input.provider,
    scopedSubject(input.appId, profile.subject),
    profile.email,
    nowIso(),
  );
  return createUserSession(userId, input.deviceName);
}

function ensureConfigured(
  provider: Provider,
  config: RuntimeConfig,
  platform: ClientPlatform,
) {
  if (!configuredProviders(config, platform)[provider]) {
    throw new ApiError(503, 'PROVIDER_NOT_CONFIGURED', `${provider} 登录尚未配置`);
  }
}

async function readProfile(
  input: SocialInput,
  config: RuntimeConfig,
  platform: ClientPlatform,
) {
  if (input.provider === 'apple') {
    return verifyApple(input.idToken, clientId(config, 'apple', platform) ?? '', input.nonce);
  }
  if (input.provider === 'google') {
    const provider = config.auth.providers.find((item) => item.id === 'google');
    const audiences = [
      ...Object.values(provider?.clientIds ?? {})
        .filter((value): value is string => Boolean(value)),
      ...(process.env.GOOGLE_CLIENT_IDS ?? '').split(',').filter(Boolean),
    ];
    return verifyGoogle(input.idToken, [...new Set(audiences)], input.nonce);
  }
  return verifyGitHub(input, clientId(config, 'github', platform) ?? '');
}

async function verifyApple(
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

async function verifyGoogle(
  idToken: string | undefined,
  audiences: string[],
  nonce?: string,
): Promise<SocialProfile> {
  if (!idToken) throw new ApiError(400, 'ID_TOKEN_REQUIRED', '缺少 Google 身份令牌');
  const { payload } = await jwtVerify(idToken, googleKeys, {
    issuer: ['https://accounts.google.com', 'accounts.google.com'],
    audience: audiences,
  });
  ensureNonce(payload.nonce, nonce);
  return {
    subject: String(payload.sub),
    email: typeof payload.email === 'string' ? payload.email : null,
    emailVerified: payload.email_verified === true,
    name: typeof payload.name === 'string' ? payload.name : 'Google 用户',
  };
}

async function verifyGitHub(input: SocialInput, providerClientId: string): Promise<SocialProfile> {
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

function findOrCreateUser(appId: string, profile: SocialProfile) {
  if (profile.email && profile.emailVerified) {
    const existing = database.prepare(
      'SELECT id FROM users WHERE app_id = ? AND email = ?',
    ).get(appId, profile.email.toLowerCase()) as { id: string } | undefined;
    if (existing) return existing.id;
  }
  const id = createId();
  const timestamp = nowIso();
  const email = profile.email?.toLowerCase() ?? `external-${id}@invalid.local`;
  database.prepare(`
    INSERT INTO users(
      id, app_id, email, password_hash, username, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?)
  `).run(id, appId, email, `external$${createId()}`, profile.name, timestamp, timestamp);
  return getUserRow(id).id;
}

function scopedSubject(appId: string, subject: string) {
  return `${appId}:${subject}`;
}

function ensureNonce(actual: unknown, expected?: string) {
  if (expected && actual !== expected) {
    throw new ApiError(401, 'OIDC_NONCE_INVALID', '身份令牌校验失败');
  }
}

function clientId(
  config: RuntimeConfig,
  provider: 'apple' | 'google' | 'github',
  platform: ClientPlatform,
) {
  const configured = config.auth.providers.find((item) => item.id === provider)
    ?.clientIds?.[platform];
  if (configured) return configured;
  if (provider === 'apple') return process.env.APPLE_CLIENT_ID;
  if (provider === 'google') return process.env.GOOGLE_CLIENT_IDS?.split(',')[0];
  return process.env.GITHUB_CLIENT_ID;
}
