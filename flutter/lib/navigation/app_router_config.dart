import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_controller.dart';
import '../navigation/app_route.dart';
import '../navigation/app_route_paths.dart';
import '../navigation/route_guard.dart';
import '../navigation/route_observer.dart';
import '../navigation/shell_scaffold.dart';
import '../screens/account_security_screen.dart';
import '../screens/auth_screens.dart';
import '../screens/checkout_screen.dart';
import '../screens/coupons_screen.dart';
import '../screens/delete_account_screen.dart';
import '../screens/home_screen.dart';
import '../screens/invite_screen.dart';
import '../screens/launch_screens.dart';
import '../screens/legal_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/orders_screen.dart';
import '../screens/preference_screen.dart';
import '../screens/profile_edit_screen.dart';
import '../screens/profile_screens.dart';
import '../screens/sessions_screen.dart';
import '../screens/settings_screens.dart';
import '../screens/settings_utility_screen.dart';
import '../screens/state_gallery_screen.dart';
import '../screens/statistics_screen.dart';
import '../screens/support_form_screens.dart';
import '../screens/support_home_screen.dart';
import '../screens/text_size_screen.dart';

/// Builds the app's GoRouter. `controller` drives auth state (redirect uses
/// `signedIn`/`config`); `routerRefresh` re-evaluates redirects when it fires.
GoRouter buildAppRouter(
  AppController controller, {
  Listenable? routerRefresh,
}) {
  final routeObserver = AppRouteObserver();

  // Note: go_router 14.x renamed the constructor param to `observers`
  // (NavigatorObserver list) — `navigatorObservers` no longer exists.
  return GoRouter(
    observers: [routeObserver],
    refreshListenable: routerRefresh,
    redirect: (context, state) {
      final route = _routeFor(state.uri);
      if (route == null) return null;
      final decision = guardRoute(
        route,
        signedIn: controller.signedIn,
        config: controller.config,
      );
      if (decision.unavailable) return pathFor(AppRoute.home);
      if (decision.pending != null) {
        // Remember what the user was trying to reach so the auth screens can
        // resume it after a successful login (see consumeAuthRedirectTarget).
        controller.setAuthRedirectTarget(route);
        return pathFor(AppRoute.signIn);
      }
      return null;
    },
    routes: [
      GoRoute(
        path: pathFor(AppRoute.logo),
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: pathFor(AppRoute.promo),
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: pathFor(AppRoute.onboarding),
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: pathFor(AppRoute.signIn),
        builder: (context, state) => const AuthScreen(mode: AuthMode.signIn),
      ),
      GoRoute(
        path: pathFor(AppRoute.signUp),
        builder: (context, state) => const AuthScreen(mode: AuthMode.signUp),
      ),
      GoRoute(
        path: pathFor(AppRoute.phoneSignIn),
        builder: (context, state) => const AuthScreen(mode: AuthMode.phone),
      ),
      GoRoute(
        path: pathFor(AppRoute.forgotPassword),
        builder: (context, state) => const AuthScreen(mode: AuthMode.forgot),
      ),
      GoRoute(
        path: pathFor(AppRoute.verifyEmail),
        builder: (context, state) => const AuthScreen(mode: AuthMode.verify),
      ),
      GoRoute(
        path: pathFor(AppRoute.resetPassword),
        builder: (context, state) => const AuthScreen(mode: AuthMode.reset),
      ),
      GoRoute(
        path: pathFor(AppRoute.notificationCenter),
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: pathFor(AppRoute.deleteAccount),
        builder: (context, state) => const DeleteAccountScreen(),
      ),
      GoRoute(
        path: pathFor(AppRoute.stateGallery),
        builder: (context, state) => const StateGalleryScreen(),
      ),
      GoRoute(
        path: pathFor(AppRoute.accountSecurity),
        builder: (context, state) => const AccountSecurityScreen(),
      ),
      GoRoute(
        path: pathFor(AppRoute.helpFeedback),
        builder: (context, state) => const SupportHomeScreen(),
      ),
      GoRoute(
        path: pathFor(AppRoute.supportNewTicket),
        builder: (context, state) => const NewSupportTicketScreen(),
      ),
      GoRoute(
        path: pathFor(AppRoute.supportTicket),
        builder: (context, state) => const SupportTicketScreen(),
      ),
      GoRoute(
        path: pathFor(AppRoute.supportFeedback),
        builder: (context, state) => const ProductFeedbackScreen(),
      ),
      GoRoute(
        path: pathFor(AppRoute.legal),
        builder: (context, state) => const LegalScreen(),
      ),
      GoRoute(
        path: pathFor(AppRoute.termsOfService),
        builder: (context, state) =>
            const LegalDocumentScreen(type: 'terms'),
      ),
      GoRoute(
        path: pathFor(AppRoute.privacyPolicy),
        builder: (context, state) =>
            const LegalDocumentScreen(type: 'privacy'),
      ),
      GoRoute(
        path: pathFor(AppRoute.profileEdit),
        builder: (context, state) => const ProfileEditScreen(),
      ),
      GoRoute(
        path: pathFor(AppRoute.statistics),
        builder: (context, state) => const StatisticsScreen(),
      ),
      GoRoute(
        path: pathFor(AppRoute.invite),
        builder: (context, state) => const InviteScreen(),
      ),
      GoRoute(
        path: pathFor(AppRoute.coupons),
        builder: (context, state) => const CouponsScreen(),
      ),
      GoRoute(
        path: pathFor(AppRoute.checkout),
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
        path: pathFor(AppRoute.orders),
        builder: (context, state) => const OrdersScreen(),
      ),
      GoRoute(
        path: pathFor(AppRoute.settings),
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: pathFor(AppRoute.membership),
        builder: (context, state) => const MembershipScreen(),
      ),
      GoRoute(
        path: pathFor(AppRoute.membershipPlans),
        builder: (context, state) => const MembershipScreen(),
      ),
      GoRoute(
        path: pathFor(AppRoute.devices),
        builder: (context, state) => const SessionsScreen(),
      ),
      GoRoute(
        path: pathFor(AppRoute.notificationSettings),
        builder: (context, state) => const PreferenceScreen(
          kind: PreferenceKind.notifications,
          title: '通知设置',
        ),
      ),
      GoRoute(
        path: pathFor(AppRoute.privacy),
        builder: (context, state) =>
            const PreferenceScreen(kind: PreferenceKind.privacy, title: '隐私设置'),
      ),
      GoRoute(
        path: pathFor(AppRoute.general),
        builder: (context, state) =>
            const PreferenceScreen(kind: PreferenceKind.general, title: '通用设置'),
      ),
      GoRoute(
        path: pathFor(AppRoute.appearance),
        builder: (context, state) => const PreferenceScreen(
          kind: PreferenceKind.appearance,
          title: '外观主题',
        ),
      ),
      GoRoute(
        path: pathFor(AppRoute.language),
        builder: (context, state) =>
            const PreferenceScreen(kind: PreferenceKind.language, title: '语言'),
      ),
      GoRoute(
        path: pathFor(AppRoute.textSize),
        builder: (context, state) => const TextSizeScreen(),
      ),
      GoRoute(
        path: pathFor(AppRoute.storage),
        builder: (context, state) =>
            const SettingsUtilityScreen(kind: SettingsUtilityKind.storage),
      ),
      GoRoute(
        path: pathFor(AppRoute.permissions),
        builder: (context, state) =>
            const SettingsUtilityScreen(kind: SettingsUtilityKind.permissions),
      ),
      GoRoute(
        path: pathFor(AppRoute.about),
        builder: (context, state) =>
            const SettingsUtilityScreen(kind: SettingsUtilityKind.about),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ShellScaffold(navigationShell: navigationShell),
        branches: [
          // NOTE: do NOT add a shared NavigatorObserver to branches — a single
          // observer instance can only attach to ONE navigator (NavigatorState
          // asserts observer.navigator == null), so sharing it across the root
          // + branch navigators crashes. Tab-switch telemetry is emitted from
          // ShellScaffold._goBranch instead.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: pathFor(AppRoute.home),
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: pathFor(AppRoute.profile),
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// Maps a URI back to an [AppRoute] (for redirect + entry-intent). Returns
/// null for unknown paths so redirect can leave them alone.
AppRoute? _routeFor(Uri uri) {
  final path = uri.path.isEmpty ? '/' : uri.path;
  for (final entry in appRoutePaths.entries) {
    if (entry.value == path) return entry.key;
  }
  return null;
}

/// Warm entry: push a named route onto the current stack (e.g. notification tap).
void openEntryWarm(GoRouter router, AppRoute target) =>
    router.push(pathFor(target));
