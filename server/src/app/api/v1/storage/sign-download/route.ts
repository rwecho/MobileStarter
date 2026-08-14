import { NextRequest } from 'next/server';
import { requireAuth } from '@/server/auth';
import { ApiError, handleError, ok } from '@/server/http';
import { signDownload } from '@/server/storage';

// Resolves a stored object reference (objectKey, as returned by sign-upload)
// into a fresh download URL — a direct public/CDN URL if S3_PUBLIC_BASE is
// configured, otherwise a short-lived presigned GET URL.
//
// Security: the objectKey must belong to the caller's own app. In single-bucket
// mode the key is prefixed with `<appId>/`, so we check that prefix to prevent a
// user of app A from reading app B's private objects by guessing the key.
export async function GET(request: NextRequest) {
  try {
    const { user } = await requireAuth(request);
    const objectKey = request.nextUrl.searchParams.get('key');
    if (!objectKey) {
      return handleError(new Error('缺少 key 参数'));
    }
    const appPrefix = `${user.app_id.toLowerCase()}/`;
    if (!objectKey.toLowerCase().startsWith(appPrefix)) {
      return handleError(new ApiError(403, 'FORBIDDEN', '无权访问该对象', false));
    }
    const result = await signDownload({ appId: user.app_id, objectKey });
    return ok(result);
  } catch (error) {
    return handleError(error);
  }
}
