import { NextRequest } from 'next/server';
import { requireAuth, revokeAllSessions } from '@/server/auth';
import { handleError, ok } from '@/server/http';

export function POST(request: NextRequest) {
  try {
    const { user } = requireAuth(request);
    revokeAllSessions(user.id);
    return ok({ signedOut: true });
  } catch (error) {
    return handleError(error);
  }
}

