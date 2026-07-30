import { NextRequest } from 'next/server';
import { authorizeAdmin, readAdminScope } from '@/server/admin-auth';
import { handleError, ok } from '@/server/http';
import { getOverview } from '@/server/metrics-repository';

export function GET(request: NextRequest) {
  try {
    authorizeAdmin(request);
    const scope = readAdminScope(request);
    return ok(getOverview(scope));
  } catch (error) {
    return handleError(error);
  }
}
