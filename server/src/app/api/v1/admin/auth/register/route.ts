import { NextRequest } from 'next/server';
import { z } from 'zod';
import { authorizeAdmin, setAdminCookie } from '@/server/admin-auth';
import { adminExists, createAdmin, createSession } from '@/server/admin-identity';
import { handleError, ok } from '@/server/http';

const schema = z.object({
  username: z.string().trim().min(3, '用户名至少 3 位').max(32),
  email: z.email('邮箱格式不正确'),
  password: z.string().min(8, '密码至少 8 位').max(128),
});

export async function POST(request: NextRequest) {
  try {
    const input = schema.parse(await request.json());
    const bootstrap = !adminExists();
    if (!bootstrap) authorizeAdmin(request); // only a signed-in admin may create new admins
    const profile = await createAdmin(input);
    if (bootstrap) {
      const { token } = createSession(profile.id);
      await setAdminCookie(token);
      return ok({ profile, autoLogin: true }, 201);
    }
    return ok({ profile, autoLogin: false });
  } catch (error) {
    return handleError(error);
  }
}
