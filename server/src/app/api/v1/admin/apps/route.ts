import { NextRequest } from 'next/server';
import { authorizeAdmin } from '@/server/admin-auth';
import { handleError, ok } from '@/server/http';
import { listApps } from '@/server/tenant-repository';

export function GET(request: NextRequest) {
  try {
    const { appId } = authorizeAdmin(request);
    return ok({ apps: listApps().filter((app) => app.appId === appId) });
  } catch (error) {
    return handleError(error);
  }
}
