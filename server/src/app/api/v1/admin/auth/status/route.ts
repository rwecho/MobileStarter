import { NextRequest } from 'next/server';
import { adminExists, getAdminFromRequest } from '@/server/admin-identity';
import { handleError, ok } from '@/server/http';

export function GET(request: NextRequest) {
  try {
    return ok({ adminExists: adminExists(), admin: getAdminFromRequest(request) });
  } catch (error) {
    return handleError(error);
  }
}
