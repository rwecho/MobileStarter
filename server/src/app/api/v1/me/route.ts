import { NextRequest } from 'next/server';
import { requireAuth, toPublicUser } from '@/server/auth';
import { handleError, ok } from '@/server/http';

export function GET(request: NextRequest) {
  try {
    return ok(toPublicUser(requireAuth(request).user));
  } catch (error) {
    return handleError(error);
  }
}

