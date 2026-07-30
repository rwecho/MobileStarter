import type { SQLInputValue } from 'node:sqlite';
import { database } from './database';
import { sinceIso } from './time';
import type { AdminScope } from './admin-auth';

export type LogFilters = Readonly<{
  name?: string;
  platform?: string;
  sinceMinutes?: number;
  limit: number;
  offset: number;
}>;

export type LogRow = Readonly<{
  eventId: string;
  name: string;
  screenId: string | null;
  platform: string;
  appVersion: string;
  occurredAt: string;
  receivedAt: string;
  anonymousId: string;
  userId: string | null;
  properties: Record<string, unknown>;
}>;

export type LogTally = Readonly<{ key: string; count: number }>;
export type HourPoint = Readonly<{ bucket: string; count: number }>;

export type LogSummary = Readonly<{
  total: number;
  byName: readonly LogTally[];
  byPlatform: readonly LogTally[];
  series: readonly HourPoint[];
  names: readonly string[];
  platforms: readonly string[];
}>;

export function listLogs(scope: AdminScope, filters: LogFilters): LogRow[] {
  const { where, params } = buildWhere(scope, filters);
  const rows = database.prepare(`
    SELECT event_id AS eventId, name, screen_id AS screenId, platform,
      app_version AS appVersion, occurred_at AS occurredAt, received_at AS receivedAt,
      anonymous_id AS anonymousId, user_id AS userId, properties
    FROM telemetry_events ${where}
    ORDER BY received_at DESC LIMIT ? OFFSET ?
  `).all(...params, filters.limit, filters.offset) as Array<
    Omit<LogRow, 'properties'> & { properties: string }
  >;
  return rows.map((row) => ({ ...row, properties: parseJson(row.properties) }));
}

export function getLogSummary(scope: AdminScope, sinceMinutes: number): LogSummary {
  const since = sinceIso(sinceMinutes);
  const base = 'app_id = ? AND received_at >= ?';
  const byName = tally(
    `SELECT name AS key, COUNT(*) AS count FROM telemetry_events WHERE ${base} GROUP BY name ORDER BY count DESC LIMIT 8`,
    scope.appId,
    since,
  );
  const byPlatform = tally(
    `SELECT platform AS key, COUNT(*) AS count FROM telemetry_events WHERE ${base} GROUP BY platform ORDER BY count DESC`,
    scope.appId,
    since,
  );
  const series = database.prepare(`
    SELECT substr(received_at, 1, 13) AS bucket, COUNT(*) AS count
    FROM telemetry_events WHERE ${base}
    GROUP BY bucket ORDER BY bucket
  `).all(scope.appId, since) as HourPoint[];
  return {
    total: scalar(
      `SELECT COUNT(*) AS c FROM telemetry_events WHERE ${base}`,
      scope.appId,
      since,
    ),
    byName,
    byPlatform,
    series,
    names: byName.map((item) => item.key),
    platforms: byPlatform.map((item) => item.key),
  };
}

function buildWhere(scope: AdminScope, filters: LogFilters) {
  const clauses = ['app_id = ?'];
  const params: SQLInputValue[] = [scope.appId];
  if (filters.name) {
    clauses.push('name = ?');
    params.push(filters.name);
  }
  if (filters.platform) {
    clauses.push('platform = ?');
    params.push(filters.platform);
  }
  if (filters.sinceMinutes) {
    clauses.push('received_at >= ?');
    params.push(sinceIso(filters.sinceMinutes));
  }
  return { where: `WHERE ${clauses.join(' AND ')}`, params };
}

function tally(sql: string, ...params: SQLInputValue[]): LogTally[] {
  return database.prepare(sql).all(...params) as LogTally[];
}

function scalar(sql: string, ...params: SQLInputValue[]) {
  return (database.prepare(sql).get(...params) as { c: number }).c;
}

function parseJson(value: string) {
  try {
    return JSON.parse(value) as Record<string, unknown>;
  } catch {
    return { raw: value } as Record<string, unknown>;
  }
}
