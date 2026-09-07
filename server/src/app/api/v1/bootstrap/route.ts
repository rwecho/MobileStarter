import { NextRequest } from 'next/server';
import { requireAuth, toPublicUser } from '@/server/auth';
import { getRuntimeConfig } from '@/server/database';
import { handleError, ok } from '@/server/http';
import {
  configuredProviders,
  providerPolicy,
  publicProviderConfig,
} from '@/server/social-auth';
import { getClientContext } from '@/server/client-context';

export const dynamic = 'force-dynamic';

export async function GET(request: NextRequest) {
  try {
    const client = getClientContext(request);
    const config = await getRuntimeConfig(client.appId, client.environment);
    // 法务全文不进启动载荷（bootstrap 轻量化）：仅保留元数据（revision 供注册
    // 同意记录），正文由页面打开时经 GET /api/v1/public/legal 按需读取。
    const { legal: fullLegal, ...startupConfig } = config;
    const legal = fullLegal.map(({ content: _content, ...meta }) => meta);
    let user = null;
    try {
      user = toPublicUser((await requireAuth(request)).user);
    } catch {
      user = null;
    }
    return ok({
      config: { ...startupConfig, legal },
      user,
      authProviders: configuredProviders(config, client.platform),
      authProviderPolicy: providerPolicy(config, client.platform),
      authProviderConfig: publicProviderConfig(config, client.platform),
      client,
      serverTime: new Date().toISOString(),
      apiVersion: 'v1',
    });
  } catch (error) {
    return handleError(error);
  }
}
