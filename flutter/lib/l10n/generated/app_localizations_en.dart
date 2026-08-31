// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get authTagline =>
      'Sync your membership, orders and preferences securely.';

  @override
  String get authSignInTitle => 'Welcome back';

  @override
  String get authSignInAction => 'Sign in';

  @override
  String get authSignUpTitle => 'Create account';

  @override
  String get authSignUpAction => 'Sign up';

  @override
  String get authPhoneTitle => 'Phone sign-in';

  @override
  String get authPhoneAction => 'Send code';

  @override
  String get authForgotTitle => 'Reset password';

  @override
  String get authForgotAction => 'Send code';

  @override
  String get authVerifyTitle => 'Verify email';

  @override
  String get authVerifyAction => 'Confirm code';

  @override
  String get authResetTitle => 'Set new password';

  @override
  String get authResetAction => 'Confirm change';

  @override
  String get authProcessing => 'Working…';

  @override
  String get authVerifyAndSignIn => 'Verify & sign in';

  @override
  String get authForgotPassword => 'Forgot password';

  @override
  String get authCreateAccount => 'Create account';

  @override
  String get authUsername => 'Username';

  @override
  String get authUsernameMinLength => 'Username needs at least 2 characters';

  @override
  String get authPhone => 'Phone number';

  @override
  String get authAccountPlaceholder => 'Username, email or phone';

  @override
  String get authEmail => 'Email';

  @override
  String get authEmailRequired => 'Enter your email';

  @override
  String get authEmailInvalid => 'Invalid email address';

  @override
  String get authAccountRequired => 'Enter your username, email or phone';

  @override
  String get authPassword => 'Password';

  @override
  String get authPasswordRequired => 'Enter your password';

  @override
  String get authPasswordMinLength => 'Password needs at least 8 characters';

  @override
  String get authCode => 'Verification code';

  @override
  String get authConsentLabel => 'Terms consent for sign-in and sign-up';

  @override
  String get authConsentPrefix => 'I have read and agree to the';

  @override
  String get authTerms => 'Terms of Service';

  @override
  String get authConsentMiddle => 'and';

  @override
  String get authPrivacy => 'Privacy Policy';

  @override
  String get authConsentRequired =>
      'Please read and agree to the Terms and Privacy Policy first';
}
