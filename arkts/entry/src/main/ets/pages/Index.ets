import common from '@ohos.app.ability.common'
import { AppRoute, routeByName } from '../navigation/AppRoute'
import { EntryIntent, entryIntentInbox } from '../navigation/EntryIntent'
import { AppStore } from '../state/AppStore'
import { AppColors, AppRadii, AppSpacing } from '../theme/AppTokens'
import { AppIcon, AppIconName } from '../design_system/AppIcon'
import { AuthMode, AuthPage } from './AuthPage'
import { StateGalleryPage } from './GenericPage'
import { CouponsPage, InvitePage, StatisticsPage } from './ProfileDataPages'
import { OrdersPage, SessionsPage } from './AccountDataPages'
import { NotificationPage } from './NotificationPage'
import {
  AccountSecurityPage, ChoicePreferencePage, ProfileEditPage
} from './SettingsActionPages'
import { AboutPage, LegalDocumentPage, LegalPage } from './SettingsLegalPages'
import { AppTabShell } from './AppTabShell'
import { OnboardingPage, SplashPage } from './LaunchPages'
import { CheckoutPage } from './CheckoutPage'
import { MembershipPage } from './ProfilePages'
import { SettingDetailPage, SettingsPage } from './SettingsPages'
import { SettingsUtilityPage } from './SettingsUtilityPage'
import {
  NewSupportTicketPage, ProductFeedbackPage, SupportHomePage, SupportTicketPage
} from './SupportPages'

@Entry
@Component
struct Index {
  @State store: AppStore = new AppStore()

  aboutToAppear(): void {
    // 原生 toast 需要 UIContext（顶部展示 + 主色文字）；必须在 initialize
    // 之前注入——initialize 里的离线提示就会触发 showToast。
    this.store.attachUIContext(this.getUIContext())
    this.store.initialize(this.getUIContext().getHostContext() as common.UIAbilityContext)
    entryIntentInbox.subscribe(this)
  }

  aboutToDisappear(): void {
    entryIntentInbox.unsubscribe(this)
  }

  onEntryIntent(intent: EntryIntent): void {
    this.store.openEntryByName(intent.routeName, intent.cold)
  }

  onResume(): void {
    this.store.resume()
  }

  private routeFromName(name: string): AppRoute {
    return routeByName(name) ?? AppRoute.Home
  }

  // NavPathStack destination map: each route name → its page, wrapped in a
  // NavDestination so HarmonyOS keeps the source page alive on push (issue #2).
  // 'tabs' 是底部 tab 壳（首页/我的 常驻 Tabs 保活）；其余为子页面/登录/闪屏。
  @Builder
  pageMap(name: string) {
    NavDestination() {
      if (name === 'tabs') {
        AppTabShell({ store: this.store })
      } else if (name === 'Logo' || name === 'Promo') {
        SplashPage({ store: this.store })
      } else if (name === 'Onboarding') {
        OnboardingPage({ store: this.store })
      } else if (name === 'SignIn') {
        AuthPage({ store: this.store, mode: AuthMode.SignIn })
      } else if (name === 'SignUp') {
        AuthPage({ store: this.store, mode: AuthMode.SignUp })
      } else if (name === 'PhoneSignIn') {
        AuthPage({ store: this.store, mode: AuthMode.Phone })
      } else if (name === 'ForgotPassword') {
        AuthPage({ store: this.store, mode: AuthMode.Forgot })
      } else if (name === 'VerifyEmail') {
        AuthPage({ store: this.store, mode: AuthMode.Verify })
      } else if (name === 'ResetPassword') {
        AuthPage({ store: this.store, mode: AuthMode.Reset })
      } else if (name === 'ProfileEdit') {
        ProfileEditPage({ store: this.store })
      } else if (name === 'Statistics') {
        StatisticsPage({ store: this.store, remote: this.store.remote })
      } else if (name === 'Invite') {
        InvitePage({ store: this.store, remote: this.store.remote })
      } else if (name === 'Coupons') {
        CouponsPage({ store: this.store, remote: this.store.remote })
      } else if (name === 'Membership' || name === 'MembershipPlans') {
        MembershipPage({ store: this.store })
      } else if (name === 'Checkout') {
        CheckoutPage({ store: this.store })
      } else if (name === 'Orders') {
        OrdersPage({ store: this.store, remote: this.store.remote })
      } else if (name === 'Settings') {
        SettingsPage({ store: this.store })
      } else if (name === 'AccountSecurity') {
        AccountSecurityPage({ store: this.store })
      } else if (name === 'Devices') {
        SessionsPage({ store: this.store, remote: this.store.remote })
      } else if (name === 'NotificationCenter') {
        NotificationPage({ store: this.store, remote: this.store.remote })
      } else if (name === 'Appearance' || name === 'Language' || name === 'TextSize') {
        ChoicePreferencePage({ store: this.store, route: this.routeFromName(name) })
      } else if (name === 'Legal') {
        LegalPage({ store: this.store })
      } else if (name === 'TermsOfService') {
        LegalDocumentPage({ store: this.store, type: 'terms' })
      } else if (name === 'PrivacyPolicy') {
        LegalDocumentPage({ store: this.store, type: 'privacy' })
      } else if (name === 'About') {
        AboutPage({ store: this.store })
      } else if (name === 'Storage' || name === 'Permissions') {
        SettingsUtilityPage({ store: this.store, route: this.routeFromName(name) })
      } else if (name === 'HelpFeedback') {
        SupportHomePage({ store: this.store, remote: this.store.remote })
      } else if (name === 'SupportTicket') {
        SupportTicketPage({ store: this.store, remote: this.store.remote })
      } else if (name === 'NewSupportTicket') {
        NewSupportTicketPage({ store: this.store })
      } else if (name === 'ProductFeedback') {
        ProductFeedbackPage({ store: this.store })
      } else if (name === 'StateGallery') {
        StateGalleryPage({ store: this.store })
      } else if (name === 'DeleteAccount' || name === 'NotificationSettings' ||
        name === 'Privacy' || name === 'General') {
        // 通用设置路由（注销账号 / 通知 / 隐私分析 / 通用开关）走 SettingDetailPage。
        SettingDetailPage({ store: this.store, route: this.routeFromName(name) })
      } else {
        // 未注册路由：明确 404 提示，避免静默落到错误页（issue #9）。
        Column() {
          Text(`页面不存在（${name}）`).fontSize(16).fontColor(AppColors.textSecondary)
        }.width('100%').height('100%').justifyContent(FlexAlign.Center)
      }
    }
    .hideTitleBar(true)
    .onBackPressed(() => {
      this.store.back()
      return true
    })
  }

  build() {
    Navigation(this.store.navStack) {
    }
    .navDestination(this.pageMap)
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
    .width('100%').height('100%').backgroundColor(AppColors.background)
  }
}
