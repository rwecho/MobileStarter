import common from '@ohos.app.ability.common'
import { UIContext } from '@ohos.arkui.UIContext'
import { AppColors } from '../theme/AppTokens'
import { ConfigurationConstant } from '@kit.AbilityKit'
import { apiClient, ApiFailure } from '../data/ApiClient'
import { localStore } from '../data/LocalStore'
import { AppUser, OrderView, PurchaseStatus, RuntimeConfig } from '../domain/Models'
import { RemoteDataStore } from './RemoteDataStore'
import { telemetry, TelemetryConfig } from '../telemetry/Telemetry'
import { AppTelemetrySink } from '../telemetry/AppTelemetrySink'
import { AppRoute, routeName } from '../navigation/AppRoute'
import { initAppStrings } from '../localization/AppStrings'
import {
  backAction,
  navigateByNameAction,
  navigateAction,
  openEntryByNameAction,
  replaceAllAction,
  replaceTopAction
} from './AppNavActions'
import {
  requestPasswordResetAction,
  requestPhoneCodeAction,
  resetPasswordAction,
  signInAction,
  signOutAction,
  signOutAllAction,
  signUpAction,
  socialSignInAction,
  verifyEmailAction,
  verifyPasswordResetAction,
  verifyPhoneCodeAction,
  handleSessionExpiredAction
} from './AppAuthActions'
import {
  changePasswordAction,
  createTicketAction,
  deleteAccountAction,
  replyTicketAction,
  saveSettingAction,
  submitFeedbackAction,
  updateProfileAction,
  cacheUserPreferences
} from './AppAccountActions'
import { purchaseAction, startCheckoutAction } from './AppPaymentActions'

// 应用状态仓库。方法体按域拆分到 App*Actions / AppRouteTable（CI 350 行硬上限；
// ArkTS 无 partial class，动作是收 store 的自由函数，这里只留字段、引导与薄委托）。
// 原 private 成员（context/initialized/queuedEntry*/applyPreferences/showApiError）
// 因动作模块需访问而去私有化——ArkTS 无包内私有，勿在 state/ 动作模块之外调用。
@Observed
export class AppStore {
  navStack: NavPathStack = new NavPathStack()
  currentRoute: AppRoute = AppRoute.Logo
  // 底部 tab：0=首页, 1=我的。首页/我的 常驻在一个 'tabs' NavDestination 里用
  // Tabs 组件保活（切换无转场、不重建），navStack 只承载子页面/登录/闪屏。
  currentTab: number = 0
  signedIn: boolean = false
  online: boolean = true
  // bootstrapped：初始 bootstrap 是否完成（成功或失败）；品牌闪屏据此判断"配置拉取完成"。
  bootstrapped: boolean = false
  // localReady：本地启动数据（preferences + 磁盘缓存 config）已就绪。SplashPage 进首页
  // 只等它、不等网络（issue #24：冷启动时延 = 磁盘读取，通常 <20ms）。
  localReady: boolean = false
  busy: boolean = false
  theme: string = 'system'
  language: string = 'zh-CN'
  textScale: number = 1
  config: RuntimeConfig | null = null
  user: AppUser | null = null
  // 最近一次认证失败的错误信息（内联显示在表单字段下方，见 AuthPage）。
  // 认证成功后清空；输入变化时由页面清空。
  lastAuthError: string = ''
  authProviders: Record<string, boolean> = {}
  authProviderPolicy: Record<string, boolean> = {}
  authProviderConfig: Record<string, Object> = {}
  recoveryEmail: string = ''
  resetToken: string = ''
  pendingRoute: AppRoute | null = null
  // payment
  purchaseStatus: PurchaseStatus = PurchaseStatus.Idle
  purchaseOrder: OrderView | null = null
  purchaseMessage: string = ''
  pendingPlanId: string = ''
  // True on a device with HMS Core + AppGallery Connect product config; drives
  // the production HMS IAP provider instead of the dev mock.
  useHmsIap: boolean = false
  remote: RemoteDataStore = new RemoteDataStore()
  context: common.UIAbilityContext | null = null
  initialized: boolean = false
  queuedEntryName: string | null = null
  queuedEntryCold: boolean = false

