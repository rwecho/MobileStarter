enum AppRoute {
  logo,
  promo,
  onboarding,
  home,
  signIn,
  signUp,
  phoneSignIn,
  forgotPassword,
  verifyEmail,
  resetPassword,
  profile,
  profileEdit,
  statistics,
  invite,
  coupons,
  membership,
  membershipPlans,
  checkout,
  orders,
  settings,
  accountSecurity,
  devices,
  notificationSettings,
  privacy,
  general,
  appearance,
  language,
  textSize,
  storage,
  permissions,
  helpFeedback,
  supportNewTicket,
  supportTicket,
  supportFeedback,
  legal,
  termsOfService,
  privacyPolicy,
  about,
  deleteAccount,
  notificationCenter,
  stateGallery,
}

// Resolves a notification deep-link route name back to the enum. External URLs
// (containing "://") and unknown names are ignored, mirroring the RN guard.
AppRoute? appRouteFromName(String? name) {
  if (name == null || name.isEmpty || name.contains('://')) return null;
  final alias = _routeAliases[name];
  if (alias != null) return alias;
  for (final route in AppRoute.values) {
    if (route.name.toLowerCase() == name.toLowerCase()) return route;
  }
  return null;
}

const _routeAliases = <String, AppRoute>{
  'notifications.center': AppRoute.notificationCenter,
  'profile.home': AppRoute.profile,
  'profile.edit': AppRoute.profileEdit,
  'profile.statistics': AppRoute.statistics,
  'profile.invite': AppRoute.invite,
  'profile.coupons': AppRoute.coupons,
  'membership.home': AppRoute.membership,
  'membership.plans': AppRoute.membershipPlans,
  'membership.checkout': AppRoute.checkout,
  'membership.orders': AppRoute.orders,
  'settings.home': AppRoute.settings,
  'settings.accountSecurity': AppRoute.accountSecurity,
  'settings.devices': AppRoute.devices,
  'settings.notifications': AppRoute.notificationSettings,
  'settings.privacy': AppRoute.privacy,
  'settings.general': AppRoute.general,
  'settings.appearance': AppRoute.appearance,
  'settings.language': AppRoute.language,
  'settings.textSize': AppRoute.textSize,
  'settings.storage': AppRoute.storage,
  'settings.permissions': AppRoute.permissions,
  'settings.helpFeedback': AppRoute.helpFeedback,
  'settings.legal': AppRoute.legal,
  'settings.termsOfService': AppRoute.termsOfService,
  'settings.privacyPolicy': AppRoute.privacyPolicy,
  'settings.about': AppRoute.about,
  'support.home': AppRoute.helpFeedback,
  'support.newTicket': AppRoute.supportNewTicket,
};
