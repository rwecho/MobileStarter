import http from '@ohos.net.http'
import { TelemetryBatch, TelemetryValue } from '../telemetry/Telemetry'
import {
  ApiEnvelope,
  ApiErrorBody,
  AppUser,
  AuthPayload,
  BootstrapPayload,
  CouponView,
  CreateTicketInput,
  DeleteAccountInput,
  FeedbackInput,
  HelpArticle,
  PhoneCodeInput,
  PhoneVerifyInput,
  ReferralView,
  SessionView,
  SignInInput,
  SignUpInput,
  OrderView,
  NotificationView,
  SupportTicket,
  SupportTicketDetail,
  SupportMessage,
  UsageSummary
} from '../domain/Models'

const API_BASE: string = 'http://192.168.20.110:3210'
const APP_ID: string = 'mobileui'

interface SocialSignInInput {
  provider: string
  deviceName: string
  idToken?: string
  authorizationCode?: string
  redirectUri?: string
  codeVerifier?: string
}

interface TelemetryEventEnvelope {
  eventId: string
  name: string
  screenId: string
  occurredAt: string
  configVersion: number
  properties: Record<string, TelemetryValue>
}

export class ApiFailure extends Error {
  readonly code: string
  readonly status: number
  readonly retryable: boolean

  constructor(code: string, message: string, status: number, retryable: boolean) {
    super(message)
    this.code = code
    this.status = status
    this.retryable = retryable
  }
}

export class ApiClient {
  private token: string = ''
  private refreshToken: string = ''
  private installationId: string = ''
  private language: string = 'zh-CN'
  private refreshInFlight: Promise<boolean> | null = null
  private sessionExpiredCallback: (() => void) | null = null

  setToken(token: string): void {
    this.token = token
  }

  setRefreshToken(token: string): void {
    this.refreshToken = token
  }

  setInstallationId(value: string): void {
    this.installationId = value
  }

  setLanguage(value: string): void {
    this.language = value
  }

  // Set by AppStore so an unrecoverable session expiry clears the user and
  // returns to the sign-in guard instead of looping on failing requests.
  setSessionExpiredCallback(callback: (() => void) | null): void {
    this.sessionExpiredCallback = callback
  }

  bootstrap(): Promise<BootstrapPayload> {
    return this.request<BootstrapPayload>('/api/v1/bootstrap', http.RequestMethod.GET)
  }

  signIn(identifier: string, password: string): Promise<AuthPayload> {
    const input: SignInInput = { identifier, password, deviceName: 'HarmonyOS · MobileUI' }
    return this.request<AuthPayload>('/api/v1/auth/sign-in', http.RequestMethod.POST, input)
  }

  signUp(email: string, password: string, username: string, consentVersion: string):
    Promise<AuthPayload> {
    const input: SignUpInput = {
      email,
      password,
      username,
      consentVersion,
      deviceName: 'HarmonyOS · MobileUI'
    }
    return this.request<AuthPayload>('/api/v1/auth/sign-up', http.RequestMethod.POST, input)
  }

  verifyEmail(email: string, code: string): Promise<boolean> {
    return this.request<Record<string, boolean>>(
      '/api/v1/auth/verify-email',
      http.RequestMethod.POST,
      { email, code }
    ).then(result => result['verified'] === true)
  }

  resendEmailVerification(email: string): Promise<boolean> {
    return this.request<Record<string, boolean>>(
      '/api/v1/auth/verify-email/resend',
      http.RequestMethod.POST,
      { email }
    ).then(result => result['accepted'] === true)
  }

  signOut(): Promise<boolean> {
    return this.request<Record<string, boolean>>(
      '/api/v1/auth/sign-out',
      http.RequestMethod.POST
    ).then(result => result['signedOut'] === true)
  }

  signOutAll(): Promise<boolean> {
    return this.request<Record<string, boolean>>(
      '/api/v1/auth/sign-out-all',
      http.RequestMethod.POST
    ).then(result => result['signedOut'] === true)
  }

  requestPhoneCode(phone: string): Promise<boolean> {
    const input: PhoneCodeInput = { phone }
    return this.request<Record<string, boolean>>(
      '/api/v1/auth/phone/request',
      http.RequestMethod.POST,
      input
    ).then(result => result['accepted'] === true)
  }