  constructor() {
    // Seed the nav stack with the splash route so Navigation renders SplashPage
    // immediately (before bootstrap). pushPath on a detached NavPathStack is safe.
    this.navStack.pushPath({ name: routeName(AppRoute.Logo) })
  }

  async initialize(context: common.UIAbilityContext): Promise<void> {
    this.context = context
    initAppStrings(context)
    await localStore.initialize(context)
    this.applyPreferences()
    apiClient.setInstallationId(localStore.installationId())
    const cached = localStore.readConfig()
    if (cached !== null) {
      this.config = cached
    }
    // 网络 bootstrap 之前置位：进首页不等网络，只等磁盘（issue #24）。
    this.localReady = true
    const token = localStore.readToken()
    apiClient.setToken(token)
    apiClient.setRefreshToken(localStore.readRefreshToken())
    // 静默刷新轮换出的新 token 对必须落盘：transport 只更新内存，不落盘则
    // 重启后读到已轮换的旧 refresh token，服务端复用检测（REFRESH_TOKEN_REUSED）
    // 会吊销整个会话 → 使用中被踢回登录页。
    apiClient.setTokenPersistHandler((token: string, refreshToken: string): void => {
      localStore.saveToken(token)
      localStore.saveRefreshToken(refreshToken)
    })
    apiClient.setSessionExpiredCallback(() => { handleSessionExpiredAction(this) })
    // 磁盘快照注入 + 启动恢复（必须在 configureTelemetry 之前，issue #22）。
    telemetry.setPersistence(
      (): string | null => localStore.readTelemetryQueue(),
      (json: string): void => localStore.saveTelemetryQueue(json)
    )
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
      cacheUserPreferences(this)
    } catch (error) {
      this.online = false
      this.showToast('当前使用离线配置', true)
    }
    this.configureTelemetry()
    this.applyPreferences()
    this.initialized = true
    this.bootstrapped = true
    if (this.queuedEntryName !== null) {
      const name = this.queuedEntryName
      const cold = this.queuedEntryCold
      this.queuedEntryName = null
      this.openEntryByName(name, cold)
    }
  }

  configureTelemetry(): void {
    const config = new TelemetryConfig()
    config.configVersion = this.config?.version ?? 0
    telemetry.configure(config, new AppTelemetrySink())
  }

  applyPreferences(): void {
    if (this.context === null) return
    const theme = localStore.readTheme()
    const language = localStore.readLanguage() === 'en-US' ? 'en-US' : 'zh-CN'
    const textScale = Math.min(1.3, Math.max(0.9, localStore.readTextScale()))
    this.theme = theme
    this.language = language
    this.textScale = textScale
    const colorMode = theme === 'dark'
      ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK
      : theme === 'light'
        ? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
        : ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET
    const application = this.context.getApplicationContext()
    application.setColorMode(colorMode)
    application.setLanguage(language)
    application.setFontSizeScale(textScale)
    apiClient.setLanguage(language)
  }

  get route(): AppRoute {
    return this.currentRoute
  }

  get canGoBack(): boolean {
    return this.navStack.size() > 1
  }

  navigate(route: AppRoute): void {
    navigateAction(this, route)
  }

  // Resolves an in-app route name (from a notification deep link) back to the
  // enum and navigates; external URLs and unknown names are ignored.
  navigateByName(name: string | null): void {
    navigateByNameAction(this, name)
  }

  openEntryByName(name: string | null, cold: boolean): void {
    openEntryByNameAction(this, name, cold)
  }

  resume(): void {
    this.applyPreferences()
  }

  // 底部 tab 的 NavDestination 名称：首页/我的 常驻其中，用 Tabs 保活。
  static readonly TAB_NAME: string = 'tabs'

  replaceAll(route: AppRoute): void {
    replaceAllAction(this, route)
  }

  replaceTop(route: AppRoute): void {
    replaceTopAction(this, route)
  }

  completeAuthentication(): void {
    const target = this.pendingRoute ?? AppRoute.Home
    this.pendingRoute = null
    this.replaceTop(target)
  }

  back(): void {
    backAction(this)
  }

  signIn(email: string, password: string): Promise<boolean> {
    return signInAction(this, email, password)
  }

  signUp(email: string, password: string, username: string, consentVersion: string):
    Promise<boolean> {
    return signUpAction(this, email, password, username, consentVersion)
  }

  verifyEmail(code: string): Promise<boolean> {
    return verifyEmailAction(this, code)
  }

  requestPhoneCode(phone: string): Promise<boolean> {
    return requestPhoneCodeAction(this, phone)
  }

  verifyPhoneCode(phone: string, code: string): Promise<boolean> {
    return verifyPhoneCodeAction(this, phone, code)
  }

  socialSignIn(
    provider: string, idToken: string, authorizationCode: string,
    redirectUri: string, codeVerifier: string
  ): Promise<boolean> {
    return socialSignInAction(this, provider, idToken, authorizationCode, redirectUri, codeVerifier)
  }

  requestPasswordReset(email: string): Promise<boolean> {
    return requestPasswordResetAction(this, email)
  }

  verifyPasswordReset(code: string): Promise<boolean> {
    return verifyPasswordResetAction(this, code)
  }

  resetPassword(newPassword: string): Promise<boolean> {
    return resetPasswordAction(this, newPassword)
  }

  signOut(): Promise<void> {
    return signOutAction(this)
  }

  signOutAll(): Promise<void> {
    return signOutAllAction(this)
  }

  saveSetting(key: string, value: string | number | boolean): Promise<boolean> {
    return saveSettingAction(this, key, value)
  }

  deleteAccount(password: string): Promise<boolean> {
    return deleteAccountAction(this, password)
  }

  changePassword(currentPassword: string, newPassword: string): Promise<boolean> {
    return changePasswordAction(this, currentPassword, newPassword)
  }

  updateProfile(displayName: string, bio: string, avatarUrl: string | null): Promise<boolean> {
    return updateProfileAction(this, displayName, bio, avatarUrl)
  }

  submitFeedback(
    title: string, body: string, category: string = 'suggestion', rating: number = 5
  ): Promise<boolean> {
    return submitFeedbackAction(this, title, body, category, rating)
  }

  createTicket(
    category: string, severity: string, subject: string, message: string
  ): Promise<boolean> {
    return createTicketAction(this, category, severity, subject, message)
  }

  replyTicket(message: string): Promise<boolean> {
    return replyTicketAction(this, message)
  }

  purchase(planId: string): Promise<boolean> {
    return purchaseAction(this, planId)
  }

  startCheckout(planId: string): void {
    startCheckoutAction(this, planId)
  }

  // 原生 toast（系统级）：顶部展示、文字用主色（错误用语义红）。
  // UIContext 由 Index 挂载时注入（attachUIContext）；极早期未注入时静默跳过。
  private uiContext: UIContext | null = null

  attachUIContext(ui: UIContext): void {
    this.uiContext = ui
  }

  showToast(message: string, error: boolean = false): void {
    if (this.uiContext === null) return
    this.uiContext.getPromptAction().showToast({
      message: message,
      duration: 2000,
      alignment: Alignment.Top,
      textColor: error ? AppColors.error : AppColors.brand,
      backgroundColor: AppColors.surface
    })
  }

  showApiError(error: Error): void {
    // 错误统一出口：用户可见的 API 错误必须进遥测（此前只 toast，
    // catch 分支的错误永远查不到）。
    telemetry.report(error)
    if (error instanceof ApiFailure) {
      this.showToast(error.message, true)
      return
    }
    this.online = false
    this.showToast('网络连接失败，请稍后重试', true)
  }
}
