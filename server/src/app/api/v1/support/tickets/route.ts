import { NextRequest } from 'next/server';
import { database, nowIso, runTransaction } from '@/server/database';
import { handleError, ok } from '@/server/http';
import { createId } from '@/server/ids';
import { supportTicketSchema } from '@/server/schemas';
import {
  getSupportIdentity,
  resolveSupportRoute,
  ticketView,
} from '@/server/support';

export function GET(request: NextRequest) {
  try {
    const identity = getSupportIdentity(request);
    const route = resolveSupportRoute(request, 'technical');
    const rows = database.prepare(`
      SELECT * FROM support_tickets WHERE app_id = ? AND (
        (? IS NOT NULL AND user_id = ?)
        OR (? IS NULL AND user_id IS NULL AND installation_id = ?)
      ) ORDER BY updated_at DESC LIMIT 50
    `).all(
      route.appId,
      identity.userId,
      identity.userId,
      identity.userId,
      identity.installationId,
    ) as Record<string, unknown>[];
    return ok(rows.map(ticketView));
  } catch (error) {
    return handleError(error);
  }
}

export async function POST(request: NextRequest) {
  try {
    const identity = getSupportIdentity(request);
    const input = supportTicketSchema.parse(await request.json());
    const route = resolveSupportRoute(request, input.category);
    const id = createId();
    const messageId = createId();
    const now = nowIso();
    runTransaction(() => {
      database.prepare(`
        INSERT INTO support_tickets(
          id, app_id, user_id, installation_id, locale, market, data_region,
          queue_id, category, severity, subject, status, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'submitted', ?, ?)
      `).run(
        id, route.appId, identity.userId, identity.installationId || null,
        route.locale, route.market, route.dataRegion, route.queueId,
        input.category, input.severity, input.subject, now, now,
      );
      database.prepare(`
        INSERT INTO support_messages(id, ticket_id, author_type, body, created_at)
        VALUES (?, ?, 'user', ?, ?)
      `).run(messageId, id, input.message, now);
    });
    const row = database.prepare('SELECT * FROM support_tickets WHERE id = ?').get(id);
    return ok(ticketView(row as Record<string, unknown>), 201);
  } catch (error) {
    return handleError(error);
  }
}
