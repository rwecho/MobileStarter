import { NextRequest } from 'next/server';
import { getConfigDraft, getRuntimeConfig, saveConfigDraft } from '@/server/database';
import { authorizeAdmin, readAdminScope } from '@/server/admin-auth';
import { handleError, ok } from '@/server/http';
import { runtimeConfigSchema } from '@/server/schemas';

export function GET(request: NextRequest) {
  try {
    authorizeAdmin(request);
    const scope = readAdminScope(request);
    return ok({
      published: getRuntimeConfig(scope.appId, scope.environment),
      draft: getConfigDraft(scope.appId, scope.environment),
    });
  } catch (error) {
    return handleError(error);
  }
}

export async function PUT(request: NextRequest) {
  try {
    authorizeAdmin(request);
    const scope = readAdminScope(request);
    const candidate = runtimeConfigSchema.parse(await request.json());
    saveConfigDraft(candidate, scope.appId, scope.environment);
    return ok({ draft: candidate });
  } catch (error) {
    return handleError(error);
  }
}
