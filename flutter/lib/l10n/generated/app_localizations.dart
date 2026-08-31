import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @authTagline.
  ///
  /// In zh, this message translates to:
  /// **'安全同步你的会员、订单与偏好设置。'**
  String get authTagline;

  /// No description provided for @authSignInTitle.
  ///
  /// In zh, this message translates to:
  /// **'欢迎回来'**
  String get authSignInTitle;

  /// No description provided for @authSignInAction.
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get authSignInAction;

  /// No description provided for @authSignUpTitle.
  ///
  /// In zh, this message translates to:
  /// **'创建账号'**
  String get authSignUpTitle;

  /// No description provided for @authSignUpAction.
  ///
  /// In zh, this message translates to:
  /// **'注册'**
  String get authSignUpAction;

  /// No description provided for @authPhoneTitle.
  ///
  /// In zh, this message translates to:
  /// **'手机号登录'**
  String get authPhoneTitle;

  /// No description provided for @authPhoneAction.
  ///
  /// In zh, this message translates to:
  /// **'发送验证码'**
  String get authPhoneAction;

  /// No description provided for @authForgotTitle.
  ///
  /// In zh, this message translates to:
  /// **'找回密码'**
  String get authForgotTitle;

  /// No description provided for @authForgotAction.
  ///
  /// In zh, this message translates to:
  /// **'发送验证码'**
  String get authForgotAction;

  /// No description provided for @authVerifyTitle.
  ///
  /// In zh, this message translates to:
  /// **'验证邮箱'**
  String get authVerifyTitle;

  /// No description provided for @authVerifyAction.
  ///
  /// In zh, this message translates to:
  /// **'确认验证码'**
  String get authVerifyAction;

  /// No description provided for @authResetTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置新密码'**
  String get authResetTitle;

  /// No description provided for @authResetAction.
  ///
  /// In zh, this message translates to:
  /// **'确认修改'**
  String get authResetAction;

  /// No description provided for @authProcessing.
  ///
  /// In zh, this message translates to:
  /// **'正在处理…'**
  String get authProcessing;

  /// No description provided for @authVerifyAndSignIn.
  ///
  /// In zh, this message translates to:
  /// **'验证并登录'**
  String get authVerifyAndSignIn;

  /// No description provided for @authForgotPassword.
  ///
  /// In zh, this message translates to:
  /// **'忘记密码'**
  String get authForgotPassword;

  /// No description provided for @authCreateAccount.
  ///
  /// In zh, this message translates to:
  /// **'创建账号'**
  String get authCreateAccount;

  /// No description provided for @authUsername.
  ///
  /// In zh, this message translates to:
  /// **'用户名'**
  String get authUsername;

  /// No description provided for @authUsernameMinLength.
  ///
  /// In zh, this message translates to:
  /// **'用户名至少 2 个字符'**
  String get authUsernameMinLength;

  /// No description provided for @authPhone.
  ///
  /// In zh, this message translates to:
  /// **'手机号'**
  String get authPhone;

  /// No description provided for @authAccountPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'用户名、邮箱或手机号'**
  String get authAccountPlaceholder;

  /// No description provided for @authEmail.
  ///
  /// In zh, this message translates to:
  /// **'邮箱'**
  String get authEmail;

  /// No description provided for @authEmailRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入邮箱'**
  String get authEmailRequired;

  /// No description provided for @authEmailInvalid.
  ///
  /// In zh, this message translates to:
  /// **'邮箱格式不正确'**
  String get authEmailInvalid;

  /// No description provided for @authAccountRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入用户名、邮箱或手机号'**
  String get authAccountRequired;

  /// No description provided for @authPassword.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get authPassword;

  /// No description provided for @authPasswordRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入密码'**
  String get authPasswordRequired;

  /// No description provided for @authPasswordMinLength.
  ///
  /// In zh, this message translates to:
  /// **'密码至少 8 位'**
  String get authPasswordMinLength;

  /// No description provided for @authCode.
  ///
  /// In zh, this message translates to:
  /// **'验证码'**
  String get authCode;

  /// No description provided for @authConsentLabel.
  ///
  /// In zh, this message translates to:
  /// **'登录与注册协议确认'**
  String get authConsentLabel;

  /// No description provided for @authConsentPrefix.
  ///
  /// In zh, this message translates to:
  /// **'我已阅读并同意'**
  String get authConsentPrefix;

  /// No description provided for @authTerms.
  ///
  /// In zh, this message translates to:
  /// **'用户协议'**
  String get authTerms;

  /// No description provided for @authConsentMiddle.
  ///
  /// In zh, this message translates to:
  /// **'与'**
  String get authConsentMiddle;

  /// No description provided for @authPrivacy.
  ///
  /// In zh, this message translates to:
  /// **'隐私政策'**
  String get authPrivacy;

  /// No description provided for @authConsentRequired.
  ///
  /// In zh, this message translates to:
  /// **'请先阅读并同意用户协议与隐私政策'**
  String get authConsentRequired;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
