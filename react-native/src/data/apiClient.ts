import { Platform } from 'react-native';
import {
  AppUser,
  BootstrapPayload,
  CouponView,
  HelpArticle,
  NotificationItem,
  OrderView,
  ProductFeedback,
  ReferralView,
  SessionView,
  SupportConfig,
  SupportMessage,
  SupportTicket,
  SupportTicketDetail,
  UserSettings,
  UsageSummary,
} from '../domain/models';
import { readAnonymousId, readSessionToken } from './storage';

type Envelope<T> = Readonly<{ data: T }>;
type ErrorEnvelope = Readonly<{
  error: Readonly<{ code: string; message: string; retryable: boolean; traceId: string }>;
}>;

const apiBase = process.env.EXPO_PUBLIC_API_URL
  ?? (Platform.OS === 'android' ? 'http://10.0.2.2:3210' : 'http://localhost:3210');

export class ApiClientError extends Error {
  constructor(
    readonly code: string,
    message: string,
    readonly status: number,
    readonly retryable: boolean,
  ) {
    super(message);
  }
}

export const apiClient = {
  bootstrap: () => request<BootstrapPayload>('/api/v1/bootstrap'),
  signIn: (identifier: string, password: string) => requestAuth('/api/v1/auth/sign-in', {
    identifier,
    password,
    deviceName: `${Platform.OS} · MobileUI`,
  }),
  signUp: (email: string, password: string, username: string) =>
    requestAuth('/api/v1/auth/sign-up', {
      email,
      password,
      username,
      deviceName: `${Platform.OS} · MobileUI`,
    }),
  socialSignIn: (input: {
    provider: 'apple' | 'google' | 'github';
    idToken?: string;
    authorizationCode?: string;
    redirectUri?: string;
    codeVerifier?: string;
    nonce?: string;
  }) => requestAuth('/api/v1/auth/social', {
    ...input,
    deviceName: `${Platform.OS} · MobileUI`,
  }),
  signOut: () => request<{ signedOut: boolean }>('/api/v1/auth/sign-out', { method: 'POST' }),
  requestPhoneCode: (phone: string) => request<{
    accepted: boolean;
    resendAfterSeconds: number;
  }>('/api/v1/auth/phone/request', jsonOptions('POST', { phone })),
  verifyPhoneCode: (phone: string, code: string) => requestAuth('/api/v1/auth/phone/verify', {
    phone,
    code,
    deviceName: `${Platform.OS} · MobileUI`,
  }),
  requestPasswordReset: (email: string) => request<{
    accepted: boolean;
    resendAfterSeconds: number;
  }>('/api/v1/auth/password/forgot', jsonOptions('POST', { email })),
  verifyPasswordReset: (email: string, code: string) => request<{
    resetToken: string;
    expiresInSeconds: number;
  }>('/api/v1/auth/password/verify', jsonOptions('POST', { email, code })),
  resetPassword: (resetToken: string, newPassword: string) => request<{
    changed: boolean;
    requiresSignIn: boolean;
  }>('/api/v1/auth/password/reset', jsonOptions('POST', { resetToken, newPassword })),
  updateProfile: (patch: { displayName?: string; bio?: string; avatarUrl?: string | null }) =>
    request<AppUser>('/api/v1/me/profile', jsonOptions('PATCH', patch)),
  changePassword: (currentPassword: string, newPassword: string) =>
    request<{ changed: boolean; requiresSignIn: boolean }>(
      '/api/v1/me/change-password',
      jsonOptions('POST', { currentPassword, newPassword }),
    ),
  saveSettings: (patch: UserSettings) =>
    request<UserSettings>('/api/v1/me/settings', jsonOptions('PUT', patch)),
  sessions: () => request<readonly SessionView[]>('/api/v1/me/sessions'),
  revokeSession: (id: string) =>
    request<{ revoked: boolean }>(`/api/v1/me/sessions/${id}`, { method: 'DELETE' }),
  notifications: () => request<readonly NotificationItem[]>('/api/v1/notifications'),
  readAllNotifications: () =>
    request<{ allRead: boolean }>('/api/v1/notifications', { method: 'PATCH' }),
  readNotification: (id: string) =>
    request<{ read: boolean }>(`/api/v1/notifications/${id}`, { method: 'PATCH' }),
  deleteNotification: (id: string) =>
    request<{ deleted: boolean }>(`/api/v1/notifications/${id}`, { method: 'DELETE' }),
  orders: () => request<readonly OrderView[]>('/api/v1/orders'),
  usage: () => request<UsageSummary>('/api/v1/me/usage'),
  coupons: () => request<readonly CouponView[]>('/api/v1/me/coupons'),
  referral: () => request<ReferralView>('/api/v1/me/referral'),
  purchase: (planId: string) => request<OrderView>(
    '/api/v1/orders',
    {
      ...jsonOptions('POST', { planId }),
      headers: {
        ...clientHeaders(),
        'Content-Type': 'application/json',
        'Idempotency-Key': createIdempotencyKey(),
      },
    },
  ),
  deleteAccount: (password: string) => request<{ deleted: boolean }>(
    '/api/v1/me/deletion',
    jsonOptions('DELETE', { password, confirmation: 'DELETE' }),
  ),
  telemetry: (batch: {
    anonymousId: string;
    sessionId: string;
    events: readonly Record<string, unknown>[];
  }, signal?: AbortSignal) => request<{ accepted: number; duplicates: number }>(
    '/api/v1/telemetry/events',
    { ...jsonOptions('POST', batch), signal },
  ),
  supportConfig: () => request<Pick<
    SupportConfig,
    'enabled' | 'market' | 'dataRegion' | 'categories'
  >>('/api/v1/support/config'),
  helpArticles: () => request<readonly HelpArticle[]>('/api/v1/support/help'),
  supportTickets: () => request<readonly SupportTicket[]>('/api/v1/support/tickets'),
  supportTicket: (id: string) =>
    request<SupportTicketDetail>(`/api/v1/support/tickets/${id}`),
  createSupportTicket: (input: {
    category: string;
    severity: 'normal' | 'high' | 'urgent';
    subject: string;
    message: string;
  }) => request<SupportTicket>('/api/v1/support/tickets', jsonOptions('POST', input)),
  replySupportTicket: (id: string, message: string) =>
    request<SupportMessage>(
      `/api/v1/support/tickets/${id}/messages`,
      jsonOptions('POST', { message }),
    ),
  submitFeedback: (input: {
    category: 'suggestion' | 'experience' | 'feature_request' | 'other';
    title: string;
    body: string;
    rating?: number;
    screenshots: readonly Readonly<{
      fileName: string;
      mimeType: 'image/jpeg';
      data: string;
    }>[];
  }) => request<ProductFeedback>('/api/v1/support/feedback', jsonOptions('POST', input)),
};

