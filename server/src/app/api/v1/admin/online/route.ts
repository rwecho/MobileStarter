import { NextRequest } from 'next/server';
import { adminContext } from '@/server/admin-auth';
import { handleError, ok } from '@/server/http';
import { getOnlineStats } from '@/server/session-repository';

export function GET(request: NextRequest) {
  try {
    const { scope } = adminContext(request);
    return ok(getOnlineStats(scope));
  } catch (error) {
    return handleError(error);
  }
}
