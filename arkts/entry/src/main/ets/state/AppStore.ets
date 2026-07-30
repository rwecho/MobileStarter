import common from '@ohos.app.ability.common'
import { apiClient, ApiFailure } from '../data/ApiClient'
import { localStore } from '../data/LocalStore'
import { AppUser, AuthPayload, RuntimeConfig } from '../domain/Models'
import { RemoteDataStore } from './RemoteDataStore'
import { AppRoute } from '../navigation/AppRoute'
import { telemetry, TelemetryConfig } from '../telemetry/Telemetry'
import { AppTelemetrySink } from '../telemetry/AppTelemetrySink'
import { applyColorScheme } from '../theme/AppTokens'
import { guardRoute } from '../navigation/RouteGuard'

@Observed
export class AppStore {
  // Resolves the route names carried by notification deep links back to the
  // enum. ArkTS forbids dynamic enum indexing, so this is an explicit map.
  static readonly ROUTE_BY_NAME: Record<string, AppRoute> = {
    'Logo': AppRoute.Logo, 'Promo': AppRoute.Promo, 'Onboarding': AppRoute.Onboarding,
    'Home': AppRoute.Home, 'SignIn': AppRoute.SignIn, 'SignUp': AppRoute.SignUp,
    'PhoneSignIn': AppRoute.PhoneSignIn, 'ForgotPassword': AppRoute.ForgotPassword,
    'VerifyEmail': AppRoute.VerifyEmail, 'ResetPassword': AppRoute.ResetPassword,
    'Profile': AppRoute.Profile, 'ProfileEdit': AppRoute.ProfileEdit,
    'Statistics': AppRoute.Statistics, 'Invite': AppRoute.Invite, 'Coupons': AppRoute.Coupons,
    'Membership': AppRoute.Membership, 'MembershipPlans': AppRoute.MembershipPlans,
    'Checkout': AppRoute.Checkout, 'Orders': AppRoute.Orders, 'Settings': AppRoute.Settings,
    'AccountSecurity': AppRoute.AccountSecurity, 'Devices': AppRoute.Devices,
    'NotificationSettings': AppRoute.NotificationSettings, 'Privacy': AppRoute.Privacy,
    'General': AppRoute.General, 'Appearance': AppRoute.Appearance, 'Language': AppRoute.Language,
    'TextSize': AppRoute.TextSize, 'Storage': AppRoute.Storage, 'Permissions': AppRoute.Permissions,
    'HelpFeedback': AppRoute.HelpFeedback, 'Legal': AppRoute.Legal, 'About': AppRoute.About,
    'DeleteAccount': AppRoute.DeleteAccount, 'NotificationCenter': AppRoute.NotificationCenter,
    'StateGallery': AppRoute.StateGallery, 'SupportTicket': AppRoute.SupportTicket,
    'NewSupportTicket': AppRoute.NewSupportTicket, 'ProductFeedback': AppRoute.ProductFeedback
  }

  routeStack: AppRoute[] = [AppRoute.Logo]
  signedIn: boolean = false
  online: boolean = true
  busy: boolean = false
  config: RuntimeConfig | null = null
  user: AppUser | null = null
  toastMessage: string = ''
  toastError: boolean = false
  authProviders: Record<string, boolean> = {}
  authProviderPolicy: Record<string, boolean> = {}
  authProviderConfig: Record<string, Object> = {}
  recoveryEmail: string = ''
  resetToken: string = ''
  pendingRoute: AppRoute | null = null
  remote: RemoteDataStore = new RemoteDataStore()

  async initialize(context: common.UIAbilityContext): Promise<void> {
    await localStore.initialize(context)
    apiClient.setInstallationId(localStore.installationId())
    const cached = localStore.readConfig()
    if (cached !== null) {
      this.config = cached
    }
    const token = localStore.readToken()
    apiClient.setToken(token)
    apiClient.setRefreshToken(localStore.readRefreshToken())
    apiClient.setSessionExpiredCallback(() => { this.handleSessionExpired() })
    try {
      const payload = await apiClient.bootstrap()
      this.config = payload.config
      this.user = payload.user
      this.authProviders = payload.authProviders
      this.authProviderPolicy = payload.authProviderPolicy
      this.authProviderConfig = payload.authProviderConfig
      this.signedIn = payload.user !== null
      this.online = true
      localStore.saveConfig(payload.config)
    } catch (error) {
      this.online = false
      this.showToast('当前使用离线配置', true)
    }
    this.configureTelemetry()
    this.applyTheme()
    this.applyLanguage()
  }

  private configureTelemetry(): void {
    const config = new TelemetryConfig()
    config.configVersion = this.config?.version ?? 0
    telemetry.configure(config, new AppTelemetrySink())
  }