async function requestAuth(
  path: string,
  body: Readonly<Record<string, string | undefined>>,
) {
  return request<{ token: string; user: AppUser }>(path, jsonOptions('POST', body));
}

async function request<T>(path: string, options: RequestInit = {}): Promise<T> {
  const [token, installationId] = await Promise.all([
    readSessionToken(),
    readAnonymousId(),
  ]);
  let response: Response;
  try {
    response = await fetch(`${apiBase}${path}`, {
      ...options,
      headers: {
        ...clientHeaders(),
        'X-Installation-Id': installationId,
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
        ...options.headers,
      },
    });
  } catch {
    throw serviceUnavailableError();
  }
  const body = await parseResponse<T>(response);
  if (!response.ok || 'error' in body) {
    const error = 'error' in body ? body.error : {
      code: 'HTTP_ERROR',
      message: response.status >= 500 ? '服务暂时不可用，请稍后重试' : '服务请求失败',
      retryable: response.status >= 500,
    };
    throw new ApiClientError(error.code, error.message, response.status, error.retryable);
  }
  return body.data;
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

function jsonOptions(method: string, body: unknown): RequestInit {
  return {
    method,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  };
}

function clientHeaders() {
  return {
    'X-App-Id': process.env.EXPO_PUBLIC_APP_ID ?? 'mobileui',
    'X-App-Environment': process.env.EXPO_PUBLIC_APP_ENVIRONMENT ?? 'development',
    'X-Platform': Platform.OS,
    'X-App-Version': '1.0.0',
    'Accept-Language': 'zh-CN',
  };
}

function createIdempotencyKey() {
  return `${Date.now()}-${Math.random().toString(36).slice(2)}`;
}
