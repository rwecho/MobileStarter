import type { SQLInputValue } from 'node:sqlite';
import { database } from './database';
import { nowIso, sinceIso } from './time';
import type { AdminScope } from './admin-auth';

export const ONLINE_WINDOW_MINUTES = 5;
const DAY_MINUTES = 24 * 60;

export type OnlineSession = Readonly<{
  id: string;
  userId: string;
  username: string | null;
  deviceName: string;
  lastSeenAt: string;
  createdAt: string;
  expiresAt: string;
}>;

export type HourBucket = Readonly<{ bucket: string; count: number }>;

export type OnlineStats = Readonly<{
  onlineSessions: number;
  onlineUsers: number;
  activeSessions: number;
  totalSessions: number;
  series: readonly HourBucket[];
  sessions: readonly OnlineSession[];
}>;

export function countOnlineSessions(appId: string) {
  return scalar(
    `SELECT COUNT(*) AS c FROM sessions s
     JOIN users u ON u.id = s.user_id
     WHERE u.app_id = ? AND s.revoked_at IS NULL
       AND s.expires_at > ? AND s.last_seen_at >= ?`,
    appId,
    nowIso(),
    sinceIso(ONLINE_WINDOW_MINUTES),
  );
}

export function countOnlineUsers(appId: string) {
  return scalar(
    `SELECT COUNT(DISTINCT s.user_id) AS c FROM sessions s
     JOIN users u ON u.id = s.user_id
     WHERE u.app_id = ? AND s.revoked_at IS NULL
       AND s.expires_at > ? AND s.last_seen_at >= ?`,
    appId,
    nowIso(),
    sinceIso(ONLINE_WINDOW_MINUTES),
  );
}

export function getOnlineStats(scope: AdminScope): OnlineStats {
  const now = nowIso();
  const onlineCutoff = sinceIso(ONLINE_WINDOW_MINUTES);
  const dayCutoff = sinceIso(DAY_MINUTES);
  return {
    onlineSessions: countOnlineSessions(scope.appId),
    onlineUsers: countOnlineUsers(scope.appId),
    activeSessions: scalar(
      `SELECT COUNT(*) AS c FROM sessions s JOIN users u ON u.id = s.user_id
       WHERE u.app_id = ? AND s.revoked_at IS NULL AND s.expires_at > ?`,
      scope.appId,
      now,
    ),
    totalSessions: scalar(
      `SELECT COUNT(*) AS c FROM sessions s JOIN users u ON u.id = s.user_id
       WHERE u.app_id = ?`,
      scope.appId,
    ),
    series: series(scope.appId, dayCutoff),
    sessions: listOnline(scope.appId, now, onlineCutoff),
  };
}

function listOnline(appId: string, now: string, cutoff: string): OnlineSession[] {
  return database.prepare(`
    SELECT s.id, s.user_id AS userId, u.username, s.device_name AS deviceName,
      s.last_seen_at AS lastSeenAt, s.created_at AS createdAt,
      s.expires_at AS expiresAt
    FROM sessions s JOIN users u ON u.id = s.user_id
    WHERE u.app_id = ? AND s.revoked_at IS NULL
      AND s.expires_at > ? AND s.last_seen_at >= ?
    ORDER BY s.last_seen_at DESC LIMIT 100
  `).all(appId, now, cutoff) as OnlineSession[];
}

function series(appId: string, since: string): HourBucket[] {
  return database.prepare(`
    SELECT substr(last_seen_at, 1, 13) AS bucket, COUNT(*) AS count
    FROM sessions s JOIN users u ON u.id = s.user_id
    WHERE u.app_id = ? AND s.last_seen_at >= ?
    GROUP BY bucket ORDER BY bucket
  `).all(appId, since) as HourBucket[];
}

function scalar(sql: string, ...params: SQLInputValue[]) {
  return (database.prepare(sql).get(...params) as { c: number }).c;
}