  verifyPhoneCode(phone: string, code: string): Promise<AuthPayload> {
    const input: PhoneVerifyInput = {
      phone,
      code,
      deviceName: 'HarmonyOS · MobileUI'
    }
    return this.request<AuthPayload>(
      '/api/v1/auth/phone/verify',
      http.RequestMethod.POST,
      input
    )
  }

  socialSignIn(
    provider: string,
    idToken: string,
    authorizationCode: string,
    redirectUri: string,
    codeVerifier: string
  ): Promise<AuthPayload> {
    const body: SocialSignInInput = {
      provider,
      deviceName: 'HarmonyOS · MobileUI'
    }
    if (idToken.length > 0) body.idToken = idToken
    if (authorizationCode.length > 0) body.authorizationCode = authorizationCode
    if (redirectUri.length > 0) body.redirectUri = redirectUri
    if (codeVerifier.length > 0) body.codeVerifier = codeVerifier
    return this.request<AuthPayload>(
      '/api/v1/auth/social', http.RequestMethod.POST, body
    )
  }

  requestPasswordReset(email: string): Promise<boolean> {
    return this.request<Record<string, string | number | boolean>>(
      '/api/v1/auth/password/forgot', http.RequestMethod.POST, { email }
    ).then(result => result['accepted'] === true)
  }

  verifyPasswordReset(email: string, code: string): Promise<string> {
    return this.request<Record<string, string | number>>(
      '/api/v1/auth/password/verify', http.RequestMethod.POST, { email, code }
    ).then(result => String(result['resetToken'] ?? ''))
  }

  resetPassword(resetToken: string, newPassword: string): Promise<boolean> {
    return this.request<Record<string, boolean>>(
      '/api/v1/auth/password/reset', http.RequestMethod.POST,
      { resetToken, newPassword }
    ).then(result => result['changed'] === true)
  }

  saveSettings(patch: Record<string, string | number | boolean>):
    Promise<Record<string, string | number | boolean>> {
    return this.request<Record<string, string | number | boolean>>(
      '/api/v1/me/settings',
      http.RequestMethod.PUT,
      patch
    )
  }

  changePassword(currentPassword: string, newPassword: string): Promise<boolean> {
    return this.request<Record<string, boolean>>(
      '/api/v1/me/change-password',
      http.RequestMethod.POST,
      { currentPassword, newPassword }
    ).then(result => result['changed'] === true)
  }

