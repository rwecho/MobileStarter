import { NextRequest } from 'next/server';
import { getClientContext } from '@/server/client-context';
import { getRuntimeConfig } from '@/server/database';
import { handleError, ok } from '@/server/http';

export function GET(request: NextRequest) {
  try {
    const client = getClientContext(request);
    const support = getRuntimeConfig(client.appId, client.environment).support;
    return ok({
      enabled: support.enabled,
      market: support.market,
      dataRegion: support.dataRegion,
      categories: support.categories,
    });
  } catch (error) {
    return handleError(error);
  }
}