  // Applies the user's theme choice (settings.theme) to the global palette.
  // 'system' currently resolves to light (reading OS color mode is a TODO).
  private applyTheme(): void {
    const theme = this.user !== null ? this.user.settings['theme'] : undefined
    applyColorScheme(theme === 'dark')
  }

  // Propagates settings.language to the Accept-Language request header.
  private applyLanguage(): void {
    const language = this.user !== null ? this.user.settings['language'] : undefined
    apiClient.setLanguage(language === 'en-US' ? 'en-US' : 'zh-CN')
  }

  get route(): AppRoute {
    return this.routeStack[this.routeStack.length - 1]
  }

  get canGoBack(): boolean {
    return this.routeStack.length > 1
  }

  navigate(route: AppRoute): void {
    const decision = guardRoute(route, this.signedIn, this.config)
    if (decision.pending !== null) this.pendingRoute = decision.pending
    if (decision.unavailable) this.showToast('当前 App 未启用此功能')
    this.routeStack = [...this.routeStack, decision.route]
    telemetry.screen(decision.route.toString())
  }

  // Resolves an in-app route name (from a notification deep link) back to the
  // enum and navigates; external URLs and unknown names are ignored.
  navigateByName(name: string | null): void {
    if (name === null || name.length === 0 || name.includes('://')) return
    const route = AppStore.ROUTE_BY_NAME[name]
    if (route === undefined) return
    this.navigate(route)
  }

  replaceAll(route: AppRoute): void {
    const decision = guardRoute(route, this.signedIn, this.config)
    if (decision.pending !== null) this.pendingRoute = decision.pending
    this.routeStack = [decision.route]
    telemetry.screen(decision.route.toString())
  }

  completeAuthentication(): void {
    const target = this.pendingRoute ?? AppRoute.Profile
    this.pendingRoute = null
    this.replaceAll(target)
  }

  back(): void {
    if (!this.canGoBack) {
      return
    }
    this.routeStack = this.routeStack.slice(0, this.routeStack.length - 1)
    telemetry.screen(this.route.toString())
  }

  async signIn(email: string, password: string): Promise<boolean> {
    return this.authenticate(() => apiClient.signIn(email, password))
  }

  async signUp(email: string, password: string, username: string, consentVersion: string):
    Promise<boolean> {
    return this.authenticate(() => apiClient.signUp(email, password, username, consentVersion))
  }

  async verifyEmail(code: string): Promise<boolean> {
    if (this.user === null) return false
    try {
      const verified = await apiClient.verifyEmail(this.user.email, code)
      if (verified) this.user.emailVerified = true
      return verified
    } catch (error) {
      this.showApiError(error)
      return false
    }
  }

  async requestPhoneCode(phone: string): Promise<boolean> {
    try {
      return await apiClient.requestPhoneCode(phone)
    } catch (error) {
      this.showApiError(error as Error)
      return false
    }
  }

  async verifyPhoneCode(phone: string, code: string): Promise<boolean> {
    return this.authenticate(() => apiClient.verifyPhoneCode(phone, code))
  }

  async socialSignIn(
    provider: string,
    idToken: string,
    authorizationCode: string,
    redirectUri: string,
    codeVerifier: string
  ): Promise<boolean> {
    return this.authenticate(() => apiClient.socialSignIn(
      provider, idToken, authorizationCode, redirectUri, codeVerifier
    ))
  }

  async requestPasswordReset(email: string): Promise<boolean> {
    try {
      const accepted = await apiClient.requestPasswordReset(email)
      if (accepted) this.recoveryEmail = email
      return accepted
    } catch (error) {
      this.showApiError(error)
      return false
    }
  }

  async verifyPasswordReset(code: string): Promise<boolean> {
    try {
      this.resetToken = await apiClient.verifyPasswordReset(this.recoveryEmail, code)
      return this.resetToken.length > 0
    } catch (error) {
      this.showApiError(error)
      return false
    }
  }

  async resetPassword(newPassword: string): Promise<boolean> {
    try {
      const changed = await apiClient.resetPassword(this.resetToken, newPassword)
      if (changed) {
        this.recoveryEmail = ''
        this.resetToken = ''
      }
      return changed
    } catch (error) {
      this.showApiError(error)
      return false
    }
  }

  async signOut(): Promise<void> {
    try {
      await apiClient.signOut()
    } catch (error) {
      this.online = false
    }
    this.clearLocalSession()
    this.signedIn = false
    this.user = null
  }

  async signOutAll(): Promise<void> {
    try {
      await apiClient.signOutAll()
    } catch (error) {
      this.online = false
    }
    this.clearLocalSession()
    this.signedIn = false
    this.user = null
  }

