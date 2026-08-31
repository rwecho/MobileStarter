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
import { parseOrderStatus, type CreateOrderResult, type MembershipCurrent } from '../payment/paymentModels';
import { getPlatformHeader } from './runtimePlatform';
import { clientHeaders, jsonOptions, request, requestAuth } from './apiTransport';

// S3 storage upload (BaaS): presigned PUT 直传 OSS。url 为对象访问 URL，
// avatar 等场景存它（base64 退役）。
interface SignUploadResult {
  uploadUrl: string;
  url: string;
  objectKey: string;
}

async function uploadAvatarToStorage(jpegBase64: string, userId: string): Promise<string> {
  const sign = await request<SignUploadResult>('/api/v1/storage/uploads', jsonOptions(
    'POST',
    { path: `avatars/${userId}-${Date.now()}.jpg`, contentType: 'image/jpeg' },
  ));
  const binary = Uint8Array.from(atob(jpegBase64), c => c.charCodeAt(0));
  const put = await fetch(sign.uploadUrl, {
    method: 'PUT',
    headers: { 'content-type': 'image/jpeg' },
    body: binary,
  });
  if (!put.ok) throw new Error(`对象存储上传失败 ${put.status}`);
  return sign.url;
}

// objectKey → presigned GET URL（私有 bucket，24h）。通用资产显示前换取。
async function resolveObjectUrl(objectKey: string): Promise<string | null> {
  try {
    const result = await request<{ url: string }>(
      `/api/v1/storage/urls?key=${encodeURIComponent(objectKey)}`,
    );
    return result.url ?? null;
  } catch {
    return null;
  }
}

// 会话级缓存 + 并发合并（同一 objectKey 只请求一次；失败/过期 invalidate）。
const assetUrlCache = new Map<string, string>();

export async function resolveAssetUrl(objectKey: string): Promise<string | null> {
  if (objectKey.startsWith('http://') || objectKey.startsWith('https://') ||
      objectKey.startsWith('data:')) {
    return objectKey;
  }
  const cached = assetUrlCache.get(objectKey);
  if (cached) return cached;
  const url = await resolveObjectUrl(objectKey);
  if (url) assetUrlCache.set(objectKey, url);
  return url;
}

export function invalidateAssetUrl(objectKey: string): void {
  assetUrlCache.delete(objectKey);
}
export const apiClient = {
  uploadAvatarToStorage,
  resolveObjectUrl,
  bootstrap: () => request<BootstrapPayload>('/api/v1/bootstrap'),
  signIn: (identifier: string, password: string) => requestAuth('/api/v1/auth/sign-in', {
    identifier,
    password,
    deviceName: `${getPlatformHeader()} · MobileUI`,
  }),
  signUp: (email: string, password: string, username: string, consentVersion: string) =>
    requestAuth('/api/v1/auth/sign-up', {
      email,
      password,
      username,
      consentVersion,
      deviceName: `${getPlatformHeader()} · MobileUI`,
    }),
  verifyEmail: (email: string, code: string) => request<{ verified: boolean }>(
    '/api/v1/auth/verify-email', jsonOptions('POST', { email, code }),
  ),
  resendEmailVerification: (email: string) => request<{
    accepted: boolean;
    resendAfterSeconds: number;
  }>('/api/v1/auth/verify-email/resend', jsonOptions('POST', { email })),
  socialSignIn: (input: {
    provider: 'apple' | 'google' | 'github';
    idToken?: string;
    authorizationCode?: string;
    redirectUri?: string;
    codeVerifier?: string;
    nonce?: string;
  }) => requestAuth('/api/v1/auth/social', {
    ...input,
    deviceName: `${getPlatformHeader()} · MobileUI`,
  }),
  signOut: () => request<{ signedOut: boolean }>('/api/v1/auth/sign-out', { method: 'POST' }),
  signOutAll: () => request<{ signedOut: boolean }>('/api/v1/auth/sign-out-all', { method: 'POST' }),
  requestPhoneCode: (phone: string) => request<{
    accepted: boolean;
    resendAfterSeconds: number;
  }>('/api/v1/auth/phone/request', jsonOptions('POST', { phone })),
  verifyPhoneCode: (phone: string, code: string) => requestAuth('/api/v1/auth/phone/verify', {
    phone,
    code,
    deviceName: `${getPlatformHeader()} · MobileUI`,
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
  orders: () => request<readonly OrderView[]>('/api/v1/orders')
    .then((rows) => rows.map(toOrderView)),
  usage: () => request<UsageSummary>('/api/v1/me/usage'),
  coupons: () => request<readonly CouponView[]>('/api/v1/me/coupons'),
  referral: () => request<ReferralView>('/api/v1/me/referral'),
  createOrder: (planId: string, idempotencyKey: string) => request<CreateOrderResult>(
    '/api/v1/orders',
    {
      ...jsonOptions('POST', { planId }),
      headers: {
        ...clientHeaders(),
        'Content-Type': 'application/json',
        'Idempotency-Key': idempotencyKey,
      },
    },
  ),
  verifyPurchase: (orderId: string | undefined, receipt: unknown) => request<OrderView>(
    '/api/v1/purchases/verify',
    jsonOptions('POST', { ...(orderId ? { orderId } : {}), receipt }),
  ).then(toOrderView),
  restore: (receipts: unknown[]) => request<{ entitlements: readonly string[] }>(
    '/api/v1/purchases/restore',
    jsonOptions('POST', { receipts }),
  ),
  membershipCurrent: () => request<MembershipCurrent>('/api/v1/membership/current'),
  entitlements: () => request<{ keys: readonly string[] }>('/api/v1/membership/entitlements'),
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

// Normalize OrderView.status at the boundary: the wire returns raw strings,
// but OrderView.status is the typed OrderStatus union.
function toOrderView(raw: OrderView): OrderView {
  return { ...raw, status: parseOrderStatus(raw.status) };
}

// 传输层符号统一经 apiClient re-export：调用方（含测试）只 import apiClient。
export {
  ApiClientError,
  registerSessionExpiredHandler,
  setAnonymousIdReader,
  setRefreshTokenReader,
  setRefreshTokenWriter,
  setSessionTokenReader,
  setSessionTokenWriter,
  specificErrorMessage,
} from './apiTransport';

// Platform header injection is re-exported so callers configure the whole HTTP
// layer through apiClient alone (tests set it to 'ios'; App sets Platform.OS).
export { setPlatformHeader } from './runtimePlatform';
