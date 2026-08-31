import http from '@ohos.net.http'
import { TelemetryBatch } from '../telemetry/Telemetry'
import {
  ApiFailure,
  ApiRequestBody,
  ApiTransport,
  ProfileUpdateBody,
  RestorePurchasesBody,
  SocialSignInInput,
  VerifyPurchaseBody
} from './ApiTransport'
import {
  AppUser,
  AuthPayload,
  BootstrapPayload,
  CouponView,
  CreateOrderResult,
  DeleteAccountInput,
  HelpArticle,
  MembershipCurrent,
  NotificationView,
  OrderStatus,
  OrderView,
  SignUploadResult,
  PhoneCodeInput,
  PhoneVerifyInput,
  PurchaseReceipt,
  parseOrderStatus,
  ReferralView,
  SessionView,
  SignInInput,
  SignUpInput,
  SupportTicket,
  SupportTicketDetail,
  SupportMessage,
  UsageSummary
} from '../domain/Models'
import {
  createTicket,
  help,
  reply,
  resolveObjectUrl,
  signUpload,
  submitFeedback,
  ticket,
  tickets
} from './ApiStorageSupport'
import { uploadToS3 } from './ApiTransport'
import { CreateTicketInput } from '../domain/SupportModels'
import {
  changePassword,
  requestPasswordReset,
  requestPhoneCode,
  resendEmailVerification,
  resetPassword,
  saveSettings,
  signIn,
  signOut,
  signOutAll,
  signUp,
  socialSignIn,
  updateProfile,
  verifyEmail,
  verifyPasswordReset,
  verifyPhoneCode
} from './ApiAuthEndpoints'

export { ApiFailure } from './ApiTransport'

export class ApiClient {
  private transport: ApiTransport = new ApiTransport()

  setToken(token: string): void {
    this.transport.setToken(token)
  }

  setRefreshToken(token: string): void {
    this.transport.setRefreshToken(token)
  }

  setInstallationId(value: string): void {
    this.transport.setInstallationId(value)
  }

  setLanguage(value: string): void {
    this.transport.setLanguage(value)
  }

  // Set by AppStore so an unrecoverable session expiry clears the user and
  // returns to the sign-in guard instead of looping on failing requests.
  setSessionExpiredCallback(callback: (() => void) | null): void {
    this.transport.setSessionExpiredCallback(callback)
  }

  // Set by AppStore so a successful refresh persists the rotated token pair
  // to localStore（否则重启后读到已轮换的旧 refresh token，复用检测会吊销会话）。
  setTokenPersistHandler(handler: ((token: string, refreshToken: string) => void) | null): void {
    this.transport.setTokenPersistHandler(handler)
  }

  bootstrap(): Promise<BootstrapPayload> {
    return this.request<BootstrapPayload>('/api/v1/bootstrap', http.RequestMethod.GET)
  }

  signIn(identifier: string, password: string): Promise<AuthPayload> {
    return signIn(this.transport, identifier, password)
  }

  signUp(email: string, password: string, username: string, consentVersion: string):
    Promise<AuthPayload> {
    return signUp(this.transport, email, password, username, consentVersion)
  }

  verifyEmail(email: string, code: string): Promise<boolean> {
    return verifyEmail(this.transport, email, code)
  }

  resendEmailVerification(email: string): Promise<boolean> {
    return resendEmailVerification(this.transport, email)
  }

  signOut(): Promise<boolean> {
    return signOut(this.transport)
  }

  signOutAll(): Promise<boolean> {
    return signOutAll(this.transport)
  }

  requestPhoneCode(phone: string): Promise<boolean> {
    return requestPhoneCode(this.transport, phone)
  }

  verifyPhoneCode(phone: string, code: string): Promise<AuthPayload> {
    return verifyPhoneCode(this.transport, phone, code)
  }

  socialSignIn(
    provider: string,
    idToken: string,
    authorizationCode: string,
    redirectUri: string,
    codeVerifier: string
  ): Promise<AuthPayload> {
    return socialSignIn(this.transport, provider, idToken, authorizationCode, redirectUri, codeVerifier)
  }

  requestPasswordReset(email: string): Promise<boolean> {
    return requestPasswordReset(this.transport, email)
  }

  verifyPasswordReset(email: string, code: string): Promise<string> {
    return verifyPasswordReset(this.transport, email, code)
  }

  resetPassword(resetToken: string, newPassword: string): Promise<boolean> {
    return resetPassword(this.transport, resetToken, newPassword)
  }

  saveSettings(patch: Record<string, string | number | boolean>):
    Promise<Record<string, string | number | boolean>> {
    return saveSettings(this.transport, patch)
  }

  changePassword(currentPassword: string, newPassword: string): Promise<boolean> {
    return changePassword(this.transport, currentPassword, newPassword)
  }

  updateProfile(displayName: string, bio: string, avatarUrl: string | null): Promise<AppUser> {
    return updateProfile(this.transport, displayName, bio, avatarUrl)
  }

  sessions(): Promise<SessionView[]> {
    return this.request<SessionView[]>('/api/v1/me/sessions', http.RequestMethod.GET)
  }

  revokeSession(id: string): Promise<boolean> {
    return this.request<Record<string, boolean>>(
      `/api/v1/me/sessions/${id}`,
      http.RequestMethod.DELETE
    ).then(result => result['revoked'] === true)
  }

