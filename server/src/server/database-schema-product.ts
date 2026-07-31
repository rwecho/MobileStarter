import type { PostgresDatabase } from './postgres-database';

export async function initializeProductSchema(database: PostgresDatabase) {
  await database.exec(`
    CREATE TABLE IF NOT EXISTS notifications (
      id TEXT PRIMARY KEY, user_id TEXT NOT NULL, type TEXT NOT NULL,
      title TEXT NOT NULL, body TEXT NOT NULL, route TEXT, read_at TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
    );
    CREATE TABLE IF NOT EXISTS push_devices (
      id TEXT PRIMARY KEY, app_id TEXT NOT NULL, environment TEXT NOT NULL,
      user_id TEXT NOT NULL, installation_id TEXT NOT NULL, platform TEXT NOT NULL,
      provider TEXT NOT NULL, push_token TEXT NOT NULL, locale TEXT NOT NULL,
      timezone TEXT NOT NULL, app_version TEXT NOT NULL,
      enabled INTEGER NOT NULL DEFAULT 1, created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL, UNIQUE(app_id, environment, provider, push_token),
      UNIQUE(app_id, environment, user_id, installation_id),
      FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
    );
    CREATE TABLE IF NOT EXISTS notification_jobs (
      id TEXT PRIMARY KEY, app_id TEXT NOT NULL, environment TEXT NOT NULL,
      type TEXT NOT NULL, title TEXT NOT NULL, body TEXT NOT NULL, route TEXT,
      status TEXT NOT NULL, created_at TEXT NOT NULL, started_at TEXT,
      completed_at TEXT
    );
    CREATE TABLE IF NOT EXISTS notification_deliveries (
      id TEXT PRIMARY KEY, job_id TEXT NOT NULL, device_id TEXT NOT NULL,
      status TEXT NOT NULL, attempts INTEGER NOT NULL DEFAULT 0,
      provider_message_id TEXT, error_code TEXT, next_attempt_at TEXT,
      updated_at TEXT NOT NULL, UNIQUE(job_id, device_id),
      FOREIGN KEY(job_id) REFERENCES notification_jobs(id) ON DELETE CASCADE,
      FOREIGN KEY(device_id) REFERENCES push_devices(id) ON DELETE CASCADE
    );
    CREATE TABLE IF NOT EXISTS orders (
      id TEXT PRIMARY KEY, user_id TEXT NOT NULL, plan_id TEXT NOT NULL,
      idempotency_key TEXT NOT NULL, status TEXT NOT NULL,
      amount_minor INTEGER NOT NULL, currency TEXT NOT NULL, provider TEXT NOT NULL,
      created_at TEXT NOT NULL, completed_at TEXT, UNIQUE(user_id, idempotency_key),
      FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
    );
    CREATE TABLE IF NOT EXISTS referral_profiles (
      user_id TEXT PRIMARY KEY, code TEXT NOT NULL UNIQUE, created_at TEXT NOT NULL,
      FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
    );
    CREATE TABLE IF NOT EXISTS coupons (
      id TEXT PRIMARY KEY, user_id TEXT NOT NULL, code TEXT NOT NULL,
      title TEXT NOT NULL, discount_label TEXT NOT NULL, expires_at TEXT,
      used_at TEXT, created_at TEXT NOT NULL, UNIQUE(user_id, code),
      FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
    );
    CREATE TABLE IF NOT EXISTS telemetry_events (
      event_id TEXT NOT NULL, app_id TEXT NOT NULL, user_id TEXT,
      anonymous_id TEXT NOT NULL, session_id TEXT NOT NULL, name TEXT NOT NULL,
      screen_id TEXT, occurred_at TEXT NOT NULL, platform TEXT NOT NULL,
      app_version TEXT NOT NULL, config_version INTEGER NOT NULL,
      properties TEXT NOT NULL, received_at TEXT NOT NULL,
      PRIMARY KEY(app_id, event_id)
    );
    CREATE TABLE IF NOT EXISTS support_tickets (
      id TEXT PRIMARY KEY, app_id TEXT NOT NULL, user_id TEXT,
      installation_id TEXT, locale TEXT NOT NULL, market TEXT NOT NULL,
      data_region TEXT NOT NULL, queue_id TEXT NOT NULL, category TEXT NOT NULL,
      severity TEXT NOT NULL, subject TEXT NOT NULL, status TEXT NOT NULL,
      created_at TEXT NOT NULL, updated_at TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS support_messages (
      id TEXT PRIMARY KEY, ticket_id TEXT NOT NULL, author_type TEXT NOT NULL,
      body TEXT NOT NULL, created_at TEXT NOT NULL,
      FOREIGN KEY(ticket_id) REFERENCES support_tickets(id) ON DELETE CASCADE
    );
    CREATE TABLE IF NOT EXISTS product_feedback (
      id TEXT PRIMARY KEY, app_id TEXT NOT NULL, user_id TEXT,
      installation_id TEXT, locale TEXT NOT NULL, market TEXT NOT NULL,
      data_region TEXT NOT NULL, queue_id TEXT NOT NULL, category TEXT NOT NULL,
      title TEXT NOT NULL, body TEXT NOT NULL, rating INTEGER,
      status TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS feedback_attachments (
      id TEXT PRIMARY KEY, feedback_id TEXT NOT NULL, file_name TEXT NOT NULL,
      mime_type TEXT NOT NULL, content TEXT NOT NULL, created_at TEXT NOT NULL,
      FOREIGN KEY(feedback_id) REFERENCES product_feedback(id) ON DELETE CASCADE
    );
    CREATE INDEX IF NOT EXISTS idx_support_ticket_owner
      ON support_tickets(app_id, user_id, installation_id, updated_at);
    CREATE INDEX IF NOT EXISTS idx_feedback_owner
      ON product_feedback(app_id, user_id, installation_id, updated_at);
  `);
}
