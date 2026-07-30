import type { SQLInputValue } from 'node:sqlite';
import { database, getRuntimeConfig } from './database';
import { sinceIso } from './time';
import {
  countOnlineSessions,
  countOnlineUsers,
} from './session-repository';
import type { AdminScope } from './admin-auth';

const DAY_MINUTES = 24 * 60;

export type Overview = Readonly<{
  configVersion: number;
  users: number;
  activeSessions: number;
  onlineSessions: number;
  onlineUsers: number;
  events24h: number;
  activeUsers24h: number;
  notifications: number;
  lastEventAt: string | null;
}>;

export function getOverview(scope: AdminScope): Overview {
  const since = sinceIso(DAY_MINUTES);
  return {
    configVersion: getRuntimeConfig(scope.appId, scope.environment).version,
    users: count(
      'SELECT COUNT(*) AS c FROM users WHERE app_id = ?',
      scope.appId,
    ),
    activeSessions: count(
      `SELECT COUNT(*) AS c FROM sessions s JOIN users u ON u.id = s.user_id
       WHERE u.app_id = ? AND s.revoked_at IS NULL AND s.expires_at > ?`,
      scope.appId,
      sinceIso(0),
    ),
    onlineSessions: countOnlineSessions(scope.appId),
    onlineUsers: countOnlineUsers(scope.appId),
    events24h: count(
      'SELECT COUNT(*) AS c FROM telemetry_events WHERE app_id = ? AND received_at >= ?',
      scope.appId,
      since,
    ),
    activeUsers24h: count(
      `SELECT COUNT(DISTINCT COALESCE(user_id, anonymous_id)) AS c
       FROM telemetry_events WHERE app_id = ? AND received_at >= ?`,
      scope.appId,
      since,
    ),
    notifications: count(
      `SELECT COUNT(*) AS c FROM notifications n JOIN users u ON u.id = n.user_id
       WHERE u.app_id = ?`,
      scope.appId,
    ),
    lastEventAt: latestEvent(scope.appId),
  };
}

function latestEvent(appId: string): string | null {
  const row = database.prepare(
    'SELECT received_at AS at FROM telemetry_events WHERE app_id = ? ORDER BY received_at DESC LIMIT 1',
  ).get(appId) as { at: string } | undefined;
  return row?.at ?? null;
}

function count(sql: string, ...params: SQLInputValue[]) {
  return (database.prepare(sql).get(...params) as { c: number }).c;
}
