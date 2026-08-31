// HTTP 传输层：token 注入、401 自动刷新、错误归一化、应用身份头。
// 从 apiClient.ts 拆出以服从 CI 350 行硬上限；对外符号经 apiClient re-export，
// 调用方 API 不变。
import type { AuthSession } from '../domain/models';
import { getPlatformHeader } from './runtimePlatform';

type Envelope<T> = Readonly<{ data: T }>;
type ErrorPayload = Readonly<{
  code: string;
  message: string;
  retryable: boolean;
  traceId: string;
  retryAfterSeconds?: number;
  fieldErrors?: Readonly<Record<string, readonly string[]>>;
}>;
type ErrorEnvelope = Readonly<{ error: ErrorPayload }>;

function getApiBase() {
  return process.env.EXPO_PUBLIC_API_URL
    ?? (getPlatformHeader() === 'android' ? 'http://10.0.2.2:3210' : 'http://localhost:3210');
}

export class ApiClientError extends Error {
  constructor(
    readonly code: string,
    message: string,
    readonly status: number,
    readonly retryable: boolean,
    readonly retryAfterSeconds?: number,
    readonly fieldErrors?: Readonly<Record<string, readonly string[]>>,
  ) {
    super(message);
  }
}

// Token/anonymous sources are injectable so the HTTP layer is node-testable
// (RN storage imports react-native/expo modules that don't load in node).
// Defaults lazily load the RN implementation only when actually used.
type Reader = () => Promise<string | null>;
let sessionTokenReader: Reader = () => import('./storage').then((m) => m.readSessionToken());
let refreshTokenReader: Reader = () => import('./storage').then((m) => m.readRefreshToken());
let anonymousIdReader: Reader = () => import('./storage').then((m) => m.readAnonymousId());
let sessionTokenWriter: (token: string | null) => Promise<void> =
  (token) => import('./storage').then((m) => m.saveSessionToken(token));
let refreshTokenWriter: (token: string | null) => Promise<void> =
  (token) => import('./storage').then((m) => m.saveRefreshToken(token));

export function setSessionTokenReader(reader: Reader) { sessionTokenReader = reader; }
export function setRefreshTokenReader(reader: Reader) { refreshTokenReader = reader; }
export function setAnonymousIdReader(reader: Reader) { anonymousIdReader = reader; }
export function setSessionTokenWriter(writer: (token: string | null) => Promise<void>) { sessionTokenWriter = writer; }
export function setRefreshTokenWriter(writer: (token: string | null) => Promise<void>) { refreshTokenWriter = writer; }

let refreshInFlight: Promise<boolean> | null = null;
let sessionExpiredHandler: (() => void) | null = null;

// AppStore registers this so that an unrecoverable session expiry clears the
// user and bounces to the sign-in guard, instead of looping on failing calls.
export function registerSessionExpiredHandler(handler: (() => void) | null) {
  sessionExpiredHandler = handler;
}

export async function request<T>(path: string, options: RequestInit = {}): Promise<T> {
  return sendRequest<T>(path, options, false);
}

export async function requestAuth(
  path: string,
  body: Readonly<Record<string, string | undefined>>,
) {
  return request<AuthSession>(path, jsonOptions('POST', body));
}

