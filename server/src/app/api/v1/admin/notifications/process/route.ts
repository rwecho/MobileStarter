import { NextRequest } from 'next/server';
import { authorizeAdmin } from '@/app/api/v1/admin/config/route';
import { handleError, ok } from '@/server/http';
import { processNotificationJobs } from '@/server/notification-jobs';

export async function POST(request: NextRequest) {
  try {
    authorizeAdmin(request);
    return ok(await processNotificationJobs());
  } catch (error) {
    return handleError(error);
  }
}
