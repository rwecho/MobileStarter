import { NextRequest } from 'next/server';
import { getClientContext } from '@/server/client-context';
import { publishDraft } from '@/server/config-control';
import { handleError, ok } from '@/server/http';
import { authorizeAdmin } from '@/server/admin-auth';

export function POST(request: NextRequest) {
  try {
    authorizeAdmin(request);
    const client = getClientContext(request);
    const config = publishDraft(client, request.headers.get('x-admin-actor') ?? 'admin');
    return ok(config);
  } catch (error) {
    return handleError(error);
  }
}