async function sendRequest<T>(
  path: string,
  options: RequestInit,
  retried: boolean,
): Promise<T> {
  const [token, installationId] = await Promise.all([
    sessionTokenReader(),
    anonymousIdReader(),
  ]);
  let response: Response;
  try {
    response = await fetch(`${getApiBase()}${path}`, {
      ...options,
      headers: {
        ...clientHeaders(),
        ...(installationId ? { 'X-Installation-Id': installationId } : {}),
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
        ...options.headers,
      },
    });
  } catch {
    throw serviceUnavailableError();
  }
  if (response.status === 401 && !retried && await refreshSession()) {
    return sendRequest<T>(path, options, true);
  }
  const body = await parseResponse<T>(response);
  if (!response.ok || 'error' in body) {
    const error: ErrorPayload = 'error' in body ? body.error : {
      code: 'HTTP_ERROR',
      message: response.status >= 500 ? '服务暂时不可用，请稍后重试' : '服务请求失败',
      retryable: response.status >= 500,
      traceId: 'local',
    };
    // 401 仅在「已登录会话失效」时触发过期回调；auth 端点（登录/注册/验证码
    // 等）的 401 是凭证错误，走表单内联错误展示，不能切页/清输入。
    if (response.status === 401 && !retried && !path.startsWith('/api/v1/auth/')) {
      sessionExpiredHandler?.();
    }
    throw new ApiClientError(
      error.code,
      specificErrorMessage(error.message, error.fieldErrors),
      response.status,
      error.retryable,
      error.retryAfterSeconds,
      error.fieldErrors,
    );
  }
  return body.data;
}

export function specificErrorMessage(
  fallback: string,
  fieldErrors?: Readonly<Record<string, readonly string[]>>,
) {
  if (!fieldErrors) return fallback;
  const messages = [...new Set(Object.values(fieldErrors).flat().filter(Boolean))];
  return messages.length ? messages.join('；') : fallback;
}

async function refreshSession(): Promise<boolean> {
  if (!refreshInFlight) refreshInFlight = performRefresh();
  try {
    return await refreshInFlight;
  } finally {
    refreshInFlight = null;
  }
}

async function performRefresh(): Promise<boolean> {
  const refreshToken = await refreshTokenReader();
  if (!refreshToken) return false;
  try {
    const response = await fetch(`${getApiBase()}/api/v1/auth/refresh`, {
      method: 'POST',
      headers: { ...clientHeaders(), 'Content-Type': 'application/json' },
      body: JSON.stringify({ refreshToken }),
    });
    if (!response.ok) return false;
    const body = await response.json() as Envelope<AuthSession>;
    const data = body?.data;
    if (!data?.token || !data?.refreshToken) return false;
    await sessionTokenWriter(data.token);
    await refreshTokenWriter(data.refreshToken);
    return true;
  } catch {
    return false;
  }
}

async function parseResponse<T>(response: Response): Promise<Envelope<T> | ErrorEnvelope> {
  const text = await response.text();
  try {
    return JSON.parse(text) as Envelope<T> | ErrorEnvelope;
  } catch {
    if (response.status >= 500) throw serviceUnavailableError(response.status);
    throw new ApiClientError('INVALID_RESPONSE', '服务返回了无法识别的数据', response.status, false);
  }
}

function serviceUnavailableError(status = 0) {
  return new ApiClientError(
    'SERVICE_UNAVAILABLE',
    '无法连接服务器，请检查网络后重试',
    status,
    true,
  );
}

export function jsonOptions(method: string, body: unknown): RequestInit {
  return {
    method,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  };
}

// 每个 App 必须通过 EXPO_PUBLIC_APP_ID 声明自己的 app_id（租户）。
// 未配置时启动即抛错，避免混入不可预测的 app_id。
const APP_ID = process.env.EXPO_PUBLIC_APP_ID?.trim();
if (!APP_ID) {
  throw new Error('EXPO_PUBLIC_APP_ID 未配置：请在 .env 中设置该 App 的 app_id 后再启动。');
}

// environment（development/staging/production 等）也必须显式配置，未配置即启动报错。
const APP_ENVIRONMENT = process.env.EXPO_PUBLIC_APP_ENVIRONMENT?.trim();
if (!APP_ENVIRONMENT) {
  throw new Error('EXPO_PUBLIC_APP_ENVIRONMENT 未配置：请在 .env 中设置该 App 的 environment 后再启动。');
}

export function clientHeaders() {
  return {
    'X-App-Id': APP_ID,
    'X-App-Environment': APP_ENVIRONMENT,
    'X-Platform': getPlatformHeader(),
    'X-App-Version': '1.0.0',
    'Accept-Language': 'zh-CN',
  };
}
