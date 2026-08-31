// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get authTagline => '安全同步你的会员、订单与偏好设置。';

  @override
  String get authSignInTitle => '欢迎回来';

  @override
  String get authSignInAction => '登录';

  @override
  String get authSignUpTitle => '创建账号';

  @override
  String get authSignUpAction => '注册';

  @override
  String get authPhoneTitle => '手机号登录';

  @override
  String get authPhoneAction => '发送验证码';

  @override
  String get authForgotTitle => '找回密码';

  @override
  String get authForgotAction => '发送验证码';

  @override
  String get authVerifyTitle => '验证邮箱';

  @override
  String get authVerifyAction => '确认验证码';

  @override
  String get authResetTitle => '设置新密码';

  @override
  String get authResetAction => '确认修改';

  @override
  String get authProcessing => '正在处理…';

  @override
  String get authVerifyAndSignIn => '验证并登录';

  @override
  String get authForgotPassword => '忘记密码';

  @override
  String get authCreateAccount => '创建账号';

  @override
  String get authUsername => '用户名';

  @override
  String get authUsernameMinLength => '用户名至少 2 个字符';

  @override
  String get authPhone => '手机号';

  @override
  String get authAccountPlaceholder => '用户名、邮箱或手机号';

  @override
  String get authEmail => '邮箱';

  @override
  String get authEmailRequired => '请输入邮箱';

  @override
  String get authEmailInvalid => '邮箱格式不正确';

  @override
  String get authAccountRequired => '请输入用户名、邮箱或手机号';

  @override
  String get authPassword => '密码';

  @override
  String get authPasswordRequired => '请输入密码';

  @override
  String get authPasswordMinLength => '密码至少 8 位';

  @override
  String get authCode => '验证码';

  @override
  String get authConsentLabel => '登录与注册协议确认';

  @override
  String get authConsentPrefix => '我已阅读并同意';

  @override
  String get authTerms => '用户协议';

  @override
  String get authConsentMiddle => '与';

  @override
  String get authPrivacy => '隐私政策';

  @override
  String get authConsentRequired => '请先阅读并同意用户协议与隐私政策';
}
