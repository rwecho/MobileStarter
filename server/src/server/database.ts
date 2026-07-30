import fs from 'node:fs';
import path from 'node:path';
import { randomUUID } from 'node:crypto';
import { DatabaseSync } from 'node:sqlite';
import { defaultConfig } from '@/domain/config';
import type { RuntimeConfig } from '@/domain/config';
import { hashPassword } from './passwords';
import { initializeCoreSchema } from './database-schema-core';
import { initializeProductSchema } from './database-schema-product';

const databasePath = process.env.MOBILEUI_DATABASE_PATH
  ?? path.join(process.cwd(), 'data', 'mobileui.db');

fs.mkdirSync(path.dirname(databasePath), { recursive: true });

export const database = new DatabaseSync(databasePath);
database.exec('PRAGMA busy_timeout = 10000');
database.exec('PRAGMA foreign_keys = ON');
initializeCoreSchema(database);
initializeProductSchema(database);
ensureUserColumns();
ensureAdminSessionAppId();

const insertConfig = database.prepare(`
  INSERT OR IGNORE INTO runtime_config(app_id, version, document, updated_at)
  VALUES (?, ?, ?, ?)
`);
insertConfig.run('mobileui', defaultConfig.version, JSON.stringify(defaultConfig), nowIso());
database.prepare(`
  INSERT OR IGNORE INTO runtime_configs(app_id, environment, version, document, updated_at)
  VALUES (?, 'development', ?, ?, ?)
`).run('mobileui', defaultConfig.version, JSON.stringify(defaultConfig), nowIso());
database.prepare(`
  INSERT OR IGNORE INTO config_revisions(
    id, app_id, environment, version, document, action, actor, created_at
  ) VALUES (?, 'mobileui', 'development', ?, ?, 'seed', 'system', ?)
`).run(randomUUID(), defaultConfig.version, JSON.stringify(defaultConfig), nowIso());

if (process.env.NODE_ENV !== 'production') {
  await ensureDevelopmentTestAccount();
}
await ensureBootstrapAdmin();

export function nowIso() {
  return new Date().toISOString();
}

async function ensureDevelopmentTestAccount() {
  const email = 'test@mobileui.local';
  const exists = database.prepare(
    'SELECT id FROM users WHERE app_id = ? AND email = ?',
  ).get('mobileui', email) as { id: string } | undefined;
  if (exists) {
    if (exists.id === 'development-test-account') {
      database.prepare('UPDATE users SET username = ? WHERE id = ?')
        .run('test', exists.id);
    }
    return;
  }
  const createdAt = nowIso();
  const passwordHash = await hashPassword('test123');
  database.prepare(`
    INSERT INTO users(
      id, app_id, email, password_hash, username, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?)
  `).run(
    'development-test-account', 'mobileui', email, passwordHash, 'test',
    createdAt, createdAt,
  );
}

async function ensureBootstrapAdmin() {
  const envUsername = process.env.MOBILEUI_BOOTSTRAP_ADMIN_USERNAME;
  if (envUsername) {
    const exists = database.prepare(
      'SELECT 1 FROM admin_users WHERE username = ?',
    ).get(envUsername);
    if (!exists) {
      const password = process.env.MOBILEUI_BOOTSTRAP_ADMIN_PASSWORD;
      const email = process.env.MOBILEUI_BOOTSTRAP_ADMIN_EMAIL
        ?? `${envUsername}@mobileui.local`;
      if (password) await seedAdmin(envUsername, email, password);
    }
    return;
  }
  if (process.env.NODE_ENV !== 'production') {
    const exists = database.prepare(
      'SELECT 1 FROM admin_users WHERE username = ?',
    ).get('admin');
    if (!exists) await seedAdmin('admin', 'admin@mobileui.local', 'admin123');
  }
}

async function seedAdmin(username: string, email: string, password: string) {
  const id = randomUUID();
  const createdAt = nowIso();
  const passwordHash = await hashPassword(password);
  database.prepare(`
    INSERT INTO admin_users(id, username, email, password_hash, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?)
  `).run(id, username, email, passwordHash, createdAt, createdAt);
}

function ensureAdminSessionAppId() {
  const columns = database.prepare('PRAGMA table_info(admin_sessions)').all() as Array<{
    name: string;
  }>;
  if (!columns.some((column) => column.name === 'app_id')) {
    database.exec("ALTER TABLE admin_sessions ADD COLUMN app_id TEXT NOT NULL DEFAULT ''");
  }
}

