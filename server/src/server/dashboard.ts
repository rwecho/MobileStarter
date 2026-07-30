import { database, getRuntimeConfig } from './database';

export function getDashboardMetrics() {
  const config = getRuntimeConfig();
  return [
    { label: '配置版本', value: `v${config.version}` },
    { label: '会员等级', value: String(config.tiers.length) },
    { label: '订阅方案', value: String(config.plans.length) },
    { label: '注册用户', value: countRows('users') },
    { label: '有效会话', value: countRows('sessions', 'revoked_at IS NULL') },
    { label: '通知记录', value: countRows('notifications') },
  ];
}

function countRows(table: string, where = '1 = 1') {
  const allowed = new Set(['users', 'sessions', 'notifications']);
  if (!allowed.has(table)) return '0';
  const row = database.prepare(
    `SELECT COUNT(*) AS count FROM ${table} WHERE ${where}`,
  ).get() as { count: number };
  return String(row.count);
}

