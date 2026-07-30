import { DatabaseSync } from 'node:sqlite';

export function initializeCoreSchema(database: DatabaseSync) {
  database.exec(`
    CREATE TABLE IF NOT EXISTS runtime_config (
      app_id TEXT PRIMARY KEY, version INTEGER NOT NULL,
      document TEXT NOT NULL, updated_at TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS runtime_configs (
      app_id TEXT NOT NULL, environment TEXT NOT NULL,
      version INTEGER NOT NULL, document TEXT NOT NULL,
      updated_at TEXT NOT NULL, PRIMARY KEY(app_id, environment)
    );
    CREATE TABLE IF NOT EXISTS config_drafts (
      app_id TEXT NOT NULL, environment TEXT NOT NULL,
      document TEXT NOT NULL, updated_at TEXT NOT NULL,
      PRIMARY KEY(app_id, environment)
    );
    CREATE TABLE IF NOT EXISTS config_revisions (
      id TEXT PRIMARY KEY, app_id TEXT NOT NULL, environment TEXT NOT NULL,
      version INTEGER NOT NULL, document TEXT NOT NULL, action TEXT NOT NULL,
      actor TEXT NOT NULL, created_at TEXT NOT NULL,
      UNIQUE(app_id, environment, version)
    );
    CREATE TABLE IF NOT EXISTS config_audit (
      id TEXT PRIMARY KEY, app_id TEXT NOT NULL, environment TEXT NOT NULL,
      action TEXT NOT NULL, actor TEXT NOT NULL, from_version INTEGER,
      to_version INTEGER, metadata TEXT NOT NULL, created_at TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY, app_id TEXT NOT NULL, email TEXT NOT NULL,
      password_hash TEXT NOT NULL, username TEXT NOT NULL, display_name TEXT,
      bio TEXT NOT NULL DEFAULT '', avatar_url TEXT,
      tier_id TEXT NOT NULL DEFAULT 'free', settings TEXT NOT NULL DEFAULT '{}',
      created_at TEXT NOT NULL, updated_at TEXT NOT NULL, UNIQUE(app_id, email)
    );
    CREATE TABLE IF NOT EXISTS external_identities (
      id TEXT PRIMARY KEY, user_id TEXT NOT NULL, provider TEXT NOT NULL,
      provider_subject TEXT NOT NULL, email TEXT, created_at TEXT NOT NULL,
      UNIQUE(provider, provider_subject),
      FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
    );
    CREATE TABLE IF NOT EXISTS sessions (
      id TEXT PRIMARY KEY, user_id TEXT NOT NULL,
      token_hash TEXT NOT NULL UNIQUE, device_name TEXT NOT NULL,
      created_at TEXT NOT NULL, last_seen_at TEXT NOT NULL,
      expires_at TEXT NOT NULL, revoked_at TEXT,
      FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
    );
    CREATE TABLE IF NOT EXISTS password_reset_challenges (
      id TEXT PRIMARY KEY, app_id TEXT NOT NULL, user_id TEXT NOT NULL,
      email TEXT NOT NULL, code_hash TEXT NOT NULL,
      attempts INTEGER NOT NULL DEFAULT 0, expires_at TEXT NOT NULL,
      used_at TEXT, created_at TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS password_reset_tokens (
      id TEXT PRIMARY KEY, app_id TEXT NOT NULL, user_id TEXT NOT NULL,
      token_hash TEXT NOT NULL UNIQUE, expires_at TEXT NOT NULL,
      used_at TEXT, created_at TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS phone_auth_challenges (
      id TEXT PRIMARY KEY, app_id TEXT NOT NULL, phone TEXT NOT NULL,
      code_hash TEXT NOT NULL, attempts INTEGER NOT NULL DEFAULT 0,
      expires_at TEXT NOT NULL, used_at TEXT, created_at TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS outbound_messages (
      id TEXT PRIMARY KEY, app_id TEXT NOT NULL, channel TEXT NOT NULL,
      recipient TEXT NOT NULL, template TEXT NOT NULL, payload TEXT NOT NULL,
      status TEXT NOT NULL, error_code TEXT, created_at TEXT NOT NULL, sent_at TEXT
    );
    CREATE INDEX IF NOT EXISTS idx_reset_challenge_lookup
      ON password_reset_challenges(app_id, email, created_at);
    CREATE INDEX IF NOT EXISTS idx_phone_challenge_lookup
      ON phone_auth_challenges(app_id, phone, created_at);
  `);
}
