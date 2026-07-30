'use client';

import { useState } from 'react';

type LoadState = 'idle' | 'loading' | 'success' | 'error';
type ConfigEnvelope = Readonly<{
  published: Record<string, unknown>;
  draft: Record<string, unknown> | null;
}>;

export function ConfigConsole() {
  const [appId, setAppId] = useState('mobileui');
  const [environment, setEnvironment] = useState('development');
  const [adminKey, setAdminKey] = useState('local-development-admin');
  const [document, setDocument] = useState('');
  const [state, setState] = useState<LoadState>('idle');
  const [message, setMessage] = useState('输入范围后读取已发布配置。');

  const request = async (path: string, init?: RequestInit) => {
    const response = await fetch(path, {
      ...init,
      headers: { ...headers(appId, environment, adminKey), ...init?.headers },
    });
    const body = await response.json() as {
      data?: unknown;
      error?: { message: string };
    };
    if (!response.ok || body.error) throw new Error(body.error?.message ?? '请求失败');
    return body.data;
  };

  const execute = async (operation: () => Promise<void>) => {
    if (state === 'loading') return;
    setState('loading');
    try {
      await operation();
      setState('success');
    } catch (error) {
      setState('error');
      setMessage(error instanceof Error ? error.message : '操作失败');
    }
  };

  const load = () => execute(async () => {
    const data = await request('/api/v1/admin/config') as ConfigEnvelope;
    setDocument(JSON.stringify(data.draft ?? data.published, null, 2));
    setMessage(data.draft ? '已载入未发布草稿。' : '已载入当前发布版本。');
  });

  const saveDraft = () => execute(async () => {
    const parsed = JSON.parse(document) as Record<string, unknown>;
    await request('/api/v1/admin/config', {
      method: 'PUT',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(parsed),
    });
    setMessage('草稿已保存，客户端配置尚未改变。');
  });

  const publish = () => execute(async () => {
    const data = await request('/api/v1/admin/config/publish', { method: 'POST' });
    setDocument(JSON.stringify(data, null, 2));
    setMessage('草稿已发布，客户端将在刷新策略触发后获取新版本。');
  });

  const rollback = () => execute(async () => {
    const value = window.prompt('输入要恢复的历史版本号');
    if (!value) return;
    const data = await request('/api/v1/admin/config/rollback', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ version: Number(value) }),
    });
    setDocument(JSON.stringify(data, null, 2));
    setMessage(`已恢复版本 ${value} 的内容，并生成新的发布版本。`);
  });

  return (
    <section className="panel console">
      <div className="panel-title">
        <div>
          <p className="eyebrow">Tenant configuration</p>
          <h2>多租户配置发布</h2>
        </div>
        <span className={`status ${state}`}>{stateLabel(state)}</span>
      </div>
      <div className="scope-grid">
        <Field label="App ID" value={appId} onChange={setAppId} />
        <Field label="Environment" value={environment} onChange={setEnvironment} />
        <Field label="Admin key" type="password" value={adminKey} onChange={setAdminKey} />
      </div>
      <div className="actions">
        <button disabled={state === 'loading'} onClick={load}>读取</button>
        <button disabled={state === 'loading'} onClick={saveDraft}>保存草稿</button>
        <button disabled={state === 'loading'} onClick={publish}>发布</button>
        <button className="secondary" disabled={state === 'loading'} onClick={rollback}>回滚</button>
      </div>
      <label className="editor-label" htmlFor="config-document">运行时配置 JSON</label>
      <textarea
        id="config-document"
        onChange={(event) => setDocument(event.target.value)}
        spellCheck={false}
        value={document}
      />
      <p className="console-message" role="status">{message}</p>
    </section>
  );
}

function Field(props: Readonly<{
  label: string;
  type?: string;
  value: string;
  onChange: (value: string) => void;
}>) {
  return (
    <label>
      <span>{props.label}</span>
      <input
        type={props.type ?? 'text'}
        value={props.value}
        onChange={(event) => props.onChange(event.target.value)}
      />
    </label>
  );
}

function headers(appId: string, environment: string, adminKey: string) {
  return {
    'x-admin-key': adminKey,
    'x-admin-actor': 'control-plane-ui',
    'x-app-id': appId,
    'x-app-environment': environment,
    'x-platform': 'web',
  };
}

function stateLabel(state: LoadState) {
  return { idle: '等待', loading: '处理中', success: '已完成', error: '失败' }[state];
}
