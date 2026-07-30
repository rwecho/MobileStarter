import { NextRequest } from 'next/server';
import { z } from 'zod';
import { setAdminCookie } from '@/server/admin-auth';
import { createSession, verifyAdminCredentials } from '@/server/admin-identity';
import { ApiError, handleError, ok } from '@/server/http';

const schema = z.object({
  identifier: z.string().trim().min(1, '请输入账号'),
  password: z.string().min(1, '请输入密码'),
});

export async function POST(request: NextRequest) {
  try {
    const input = schema.parse(await request.json());
    const admin = await verifyAdminCredentials(input.identifier, input.password);
    if (!admin) throw new ApiError(401, 'INVALID_CREDENTIALS', '账号或密码错误');
    const { token } = createSession(admin.id);
    await setAdminCookie(token);
    return ok(admin);
  } catch (error) {
    return handleError(error);
  }
}
