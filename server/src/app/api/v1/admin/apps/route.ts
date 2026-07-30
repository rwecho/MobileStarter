import { NextRequest } from 'next/server';
import { authorizeAdmin } from '@/server/admin-auth';
import { handleError, ok } from '@/server/http';
import { listApps } from '@/server/tenant-repository';

export function GET(request: NextRequest) {
  try {
    authorizeAdmin(request);
    return ok({ apps: listApps() });
  } catch (error) {
    return handleError(error);
  }
}
