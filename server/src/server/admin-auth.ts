import { cookies } from 'next/headers';
import { NextRequest } from 'next/server';
import {
  ADMIN_COOKIE,
  ADMIN_SESSION_TTL_MS,
  getAdminFromRequest,
  type AdminProfile,
} from './admin-identity';
import { ApiError } from './http';

export type { AdminProfile } from './admin-identity';
export { ADMIN_COOKIE, ADMIN_SESSION_TTL_MS } from './admin-identity';

export type AdminScope = Readonly<{ appId: string; environment: string }>;

const HEADER_ADMIN: AdminProfile = {
  id: 'admin-key',
  username: 'admin-key',
  email: '',
  createdAt: '',
};

/**
 * Authorizes a control-plane request. Prefers a valid admin cookie session; in
 * non-production environments an `x-admin-key` header is still accepted so that
 * local curl and automation keep working. Throws 401 otherwise.
 */
export function authorizeAdmin(request: NextRequest): AdminProfile {
  const admin = getAdminFromRequest(request);
  if (admin) return admin;
  if (process.env.NODE_ENV !== 'production') {
    const expected = process.env.MOBILEUI_ADMIN_KEY ?? 'local-development-admin';
    if (request.headers.get('x-admin-key') === expected) return HEADER_ADMIN;
  }
  throw new ApiError(401, 'ADMIN_UNAUTHORIZED', '请先登录控制台');
}

export function readAdminScope(request: NextRequest): AdminScope {
  return {
    appId: request.headers.get('x-app-id')?.trim() || 'mobileui',
    environment: request.headers.get('x-app-environment')?.trim() || 'development',
  };
}

export async function setAdminCookie(token: string) {
  const store = await cookies();
  store.set(ADMIN_COOKIE, token, {
    httpOnly: true,
    sameSite: 'lax',
    path: '/',
    secure: process.env.NODE_ENV === 'production',
    maxAge: Math.floor(ADMIN_SESSION_TTL_MS / 1000),
  });
}

export async function clearAdminCookie() {
  const store = await cookies();
  store.delete(ADMIN_COOKIE);
}
