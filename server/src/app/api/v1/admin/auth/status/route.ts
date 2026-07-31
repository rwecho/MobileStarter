import { NextRequest } from 'next/server';
import { adminExists, getAdminFromRequest } from '@/server/admin-identity';
import { listAppIds } from '@/server/tenant-repository';
import { handleError, ok } from '@/server/http';

export function GET(request: NextRequest) {
  try {
    const session = getAdminFromRequest(request);
    return ok({
      adminExists: adminExists(),
      admin: session ? { ...session.admin, appId: session.appId } : null,
      appIds: listAppIds(),
    });
  } catch (error) {
    return handleError(error);
  }
}
