import http from '@ohos.net.http'
import {
  ApiEnvelope,
  ApiErrorBody,
  AppUser,
  AuthPayload,
  BootstrapPayload,
  CouponView,
  DeleteAccountInput,
  FeedbackInput,
  PhoneCodeInput,
  PhoneVerifyInput,
  ReferralView,
  SessionView,
  SignInInput,
  SignUpInput,
  OrderView,
  NotificationView,
  UsageSummary
} from '../domain/Models'

const API_BASE: string = 'http://10.0.2.2:3210'
const APP_ID: string = 'mobileui-demo'

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
  private installationId: string = ''

  setToken(token: string): void {
    this.token = token
  }

  setInstallationId(value: string): void {
    this.installationId = value
  }

  bootstrap(): Promise<BootstrapPayload> {
    return this.request<BootstrapPayload>('/api/v1/bootstrap', http.RequestMethod.GET)
  }

  signIn(identifier: string, password: string): Promise<AuthPayload> {
    const input: SignInInput = { identifier, password, deviceName: 'HarmonyOS · MobileUI' }
    return this.request<AuthPayload>('/api/v1/auth/sign-in', http.RequestMethod.POST, input)
  }

  signUp(email: string, password: string, username: string): Promise<AuthPayload> {
    const input: SignUpInput = {
      email,
      password,
      username,
      deviceName: 'HarmonyOS · MobileUI'
    }
    return this.request<AuthPayload>('/api/v1/auth/sign-up', http.RequestMethod.POST, input)
  }

  signOut(): Promise<boolean> {
    return this.request<Record<string, boolean>>(
      '/api/v1/auth/sign-out',
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

  submitFeedback(title: string, body: string): Promise<boolean> {
    const input: FeedbackInput = { category: 'suggestion', title, body, rating: 5 }
    return this.request<Record<string, string | number>>(
      '/api/v1/support/feedback',
      http.RequestMethod.POST,
      input
    ).then(result => String(result['id'] ?? '').length > 0)
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

  private async request<T>(
    path: string,
    method: http.RequestMethod,
    body?: Record<string, string | number | boolean> |
      SignInInput | SignUpInput | DeleteAccountInput
      | PhoneCodeInput | PhoneVerifyInput | FeedbackInput
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
      if (response.responseCode < 200 || response.responseCode >= 300) {
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

  private headers(): Record<string, string> {
    const values: Record<string, string> = {
      'content-type': 'application/json',
      'accept-language': 'zh-CN',
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
