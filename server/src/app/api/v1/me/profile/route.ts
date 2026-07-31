import { NextRequest } from 'next/server';
import { getUserRow, requireAuth, toPublicUser } from '@/server/auth';
import { database, nowIso } from '@/server/database';
import { handleError, ok } from '@/server/http';
import { profileSchema } from '@/server/schemas';

export async function PATCH(request: NextRequest) {
  try {
    const { user } = await requireAuth(request);
    const input = profileSchema.parse(await request.json());
    const displayName = input.displayName ?? user.display_name ?? user.username;
    const bio = input.bio ?? user.bio;
    const avatarUrl = input.avatarUrl === undefined ? user.avatar_url : input.avatarUrl;
    await database.prepare(`
      UPDATE users
      SET display_name = ?, bio = ?, avatar_url = ?, updated_at = ?
      WHERE id = ?
    `).run(displayName, bio, avatarUrl, nowIso(), user.id);
    return ok(toPublicUser(await getUserRow(user.id)));
  } catch (error) {
    return handleError(error);
  }
}

export const PUT = PATCH;