  private clearLocalSession(): void {
    localStore.saveToken('')
    localStore.saveRefreshToken('')
    apiClient.setToken('')
    apiClient.setRefreshToken('')
  }

  private handleSessionExpired(): void {
    this.clearLocalSession()
    this.signedIn = false
    this.user = null
    this.replaceAll(AppRoute.SignIn)
  }

  async saveSetting(key: string, value: string | number | boolean): Promise<boolean> {
    if (!this.signedIn || this.busy) {
      return false
    }
    this.busy = true
    const patch: Record<string, string | number | boolean> = {}
    patch[key] = value
    try {
      const settings = await apiClient.saveSettings(patch)
      if (this.user !== null) {
        this.user.settings = settings
      }
      this.applyTheme()
      this.applyLanguage()
      this.online = true
      this.showToast('设置已同步到服务端')
      return true
    } catch (error) {
      this.showApiError(error)
      return false
    } finally {
      this.busy = false
    }
  }

  async deleteAccount(password: string): Promise<boolean> {
    if (!this.signedIn || this.busy) {
      return false
    }
    this.busy = true
    try {
      if (!await apiClient.deleteAccount(password)) {
        return false
      }
      this.clearLocalSession()
      this.signedIn = false
      this.user = null
      this.showToast('账号已永久删除')
      return true
    } catch (error) {
      this.showApiError(error)
      return false
    } finally {
      this.busy = false
    }
  }

  async changePassword(currentPassword: string, newPassword: string): Promise<boolean> {
    if (!this.signedIn || this.busy) return false
    this.busy = true
    try {
      if (!await apiClient.changePassword(currentPassword, newPassword)) return false
      this.clearLocalSession()
      this.signedIn = false
      this.user = null
      this.showToast('密码已修改，请重新登录')
      return true
    } catch (error) {
      this.showApiError(error)
      return false
    } finally {
      this.busy = false
    }
  }

  async updateProfile(displayName: string, bio: string, avatarUrl: string): Promise<boolean> {
    if (!this.signedIn || this.busy) return false
    this.busy = true
    try {
      this.user = await apiClient.updateProfile(displayName, bio, avatarUrl)
      this.showToast('个人资料已同步到服务端')
      return true
    } catch (error) {
      this.showApiError(error)
      return false
    } finally {
      this.busy = false
    }
  }

  async submitFeedback(
    title: string,
    body: string,
    category: string = 'suggestion',
    rating: number = 5
  ): Promise<boolean> {
    if (this.busy) return false
    this.busy = true
    try {
      const submitted = await apiClient.submitFeedback(title, body, category, rating)
      if (submitted) this.showToast('意见反馈已提交')
      return submitted
    } catch (error) {
      this.showApiError(error)
      return false
    } finally {
      this.busy = false
    }
  }

  async createTicket(
    category: string, severity: string, subject: string, message: string
  ): Promise<boolean> {
    if (this.busy) return false
    this.busy = true
    try {
      const created = await apiClient.createTicket({ category, severity, subject, message })
      await this.remote.openTicket(created.id)
      this.navigate(AppRoute.SupportTicket)
      this.showToast('工单已提交')
      return true
    } catch (error) {
      this.showApiError(error)
      return false
    } finally {
      this.busy = false
    }
  }

  async replyTicket(message: string): Promise<boolean> {
    const detail = this.remote.ticketDetailState.data
    if (detail === undefined || this.busy) return false
    this.busy = true
    try {
      const sent = await apiClient.reply(detail.id, message)
      this.remote.appendReply(sent)
      return true
    } catch (error) {
      this.showApiError(error)
      return false
    } finally {
      this.busy = false
    }
  }

  showToast(message: string, error: boolean = false): void {
    this.toastMessage = message
    this.toastError = error
    setTimeout(() => {
      if (this.toastMessage === message) {
        this.toastMessage = ''
      }
    }, 2400)
  }

  private async authenticate(
    operation: () => Promise<AuthPayload>
  ): Promise<boolean> {
    if (this.busy) {
      return false
    }
    this.busy = true
    try {
      const payload = await operation()
      localStore.saveToken(payload.token)
      apiClient.setToken(payload.token)
      localStore.saveRefreshToken(payload.refreshToken)
      apiClient.setRefreshToken(payload.refreshToken)
      this.user = payload.user
      this.signedIn = true
      this.online = true
      return true
    } catch (error) {
      this.showApiError(error)
      return false
    } finally {
      this.busy = false
    }
  }

  private showApiError(error: Error): void {
    if (error instanceof ApiFailure) {
      this.showToast(error.message, true)
      return
    }
    this.online = false
    this.showToast('网络连接失败，请稍后重试', true)
  }

}
