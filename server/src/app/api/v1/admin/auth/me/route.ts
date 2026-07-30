import { NextRequest } from 'next/server';
import { getAdminFromRequest } from '@/server/admin-identity';
import { ApiError, handleError, ok } from '@/server/http';

export function GET(request: NextRequest) {
  try {
    const admin = getAdminFromRequest(request);
    if (!admin) throw new ApiError(401, 'UNAUTHENTICATED', '未登录');
    return ok(admin);
  } catch (error) {
    return handleError(error);
  }
}