  updateProfile(displayName: string, bio: string, avatarUrl: string): Promise<AppUser> {
    return this.request<AppUser>(
      '/api/v1/me/profile',
      http.RequestMethod.PUT,
      { displayName, bio, avatarUrl }
    )
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

  submitFeedback(
    title: string,
    body: string,
    category: string = 'suggestion',
    rating: number = 5
  ): Promise<boolean> {
    const input: FeedbackInput = { category, title, body, rating }
    return this.request<Record<string, string | number>>(
      '/api/v1/support/feedback',
      http.RequestMethod.POST,
      input
    ).then(result => String(result['id'] ?? '').length > 0)
  }

  help(): Promise<HelpArticle[]> {
    return this.request<HelpArticle[]>('/api/v1/support/help', http.RequestMethod.GET)
  }

  tickets(): Promise<SupportTicket[]> {
    return this.request<SupportTicket[]>('/api/v1/support/tickets', http.RequestMethod.GET)
  }

  ticket(id: string): Promise<SupportTicketDetail> {
    return this.request<SupportTicketDetail>(
      `/api/v1/support/tickets/${id}`, http.RequestMethod.GET
    )
  }

  createTicket(input: CreateTicketInput): Promise<SupportTicket> {
    return this.request<SupportTicket>(
      '/api/v1/support/tickets', http.RequestMethod.POST, input
    )
  }

  reply(ticketId: string, message: string): Promise<SupportMessage> {
    return this.request<SupportMessage>(
      `/api/v1/support/tickets/${ticketId}/messages`,
      http.RequestMethod.POST,
      { message }
    )
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

  // Telemetry is fire-and-forget and must NOT participate in the 401 refresh /
  // session-expiry loop, so it uses its own request instead of this.request.
  async telemetry(batch: TelemetryBatch): Promise<boolean> {
    const payload = JSON.stringify({
      anonymousId: batch.anonymousId,
      sessionId: batch.sessionId,
      events: batch.events.map((event): TelemetryEventEnvelope => ({
        eventId: event.eventId,
        name: event.name,
        screenId: event.screenId,
        occurredAt: event.occurredAt,
        configVersion: event.configVersion,
        properties: this.toRecord(event.properties)
      }))
    })
    const client = http.createHttp()
    try {
      const response = await client.request(`${API_BASE}/api/v1/telemetry/events`, {
        method: http.RequestMethod.POST,
        header: this.headers(),
        extraData: payload,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 5000,
        readTimeout: 5000
      })
      return response.responseCode >= 200 && response.responseCode < 300
    } catch (error) {
      return false
    } finally {
      client.destroy()
    }
  }

  // Map does not survive JSON.stringify, so flatten it to a plain record first.
  private toRecord(map: Map<string, TelemetryValue>): Record<string, TelemetryValue> {
    const record: Record<string, TelemetryValue> = {}
    map.forEach((value, key) => { record[key] = value })
    return record
  }

  private async request<T>(
    path: string,
    method: http.RequestMethod,
    body?: Record<string, string | number | boolean> |
      SignInInput | SignUpInput | DeleteAccountInput
      | PhoneCodeInput | PhoneVerifyInput | FeedbackInput | CreateTicketInput
      | SocialSignInInput,
    retried: boolean = false
  ): Promise<T> {
    const client = http.createHttp()
    try {
      const response = await client.request(`${API_BASE}${path}`, {
        method,
        header: this.headers(),
        extraData: body === undefined ? undefined : JSON.stringify(body),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 5000,
        readTimeout: 5000
      })
      const text = String(response.result)
      if (response.responseCode === 401 && !retried && await this.refreshSession()) {
        return this.request<T>(path, method, body, true)
      }
      if (response.responseCode < 200 || response.responseCode >= 300) {
        if (response.responseCode === 401 && !retried) {
          this.sessionExpiredCallback?.()
        }
        const failure = JSON.parse(text) as ApiErrorBody
        throw new ApiFailure(
          failure.error.code,
          failure.error.message,
          response.responseCode,
          failure.error.retryable
        )
      }
      return (JSON.parse(text) as ApiEnvelope<T>).data
    } finally {
      client.destroy()
    }
  }

  private async refreshSession(): Promise<boolean> {
    if (this.refreshInFlight === null) {
      this.refreshInFlight = this.performRefresh()
    }
    const current = this.refreshInFlight
    try {
      return await current
    } finally {
      this.refreshInFlight = null
    }
  }

  private async performRefresh(): Promise<boolean> {
    if (this.refreshToken.length === 0) return false
    const client = http.createHttp()
    try {
      const response = await client.request(`${API_BASE}/api/v1/auth/refresh`, {
        method: http.RequestMethod.POST,
        header: this.headers(),
        extraData: JSON.stringify({ refreshToken: this.refreshToken }),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 5000,
        readTimeout: 5000
      })
      if (response.responseCode < 200 || response.responseCode >= 300) return false
      const payload = JSON.parse(String(response.result)) as ApiEnvelope<AuthPayload>
      const data = payload.data
      if (!data.token || !data.refreshToken) return false
      this.token = data.token
      this.refreshToken = data.refreshToken
      return true
    } catch (error) {
      return false
    } finally {
      client.destroy()
    }
  }

  private headers(): Record<string, string> {
    const values: Record<string, string> = {
      'content-type': 'application/json',
      'accept-language': this.language,
      'x-app-id': APP_ID,
      'x-platform': 'harmonyos',
      'x-app-version': '1.0.0'
    }
    if (this.token.length > 0) {
      values['authorization'] = `Bearer ${this.token}`
    }
    if (this.installationId.length > 0) {
      values['x-installation-id'] = this.installationId
    }
    return values
  }
}

export const apiClient: ApiClient = new ApiClient()
