import { RuntimeConfig } from '@/domain/config';
import { createId } from './ids';
import {
  database,
  getConfigDraft,
  getRuntimeConfig,
  nowIso,
  saveRuntimeConfig,
} from './database';
import { ApiError } from './http';

export type ConfigScope = Readonly<{ appId: string; environment: string }>;

export function publishDraft(scope: ConfigScope, actor: string) {
  const draft = getConfigDraft(scope.appId, scope.environment);
  if (!draft) throw new ApiError(409, 'DRAFT_REQUIRED', '请先保存配置草稿');
  const current = getRuntimeConfig(scope.appId, scope.environment);
  const published = { ...draft, version: current.version + 1 };
  commitRevision(scope, current.version, published, 'publish', actor, {});
  database.prepare(
    'DELETE FROM config_drafts WHERE app_id = ? AND environment = ?',
  ).run(scope.appId, scope.environment);
  return published;
}

export function rollbackConfig(scope: ConfigScope, version: number, actor: string) {
  const row = database.prepare(`
    SELECT document FROM config_revisions
    WHERE app_id = ? AND environment = ? AND version = ?
  `).get(scope.appId, scope.environment, version) as { document: string } | undefined;
  if (!row) throw new ApiError(404, 'REVISION_NOT_FOUND', '配置版本不存在');
  const current = getRuntimeConfig(scope.appId, scope.environment);
  const restored = {
    ...JSON.parse(row.document) as RuntimeConfig,
    version: current.version + 1,
  };
  commitRevision(scope, current.version, restored, 'rollback', actor, {
    restoredFromVersion: version,
  });
  return restored;
}

export function listConfigRevisions(scope: ConfigScope) {
  return database.prepare(`
    SELECT version, action, actor, created_at AS createdAt
    FROM config_revisions WHERE app_id = ? AND environment = ?
    ORDER BY version DESC LIMIT 100
  `).all(scope.appId, scope.environment);
}

export function listConfigAudit(scope: ConfigScope) {
  return database.prepare(`
    SELECT id, action, actor, from_version AS fromVersion,
      to_version AS toVersion, metadata, created_at AS createdAt
    FROM config_audit WHERE app_id = ? AND environment = ?
    ORDER BY created_at DESC LIMIT 100
  `).all(scope.appId, scope.environment).map((row) => {
    const item = row as Record<string, unknown>;
    return { ...item, metadata: JSON.parse(item.metadata as string) };
  });
}

function commitRevision(
  scope: ConfigScope,
  fromVersion: number,
  config: RuntimeConfig,
  action: 'publish' | 'rollback',
  actor: string,
  metadata: Record<string, unknown>,
) {
  database.exec('BEGIN IMMEDIATE');
  try {
    saveRuntimeConfig(config, scope.appId, scope.environment);
    database.prepare(`
      INSERT INTO config_revisions(
        id, app_id, environment, version, document, action, actor, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      createId(), scope.appId, scope.environment, config.version,
      JSON.stringify(config), action, actor, nowIso(),
    );
    database.prepare(`
      INSERT INTO config_audit(
        id, app_id, environment, action, actor, from_version,
        to_version, metadata, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      createId(), scope.appId, scope.environment, action, actor,
      fromVersion, config.version, JSON.stringify(metadata), nowIso(),
    );
    database.exec('COMMIT');
  } catch (error) {
    if (database.isTransaction) database.exec('ROLLBACK');
    throw error;
  }
}