  orders(): Promise<OrderView[]> {
    return this.request<OrderView[]>('/api/v1/orders', http.RequestMethod.GET)
  }

  createOrder(planId: string, idempotencyKey: string): Promise<CreateOrderResult> {
    return this.request<CreateOrderResult>(
      '/api/v1/orders',
      http.RequestMethod.POST,
      { planId },
      { 'Idempotency-Key': idempotencyKey }
    )
  }

  verifyPurchase(orderId: string | null, receipt: PurchaseReceipt):
    Promise<OrderView> {
    const body: VerifyPurchaseBody = { receipt }
    if (orderId != null) body.orderId = orderId
    return this.request<OrderView>(
      '/api/v1/purchases/verify', http.RequestMethod.POST, body
    ).then((order: OrderView): OrderView => ({
      id: order.id,
      planId: order.planId,
      status: parseOrderStatus(String(order.status)),
      amountMinor: order.amountMinor,
      currency: order.currency,
      provider: order.provider,
      createdAt: order.createdAt,
      completedAt: order.completedAt
    }))
  }

  restorePurchases(receipts: PurchaseReceipt[]): Promise<string[]> {
    const body: RestorePurchasesBody = { receipts }
    return this.request<Record<string, string[]>>(
      '/api/v1/purchases/restore', http.RequestMethod.POST, body
    ).then(result => result['entitlements'] ?? [])
  }

  // ── S3 storage (BaaS) ───────────────────────────────────────────────────
  // 实现在 ApiStorageSupport.ets / ApiTransport.ets（350 行拆分），此处薄委托。
  signUpload(path: string, contentType: string): Promise<SignUploadResult> {
    return signUpload(this.transport, path, contentType)
  }

  resolveObjectUrl(objectKey: string): Promise<string | null> {
    return resolveObjectUrl(this.transport, objectKey)
  }

  uploadToS3(uploadUrl: string, data: ArrayBuffer, contentType: string): Promise<void> {
    return uploadToS3(uploadUrl, data, contentType)
  }

  membershipCurrent(): Promise<MembershipCurrent> {
    return this.request<MembershipCurrent>('/api/v1/membership/current', http.RequestMethod.GET)
  }

  entitlements(): Promise<string[]> {
    return this.request<Record<string, string[]>>(
      '/api/v1/membership/entitlements', http.RequestMethod.GET
    ).then(result => result['keys'] ?? [])
  }

  notifications(): Promise<NotificationView[]> {
    return this.request<NotificationView[]>('/api/v1/notifications', http.RequestMethod.GET)
  }

  markAllNotificationsRead(): Promise<boolean> {
    return this.request<Record<string, boolean>>(
      '/api/v1/notifications', http.RequestMethod.PUT
    ).then(result => result['allRead'] === true)
  }

  markNotificationRead(id: string): Promise<boolean> {
    return this.request<Record<string, boolean>>(
      `/api/v1/notifications/${id}`, http.RequestMethod.PUT
    ).then(result => result['read'] === true)
  }

  deleteNotification(id: string): Promise<boolean> {
    return this.request<Record<string, boolean>>(
      `/api/v1/notifications/${id}`, http.RequestMethod.DELETE
    ).then(result => result['deleted'] === true)
  }

  // ── 客服支持（实现在 ApiStorageSupport.ets）───────────────────────────────
  submitFeedback(
    title: string,
    body: string,
    category: string = 'suggestion',
    rating: number = 5
  ): Promise<boolean> {
    return submitFeedback(this.transport, title, body, category, rating)
  }

  help(): Promise<HelpArticle[]> {
    return help(this.transport)
  }

  tickets(): Promise<SupportTicket[]> {
    return tickets(this.transport)
  }

  ticket(id: string): Promise<SupportTicketDetail> {
    return ticket(this.transport, id)
  }

  createTicket(input: CreateTicketInput): Promise<SupportTicket> {
    return createTicket(this.transport, input)
  }

  reply(ticketId: string, message: string): Promise<SupportMessage> {
    return reply(this.transport, ticketId, message)
  }

  usage(): Promise<UsageSummary> {
    return this.request<UsageSummary>('/api/v1/me/usage', http.RequestMethod.GET)
  }

  coupons(): Promise<CouponView[]> {
    return this.request<CouponView[]>('/api/v1/me/coupons', http.RequestMethod.GET)
  }

  referral(): Promise<ReferralView> {
    return this.request<ReferralView>('/api/v1/me/referral', http.RequestMethod.GET)
  }

  deleteAccount(password: string): Promise<boolean> {
    const input: DeleteAccountInput = { password, confirmation: 'DELETE' }
    return this.request<Record<string, boolean>>(
      '/api/v1/me/deletion',
      http.RequestMethod.DELETE,
      input
    ).then(result => result['deleted'] === true)
  }

  telemetry(batch: TelemetryBatch): Promise<boolean> {
    return this.transport.telemetry(batch)
  }

  private async request<T>(
    path: string,
    method: http.RequestMethod,
    body?: ApiRequestBody,
    extraHeaders?: Record<string, string>
  ): Promise<T> {
    return this.transport.request<T>(path, method, body, extraHeaders)
  }
}

export const apiClient: ApiClient = new ApiClient()
