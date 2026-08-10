import 'package:flutter/widgets.dart';
import '../navigation/app_route.dart';
import '../screens/auth_screens.dart';
import '../screens/account_security_screen.dart';
import '../screens/checkout_screen.dart';
import '../screens/coupons_screen.dart';
import '../screens/delete_account_screen.dart';
import '../screens/home_screen.dart';
import '../screens/invite_screen.dart';
import '../screens/launch_screens.dart';
import '../screens/notifications_screen.dart';
import '../screens/orders_screen.dart';
import '../screens/profile_edit_screen.dart';
import '../screens/profile_screens.dart';
import '../screens/legal_screen.dart';
import '../screens/preference_screen.dart';
import '../screens/sessions_screen.dart';
import '../screens/settings_screens.dart';
import '../screens/settings_utility_screen.dart';
import '../screens/statistics_screen.dart';
import '../screens/state_gallery_screen.dart';
import '../screens/support_form_screens.dart';
import '../screens/support_home_screen.dart';
import '../screens/text_size_screen.dart';

abstract final class AppRouter {
  static Widget screenFor(AppRoute route) {
    return switch (route) {
      AppRoute.logo => const SplashScreen(),
      AppRoute.promo => const SplashScreen(),
      AppRoute.onboarding => const OnboardingScreen(),
      AppRoute.home => const HomeScreen(),
      AppRoute.signIn => const AuthScreen(mode: AuthMode.signIn),
      AppRoute.signUp => const AuthScreen(mode: AuthMode.signUp),
      AppRoute.phoneSignIn => const AuthScreen(mode: AuthMode.phone),
      AppRoute.forgotPassword => const AuthScreen(mode: AuthMode.forgot),
      AppRoute.verifyEmail => const AuthScreen(mode: AuthMode.verify),
      AppRoute.resetPassword => const AuthScreen(mode: AuthMode.reset),
      AppRoute.profile => const ProfileScreen(),
      AppRoute.membership => const MembershipScreen(),
      AppRoute.settings => const SettingsScreen(),
      AppRoute.deleteAccount => const DeleteAccountScreen(),
      AppRoute.stateGallery => const StateGalleryScreen(),
      AppRoute.accountSecurity => const AccountSecurityScreen(),
      AppRoute.devices => const SessionsScreen(),
      AppRoute.notificationSettings => const PreferenceScreen(
        kind: PreferenceKind.notifications,
        title: '通知设置',
      ),
      AppRoute.privacy => const PreferenceScreen(
        kind: PreferenceKind.privacy,
        title: '隐私设置',
      ),
      AppRoute.general => const PreferenceScreen(
        kind: PreferenceKind.general,
        title: '通用设置',
      ),
      AppRoute.appearance => const PreferenceScreen(
        kind: PreferenceKind.appearance,
        title: '外观主题',
      ),
      AppRoute.language => const PreferenceScreen(
        kind: PreferenceKind.language,
        title: '语言',
      ),
      AppRoute.textSize => const TextSizeScreen(),
      AppRoute.storage => const SettingsUtilityScreen(
        kind: SettingsUtilityKind.storage,
      ),
      AppRoute.permissions => const SettingsUtilityScreen(
        kind: SettingsUtilityKind.permissions,
      ),
      AppRoute.helpFeedback => const SupportHomeScreen(),
      AppRoute.supportNewTicket => const NewSupportTicketScreen(),
      AppRoute.supportTicket => const SupportTicketScreen(),
      AppRoute.supportFeedback => const ProductFeedbackScreen(),
      AppRoute.legal => const LegalScreen(),
      AppRoute.termsOfService => const LegalDocumentScreen(type: 'terms'),
      AppRoute.privacyPolicy => const LegalDocumentScreen(type: 'privacy'),
      AppRoute.about => const SettingsUtilityScreen(
        kind: SettingsUtilityKind.about,
      ),
      AppRoute.profileEdit => const ProfileEditScreen(),
      AppRoute.statistics => const StatisticsScreen(),
      AppRoute.invite => const InviteScreen(),
      AppRoute.coupons => const CouponsScreen(),
      AppRoute.membershipPlans => const MembershipScreen(),
      AppRoute.checkout => const CheckoutScreen(),
      AppRoute.orders => const OrdersScreen(),
      AppRoute.notificationCenter => const NotificationsScreen(),
    };
  }
}
