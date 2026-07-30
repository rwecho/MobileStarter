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
  about,
  deleteAccount,
  notificationCenter,
  stateGallery,
}

// Resolves a notification deep-link route name back to the enum. External URLs
// (containing "://") and unknown names are ignored, mirroring the RN guard.
AppRoute? appRouteFromName(String? name) {
  if (name == null || name.isEmpty || name.contains('://')) return null;
  for (final route in AppRoute.values) {
    if (route.name == name) return route;
  }
  return null;
}
