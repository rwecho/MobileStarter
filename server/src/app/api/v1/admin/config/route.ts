import { NextRequest } from 'next/server';
import { getConfigDraft, getRuntimeConfig, saveConfigDraft } from '@/server/database';
import { ApiError, handleError, ok } from '@/server/http';
import { runtimeConfigSchema } from '@/server/schemas';
import { getClientContext } from '@/server/client-context';

export function authorizeAdmin(request: NextRequest) {
  const expected = process.env.MOBILEUI_ADMIN_KEY ?? 'local-development-admin';
  if (request.headers.get('x-admin-key') !== expected) {
    throw new ApiError(401, 'ADMIN_UNAUTHORIZED', '管理员凭据无效');
  }
}

export function GET(request: NextRequest) {
  try {
    authorizeAdmin(request);
    const client = getClientContext(request);
    return ok({
      published: getRuntimeConfig(client.appId, client.environment),
      draft: getConfigDraft(client.appId, client.environment),
    });
  } catch (error) {
    return handleError(error);
  }
}

export async function PUT(request: NextRequest) {
  try {
    authorizeAdmin(request);
    const client = getClientContext(request);
    const candidate = runtimeConfigSchema.parse(await request.json());
    saveConfigDraft(candidate, client.appId, client.environment);
    return ok({ draft: candidate });
  } catch (error) {
    return handleError(error);
  }
}
