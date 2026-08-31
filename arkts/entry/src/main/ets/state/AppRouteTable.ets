import { AppRoute } from '../navigation/AppRoute'

// 通知深链携带的路由名 → 路由枚举。
// 从 AppStore.ets 拆出以服从 CI 350 行硬上限。ArkTS 禁止动态枚举索引，
// 所以这是一张显式映射表（此前是 AppStore.ROUTE_BY_NAME，无外部引用方）。
export const ROUTE_BY_NAME: Record<string, AppRoute> = {
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
  'HelpFeedback': AppRoute.HelpFeedback, 'Legal': AppRoute.Legal,
  'TermsOfService': AppRoute.TermsOfService, 'PrivacyPolicy': AppRoute.PrivacyPolicy,
  'About': AppRoute.About,
  'DeleteAccount': AppRoute.DeleteAccount, 'NotificationCenter': AppRoute.NotificationCenter,
  'StateGallery': AppRoute.StateGallery, 'SupportTicket': AppRoute.SupportTicket,
  'NewSupportTicket': AppRoute.NewSupportTicket, 'ProductFeedback': AppRoute.ProductFeedback,
  'notifications.center': AppRoute.NotificationCenter, 'profile.home': AppRoute.Profile,
  'profile.edit': AppRoute.ProfileEdit, 'profile.statistics': AppRoute.Statistics,
  'profile.invite': AppRoute.Invite, 'profile.coupons': AppRoute.Coupons,
  'membership.home': AppRoute.Membership,
  'membership.plans': AppRoute.MembershipPlans, 'orders.list': AppRoute.Orders,
  'membership.checkout': AppRoute.Checkout, 'membership.orders': AppRoute.Orders,
  'settings.home': AppRoute.Settings, 'settings.accountSecurity': AppRoute.AccountSecurity,
  'settings.devices': AppRoute.Devices, 'settings.notifications': AppRoute.NotificationSettings,
  'settings.privacy': AppRoute.Privacy, 'settings.general': AppRoute.General,
  'settings.appearance': AppRoute.Appearance, 'settings.language': AppRoute.Language,
  'settings.textSize': AppRoute.TextSize, 'settings.storage': AppRoute.Storage,
  'settings.permissions': AppRoute.Permissions,
  'settings.helpFeedback': AppRoute.HelpFeedback, 'settings.legal': AppRoute.Legal,
  'settings.termsOfService': AppRoute.TermsOfService,
  'settings.privacyPolicy': AppRoute.PrivacyPolicy,
  'settings.about': AppRoute.About, 'support.home': AppRoute.HelpFeedback,
  'support.newTicket': AppRoute.NewSupportTicket
}
