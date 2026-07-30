import { NextRequest } from 'next/server';
import { adminContext } from '@/server/admin-auth';
import { listConfigAudit, listConfigRevisions } from '@/server/config-control';
import { handleError, ok } from '@/server/http';

export function GET(request: NextRequest) {
  try {
    const { scope } = adminContext(request);
    return ok({ revisions: listConfigRevisions(scope), audit: listConfigAudit(scope) });
  } catch (error) {
    return handleError(error);
  }
}
