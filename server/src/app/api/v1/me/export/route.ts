import { NextRequest } from 'next/server';
import { requireAuth } from '@/server/auth';
import { exportAccountData } from '@/server/account-export';
import { handleError, ok } from '@/server/http';

export function GET(request: NextRequest) {
  try {
    const { user } = requireAuth(request);
    return ok(exportAccountData(user.id));
  } catch (error) {
    return handleError(error);
  }
}