function ensureUserColumns() {
  const columns = database.prepare('PRAGMA table_info(users)').all() as Array<{
    name: string;
  }>;
  const names = new Set(columns.map((column) => column.name));
  if (!names.has('display_name')) {
    database.exec('ALTER TABLE users ADD COLUMN display_name TEXT');
  }
  if (!names.has('bio')) {
    database.exec("ALTER TABLE users ADD COLUMN bio TEXT NOT NULL DEFAULT ''");
  }
  if (!names.has('email_verified')) {
    database.exec('ALTER TABLE users ADD COLUMN email_verified INTEGER NOT NULL DEFAULT 0');
  }
  if (!names.has('consent_version')) {
    database.exec('ALTER TABLE users ADD COLUMN consent_version TEXT');
  }
  if (!names.has('consented_at')) {
    database.exec('ALTER TABLE users ADD COLUMN consented_at TEXT');
  }
  database.exec(`
    UPDATE users SET display_name = username
    WHERE display_name IS NULL OR trim(display_name) = ''
  `);
}

export function runTransaction(action: () => void) {
  database.exec('BEGIN IMMEDIATE');
  try {
    action();
    database.exec('COMMIT');
  } catch (error) {
    if (database.isTransaction) database.exec('ROLLBACK');
    throw error;
  }
}

export function getRuntimeConfig(
  appId = 'mobileui',
  environment = 'development',
): RuntimeConfig {
  const current = database.prepare(`
    SELECT document FROM runtime_configs WHERE app_id = ? AND environment = ?
  `).get(appId, environment) as { document: string } | undefined;
  if (current) return upgradeConfig(current.document, appId, environment);
  const row = appId === 'mobileui' && environment === 'development'
    ? database.prepare(
      'SELECT document FROM runtime_config WHERE app_id = ?',
    ).get(appId) as { document: string } | undefined
    : undefined;
  if (!row) {
    seedConfigScope(appId, environment);
    return defaultConfig;
  }
  return upgradeConfig(row.document, appId, environment);
}

function seedConfigScope(appId: string, environment: string) {
  saveRuntimeConfig(defaultConfig, appId, environment);
  database.prepare(`
    INSERT OR IGNORE INTO config_revisions(
      id, app_id, environment, version, document, action, actor, created_at
    ) VALUES (?, ?, ?, ?, ?, 'seed', 'system', ?)
  `).run(
    randomUUID(), appId, environment, defaultConfig.version,
    JSON.stringify(defaultConfig), nowIso(),
  );
}

function upgradeConfig(document: string, appId: string, environment: string) {
  const parsed = JSON.parse(document) as Partial<RuntimeConfig>;
  if (!parsed.schemaVersion) {
    saveRuntimeConfig(defaultConfig, appId, environment);
    return defaultConfig;
  }
  if (!parsed.support || !parsed.telemetry) {
    const upgraded = {
      ...defaultConfig,
      ...parsed,
      telemetry: parsed.telemetry ?? defaultConfig.telemetry,
      support: parsed.support ?? defaultConfig.support,
    } as RuntimeConfig;
    saveRuntimeConfig(upgraded, appId, environment);
    return upgraded;
  }
  return parsed as RuntimeConfig;
}

export function saveRuntimeConfig(
  config: RuntimeConfig,
  appId = 'mobileui',
  environment = 'development',
) {
  database.prepare(`
    INSERT INTO runtime_configs(app_id, environment, version, document, updated_at)
    VALUES (?, ?, ?, ?, ?)
    ON CONFLICT(app_id, environment) DO UPDATE SET
      version = excluded.version, document = excluded.document,
      updated_at = excluded.updated_at
  `).run(appId, environment, config.version, JSON.stringify(config), nowIso());
  if (appId === 'mobileui' && environment === 'development') {
    database.prepare(`
      INSERT INTO runtime_config(app_id, version, document, updated_at)
      VALUES (?, ?, ?, ?)
      ON CONFLICT(app_id) DO UPDATE SET
        version = excluded.version, document = excluded.document,
        updated_at = excluded.updated_at
    `).run(appId, config.version, JSON.stringify(config), nowIso());
  }
}

export function getConfigDraft(appId: string, environment: string) {
  const row = database.prepare(`
    SELECT document FROM config_drafts WHERE app_id = ? AND environment = ?
  `).get(appId, environment) as { document: string } | undefined;
  return row ? JSON.parse(row.document) as RuntimeConfig : null;
}

export function saveConfigDraft(
  config: RuntimeConfig,
  appId: string,
  environment: string,
) {
  database.prepare(`
    INSERT INTO config_drafts(app_id, environment, document, updated_at)
    VALUES (?, ?, ?, ?)
    ON CONFLICT(app_id, environment) DO UPDATE SET
      document = excluded.document, updated_at = excluded.updated_at
  `).run(appId, environment, JSON.stringify(config), nowIso());
}
