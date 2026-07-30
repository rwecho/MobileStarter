import { NextRequest } from 'next/server';
import { authorizeAdmin } from '@/server/admin-auth';
import { getClientContext } from '@/server/client-context';
import { handleError, ok } from '@/server/http';
import { enqueueNotification } from '@/server/notification-jobs';
import { notificationJobSchema } from '@/server/schemas';

export async function POST(request: NextRequest) {
  try {
    authorizeAdmin(request);
    const client = getClientContext(request);
    const input = notificationJobSchema.parse(await request.json());
    return ok(enqueueNotification({
      appId: client.appId,
      environment: client.environment,
      type: input.type,
      title: input.title,
      body: input.body,
      route: input.route ?? null,
    }), 202);
  } catch (error) {
    return handleError(error);
  }
}
