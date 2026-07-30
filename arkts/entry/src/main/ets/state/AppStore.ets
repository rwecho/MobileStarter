import common from '@ohos.app.ability.common'
import { apiClient, ApiFailure } from '../data/ApiClient'
import { localStore } from '../data/LocalStore'
import { AppUser, AuthPayload, RuntimeConfig } from '../domain/Models'
import { RemoteDataStore } from './RemoteDataStore'
import { AppRoute } from '../navigation/AppRoute'
import { telemetry } from '../telemetry/Telemetry'
import { guardRoute } from '../navigation/RouteGuard'

@Observed
export class AppStore {
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
    try {
      const payload = await apiClient.bootstrap()
      this.config = payload.config
      this.user = payload.user
      this.authProviders = payload.authProviders
      this.authProviderPolicy = payload.authProviderPolicy
      this.signedIn = payload.user !== null
      this.online = true
      localStore.saveConfig(payload.config)
    } catch (error) {
      this.online = false
      this.showToast('当前使用离线配置', true)
    }
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
    if (decision.unavailable) this.showToast('å½“å‰ App æœªå¯ç”¨æ­¤åŠŸèƒ½')
    this.routeStack = [...this.routeStack, decision.route]
    telemetry.screen(decision.route.toString())
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

  async signUp(email: string, password: string, username: string): Promise<boolean> {
    return this.authenticate(() => apiClient.signUp(email, password, username))
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
    localStore.saveToken('')
    apiClient.setToken('')
    this.signedIn = false
    this.user = null
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
      localStore.saveToken('')
      apiClient.setToken('')
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
      localStore.saveToken('')
      apiClient.setToken('')
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

  async submitFeedback(title: string, body: string): Promise<boolean> {
    if (this.busy) return false
    this.busy = true
    try {
      const submitted = await apiClient.submitFeedback(title, body)
      if (submitted) this.showToast('意见反馈已提交')
      return submitted
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
