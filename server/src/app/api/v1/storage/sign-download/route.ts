import { NextRequest } from 'next/server';
import { requireAuth } from '@/server/auth';
import { getClientContext } from '@/server/client-context';
import { handleError, ok } from '@/server/http';
import { signDownload } from '@/server/storage';

// Resolves a stored object reference (objectKey, as returned by sign-upload)
// into a fresh download URL — a direct public/CDN URL if S3_PUBLIC_BASE is
// configured, otherwise a short-lived presigned GET URL.
export async function GET(request: NextRequest) {
  try {
    await requireAuth(request);
    const client = getClientContext(request);
    const objectKey = request.nextUrl.searchParams.get('key');
    if (!objectKey) {
      return handleError(new Error('缺少 key 参数'));
    }
    const result = await signDownload({ appId: client.appId, objectKey });
    return ok(result);
  } catch (error) {
    return handleError(error);
  }
}
