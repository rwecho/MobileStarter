import { NextRequest } from 'next/server';
import { authorizeAdmin, readAdminScope } from '@/server/admin-auth';
import { handleError, ok } from '@/server/http';
import { getOnlineStats } from '@/server/session-repository';

export function GET(request: NextRequest) {
  try {
    authorizeAdmin(request);
    const scope = readAdminScope(request);
    return ok(getOnlineStats(scope));
  } catch (error) {
    return handleError(error);
  }
}
