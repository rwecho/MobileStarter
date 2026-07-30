import { NextRequest } from 'next/server';
import { PublicUser } from '@/domain/user';
import { database, nowIso } from './database';
import { ApiError } from './http';
import { createId, createSessionToken, hashToken } from './ids';
import { hashPassword, verifyPassword } from './passwords';

type UserRow = {
  id: string;
  app_id: string;
  email: string;
  password_hash: string;
  username: string;
  display_name: string | null;
  bio: string;
  avatar_url: string | null;
  tier_id: string;
  settings: string;
  created_at: string;
  updated_at: string;
};

type SessionRow = {
  id: string;
  user_id: string;
  token_hash: string;
  device_name: string;
  created_at: string;
  last_seen_at: string;
  expires_at: string;
  revoked_at: string | null;
};

export type AuthContext = Readonly<{
  user: UserRow;
  session: SessionRow;
}>;

export async function signUp(input: {
  appId: string;
  email: string;
  password: string;
  username: string;
  deviceName: string;
}) {
  const email = input.email.trim().toLowerCase();
  const emailExists = database.prepare(
    'SELECT 1 FROM users WHERE app_id = ? AND email = ?',
  ).get(input.appId, email);
  if (emailExists) throw new ApiError(409, 'EMAIL_EXISTS', '该邮箱已注册');
  const username = input.username.trim();
  const usernameExists = database.prepare(
    'SELECT 1 FROM users WHERE app_id = ? AND lower(username) = ?',
  ).get(input.appId, username.toLowerCase());
  if (usernameExists) throw new ApiError(409, 'USERNAME_EXISTS', '该用户名已被使用');
  const id = createId();
  const createdAt = nowIso();
  const passwordHash = await hashPassword(input.password);
  database.prepare(`
    INSERT INTO users(
      id, app_id, email, password_hash, username, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?)
  `).run(id, input.appId, email, passwordHash, username, createdAt, createdAt);
  createWelcomeNotifications(id);
  return createUserSession(id, input.deviceName);
}

export async function signIn(input: {
  appId: string;
  identifier: string;
  password: string;
  deviceName: string;
}) {
  const identifier = input.identifier.trim();
  const normalized = identifier.toLowerCase();
  const user = findUserByIdentifier(input.appId, identifier, normalized);
  const valid = user && await verifyPassword(user.password_hash, input.password);
  if (!user || !valid) {
    throw new ApiError(401, 'INVALID_CREDENTIALS', '账号或密码不正确');
  }
  return createUserSession(user.id, input.deviceName);
}

function findUserByIdentifier(appId: string, identifier: string, normalized: string) {
  const direct = database.prepare(`
    SELECT * FROM users
    WHERE app_id = ? AND (email = ? OR lower(username) = ?)
  `).get(appId, normalized, normalized) as UserRow | undefined;
  if (direct || !identifier.startsWith('+')) return direct;
  return database.prepare(`
    SELECT users.* FROM users
    JOIN external_identities ON external_identities.user_id = users.id
    WHERE users.app_id = ?
      AND external_identities.provider = 'phone'
      AND external_identities.provider_subject = ?
  `).get(appId, `${appId}:${identifier}`) as UserRow | undefined;
}

export function requireAuth(request: NextRequest): AuthContext {
  const header = request.headers.get('authorization');
  const token = header?.startsWith('Bearer ') ? header.slice(7) : '';
  if (!token) throw new ApiError(401, 'UNAUTHORIZED', '请先登录');
  const session = database.prepare(`
    SELECT * FROM sessions
    WHERE token_hash = ? AND revoked_at IS NULL AND expires_at > ?
  `).get(hashToken(token), nowIso()) as SessionRow | undefined;
  if (!session) throw new ApiError(401, 'SESSION_EXPIRED', '登录状态已过期');
  const user = getUserRow(session.user_id);
  const appId = request.headers.get('x-app-id')?.trim() || 'mobileui';
  if (user.app_id !== appId) {
    throw new ApiError(401, 'TENANT_MISMATCH', '登录状态不属于当前应用');
  }
  database.prepare(
    'UPDATE sessions SET last_seen_at = ? WHERE id = ?',
  ).run(nowIso(), session.id);
  return { user, session };
}

export function revokeSession(sessionId: string) {
  database.prepare(
    'UPDATE sessions SET revoked_at = ? WHERE id = ? AND revoked_at IS NULL',
  ).run(nowIso(), sessionId);
}

export function revokeAllSessions(userId: string) {
  database.prepare(
    'UPDATE sessions SET revoked_at = ? WHERE user_id = ? AND revoked_at IS NULL',
  ).run(nowIso(), userId);
}

export function toPublicUser(row: UserRow): PublicUser {
  return {
    id: row.id,
    email: row.email,
    username: row.username,
    displayName: row.display_name ?? row.username,
    bio: row.bio,
    avatarUrl: row.avatar_url,
    tierId: row.tier_id,
    settings: JSON.parse(row.settings) as Record<string, string | boolean | number>,
    createdAt: row.created_at,
  };
}

export function getUserRow(userId: string) {
  const user = database.prepare(
    'SELECT * FROM users WHERE id = ?',
  ).get(userId) as UserRow | undefined;
  if (!user) throw new ApiError(401, 'USER_NOT_FOUND', '账号不存在');
  return user;
}

export function createUserSession(userId: string, deviceName: string) {
  const token = createSessionToken();
  const sessionId = createId();
  const createdAt = nowIso();
  const expiresAt = new Date(Date.now() + 30 * 86400_000).toISOString();
  database.prepare(`
    INSERT INTO sessions(
      id, user_id, token_hash, device_name, created_at, last_seen_at, expires_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?)
  `).run(
    sessionId,
    userId,
    hashToken(token),
    deviceName || 'Unknown device',
    createdAt,
    createdAt,
    expiresAt,
  );
  return { token, user: toPublicUser(getUserRow(userId)) };
}

function createWelcomeNotifications(userId: string) {
  const insert = database.prepare(`
    INSERT INTO notifications(id, user_id, type, title, body, route, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?)
  `);
  const createdAt = nowIso();
  insert.run(
    createId(),
    userId,
    'system',
    '欢迎使用 MobileUI',
    '你的账号已创建，所有设置会安全同步。',
    'profile.home',
    createdAt,
  );
  insert.run(
    createId(),
    userId,
    'membership',
    '探索 Pro 创作能力',
    '查看动态会员等级与当前可用方案。',
    'membership.home',
    createdAt,
  );
}
