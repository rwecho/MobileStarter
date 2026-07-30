import { NextRequest } from 'next/server';
import { requireAuth, revokeSession } from '@/server/auth';
import { handleError, ok } from '@/server/http';

export function POST(request: NextRequest) {
  try {
    const { session } = requireAuth(request);
    revokeSession(session.id);
    return ok({ signedOut: true });
  } catch (error) {
    return handleError(error);
  }
}

