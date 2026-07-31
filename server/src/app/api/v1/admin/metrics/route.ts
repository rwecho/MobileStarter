import { NextRequest } from 'next/server';
import { adminContext } from '@/server/admin-auth';
import { handleError, ok } from '@/server/http';
import { getOverview } from '@/server/metrics-repository';

export function GET(request: NextRequest) {
  try {
    const { scope } = adminContext(request);
    return ok(getOverview(scope));
  } catch (error) {
    return handleError(error);
  }
}
