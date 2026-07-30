import { NextRequest } from 'next/server';
import { requireAuth, revokeAllSessions } from '@/server/auth';
import { database, nowIso } from '@/server/database';
import { ApiError, handleError, ok } from '@/server/http';
import { passwordSchema } from '@/server/schemas';
import { hashPassword, verifyPassword } from '@/server/passwords';

export async function POST(request: NextRequest) {
  try {
    const { user } = requireAuth(request);
    const input = passwordSchema.parse(await request.json());
    const valid = await verifyPassword(user.password_hash, input.currentPassword);
    if (!valid) throw new ApiError(403, 'CURRENT_PASSWORD_INVALID', '当前密码不正确');
    const nextHash = await hashPassword(input.newPassword);
    database.prepare(
      'UPDATE users SET password_hash = ?, updated_at = ? WHERE id = ?',
    ).run(nextHash, nowIso(), user.id);
    revokeAllSessions(user.id);
    return ok({ changed: true, requiresSignIn: true });
  } catch (error) {
    return handleError(error);
  }
}
