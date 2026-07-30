import { NextRequest } from 'next/server';
import { requireAuth } from './auth';
import { getClientContext } from './client-context';
import { database, getRuntimeConfig } from './database';
import { ApiError } from './http';

export type SupportIdentity = Readonly<{
  userId: string | null;
  installationId: string;
}>;

export type SupportRoute = Readonly<{
  appId: string;
  locale: string;
  market: string;
  dataRegion: string;
  queueId: string;
}>;

export function getSupportIdentity(request: NextRequest): SupportIdentity {
  const installationId = request.headers.get('x-installation-id')?.trim() ?? '';
  if (request.headers.has('authorization')) {
    return { userId: requireAuth(request).user.id, installationId };
  }
  if (!/^[a-zA-Z0-9._-]{8,100}$/.test(installationId)) {
    throw new ApiError(400, 'INSTALLATION_ID_REQUIRED', '匿名反馈需要安装标识');
  }
  return { userId: null, installationId };
}

export function resolveSupportRoute(request: NextRequest, category: string): SupportRoute {
  const client = getClientContext(request);
  const config = getRuntimeConfig(client.appId, client.environment).support;
  if (!config.enabled) throw new ApiError(404, 'SUPPORT_DISABLED', '当前应用未启用客服');
  if (!config.categories.some((item) => item.id === category)) {
    throw new ApiError(400, 'CATEGORY_DISABLED', '当前应用未启用该问题分类');
  }
  const market = request.headers.get('x-market')?.trim() || config.market;
  const dataRegion = request.headers.get('x-data-region')?.trim() || config.dataRegion;
  const exact = config.queues.find((queue) =>
    queue.market === market
    && queue.locales.includes(client.locale)
    && queue.categories.includes(category));
  const fallback = config.queues.find((queue) =>
    queue.market === 'global' && queue.categories.includes(category));
  const queue = exact ?? fallback ?? config.queues[0];
  return {
    appId: client.appId,
    locale: client.locale,
    market,
    dataRegion,
    queueId: queue.id,
  };
}

export function getOwnedTicket(
  request: NextRequest,
  ticketId: string,
  identity = getSupportIdentity(request),
) {
  const appId = getClientContext(request).appId;
  const row = database.prepare(`
    SELECT id, app_id, user_id, installation_id, locale, market, data_region,
      queue_id, category, severity, subject, status, created_at, updated_at
    FROM support_tickets
    WHERE id = ? AND app_id = ? AND (
      (? IS NOT NULL AND user_id = ?)
      OR (? IS NULL AND user_id IS NULL AND installation_id = ?)
    )
  `).get(
    ticketId,
    appId,
    identity.userId,
    identity.userId,
    identity.userId,
    identity.installationId,
  );
  if (!row) throw new ApiError(404, 'TICKET_NOT_FOUND', '工单不存在');
  return row;
}

export function ticketView(row: Record<string, unknown>) {
  return {
    id: row.id,
    category: row.category,
    severity: row.severity,
    subject: row.subject,
    status: row.status,
    locale: row.locale,
    market: row.market,
    dataRegion: row.data_region,
    queueId: row.queue_id,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export function feedbackView(row: Record<string, unknown>) {
  return {
    id: row.id,
    category: row.category,
    title: row.title,
    body: row.body,
    rating: row.rating,
    status: row.status,
    market: row.market,
    dataRegion: row.data_region,
    queueId: row.queue_id,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}
