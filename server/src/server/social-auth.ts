import { database, nowIso, runTransaction } from './database';
import { ApiError } from './http';
import { createId } from './ids';
import { createUserSession, getUserRow } from './auth';
import { verifyApple, verifyGitHub, verifyGoogle, verifyHuawei } from './social-auth-providers';
import type { RuntimeConfig } from '@/domain/config';
import type { ClientPlatform } from './client-context';

export type Provider = 'apple' | 'google' | 'github' | 'huawei';
export type SocialInput = Readonly<{
  appId: string;
  provider: Provider;
  idToken?: string;
  authorizationCode?: string;
  redirectUri?: string;
  codeVerifier?: string;
  nonce?: string;
  deviceName: string;
}>;
export type SocialProfile = Readonly<{
  subject: string;
  email: string | null;
  emailVerified: boolean;
  name: string;
}>;

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
    huawei: policy.get('huawei') === true && Boolean(
      clientId(config, 'huawei', platform) && process.env.HUAWEI_OAUTH_CLIENT_SECRET,
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
    (['apple', 'google', 'github', 'huawei'] as const)
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
  if (input.provider === 'huawei') {
    // 华为一键登录：授权码 → 手机号，按手机号跨 provider 合并（与 phone 登录同账号）。
    const profile = await readProfile(input, config, platform);
    const userId = await findOrCreateHuaweiUser(input.appId, profile.subject);
    return await createUserSession(userId, input.appId, input.deviceName);
  }
  const profile = await readProfile(input, config, platform);
  const identity = await database.prepare(`
    SELECT user_id AS userId FROM external_identities
    WHERE provider = ? AND provider_subject = ?
  `).get(
    input.provider,
    scopedSubject(input.appId, profile.subject),
  ) as { userId: string } | undefined;
  if (identity) return await createUserSession(identity.userId, input.appId, input.deviceName);
  const userId = await findOrCreateUser(input.appId, profile);
  await database.prepare(`
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
  return await createUserSession(userId, input.appId, input.deviceName);
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
  if (input.provider === 'huawei') {
    return verifyHuawei(input);
  }
  return verifyGitHub(input, clientId(config, 'github', platform) ?? '');
}

/**
 * 华为账号按手机号找/建用户，并跨 provider 与 phone 登录合并到同一账号。
 * 1) 已有 huawei identity → 直接返回
 * 2) 已有 phone identity（同手机号）→ 追加 huawei identity 到同一用户
 * 3) 都没有 → 新建用户 + 同时插 huawei 和 phone 两条 identity
 */
async function findOrCreateHuaweiUser(appId: string, phone: string) {
  const huaweiSubject = scopedSubject(appId, phone);
  const phoneSubject = scopedSubject(appId, phone);

  return runTransaction(async () => {
    const huaweiIdentity = await database.prepare(`
      SELECT user_id AS userId FROM external_identities
      WHERE provider = 'huawei' AND provider_subject = ?
    `).get(huaweiSubject) as { userId: string } | undefined;
    if (huaweiIdentity) return huaweiIdentity.userId;

    const phoneIdentity = await database.prepare(`
      SELECT user_id AS userId FROM external_identities
      WHERE provider = 'phone' AND provider_subject = ?
    `).get(phoneSubject) as { userId: string } | undefined;

    if (phoneIdentity) {
      await database.prepare(`
        INSERT INTO external_identities(
          id, user_id, provider, provider_subject, created_at
        ) VALUES (?, ?, 'huawei', ?, ?)
      `).run(createId(), phoneIdentity.userId, huaweiSubject, nowIso());
      return phoneIdentity.userId;
    }

    // 都没有：新建用户，同时挂 huawei + phone 两条身份，后续手机号验证码登录会合入同账号
    const userId = createId();
    const createdAt = nowIso();
    // 无真实邮箱 → NULL（不再生成 xxx@phone.invalid 伪邮箱，issue #14）。
    await database.prepare(`
      INSERT INTO users(
        id, app_id, email, password_hash, username, created_at, updated_at
      ) VALUES (?, ?, NULL, ?, ?, ?, ?)
    `).run(
      userId,
      appId,
      `external$${createId()}`,
      `手机用户${phone.slice(-4)}`,
      createdAt,
      createdAt,
    );
    for (const provider of ['huawei', 'phone'] as const) {
      await database.prepare(`
        INSERT INTO external_identities(
          id, user_id, provider, provider_subject, created_at
        ) VALUES (?, ?, ?, ?, ?)
      `).run(
        createId(),
        userId,
        provider,
        provider === 'huawei' ? huaweiSubject : phoneSubject,
        createdAt,
      );
    }
    return userId;
  });
}

async function findOrCreateUser(appId: string, profile: SocialProfile) {
  if (profile.email && profile.emailVerified) {
    const existing = await database.prepare(
      'SELECT id FROM users WHERE app_id = ? AND email = ?',
    ).get(appId, profile.email.toLowerCase()) as { id: string } | undefined;
    if (existing) return existing.id;
  }
  const id = createId();
  const timestamp = nowIso();
  const email = profile.email?.toLowerCase() ?? `external-${id}@invalid.local`;
  await database.prepare(`
    INSERT INTO users(
      id, app_id, email, password_hash, username, email_verified, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  `).run(
    id,
    appId,
    email,
    `external$${createId()}`,
    profile.name,
    profile.emailVerified ? 1 : 0,
    timestamp,
    timestamp,
  );
  return (await getUserRow(id)).id;
}

function scopedSubject(appId: string, subject: string) {
  return `${appId}:${subject}`;
}

function clientId(
  config: RuntimeConfig,
  provider: 'apple' | 'google' | 'github' | 'huawei',
  platform: ClientPlatform,
) {
  const configured = config.auth.providers.find((item) => item.id === provider)
    ?.clientIds?.[platform];
  if (configured) return configured;
  if (provider === 'apple') return process.env.APPLE_CLIENT_ID;
  if (provider === 'google') return process.env.GOOGLE_CLIENT_IDS?.split(',')[0];
  if (provider === 'huawei') return process.env.HUAWEI_OAUTH_CLIENT_ID;
  return process.env.GITHUB_CLIENT_ID;
}
