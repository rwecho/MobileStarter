import { NextRequest } from 'next/server';
import { getClientContext } from '@/server/client-context';
import { listConfigAudit, listConfigRevisions } from '@/server/config-control';
import { handleError, ok } from '@/server/http';
import { authorizeAdmin } from '@/server/admin-auth';

export function GET(request: NextRequest) {
  try {
    authorizeAdmin(request);
    const scope = getClientContext(request);
    return ok({ revisions: listConfigRevisions(scope), audit: listConfigAudit(scope) });
  } catch (error) {
    return handleError(error);
  }
}
