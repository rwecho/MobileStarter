import 'package:flutter/material.dart';
import '../app/app_controller.dart';
import '../app/app_scope.dart';
import '../design_system/components.dart';
import '../design_system/feedback.dart';
import '../navigation/app_route.dart';
import '../theme/app_tokens.dart';
import 'auth_consent.dart';
import 'auth_provider_row.dart';

enum AuthMode { signIn, signUp, phone, forgot, verify, reset }

class AuthScreen extends StatefulWidget {
  const AuthScreen({required this.mode, super.key});
  final AuthMode mode;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final usernameController = TextEditingController();
  bool phoneCodeSent = false;
  bool consentAgreed = false;
  String? accountError;
  String? passwordError;
  String? usernameError;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    usernameController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final controller = AppScope.of(context);
    if (controller.busy) return;
    if (!_validateSubmission()) return;
    var success = false;
    switch (widget.mode) {
      case AuthMode.forgot:
        success = await controller.requestPasswordReset(emailController.text);
        if (success) controller.navigate(AppRoute.verifyEmail);
        break;
      case AuthMode.verify:
        success = await controller.verifyPasswordReset(passwordController.text);
        if (success) controller.navigate(AppRoute.resetPassword);
        break;
      case AuthMode.reset:
        success = await controller.resetPassword(passwordController.text);
        if (success) controller.replaceAll(AppRoute.signIn);
        break;
      case AuthMode.phone:
        if (!phoneCodeSent) {
          success = await controller.requestPhoneCode(emailController.text);
          if (success) setState(() => phoneCodeSent = true);
          break;
        }
        success = await controller.verifyPhoneCode(
          emailController.text,
          passwordController.text,
        );
        if (success) controller.completeAuthentication();
        break;
      case AuthMode.signIn:
        success = await controller.signIn(
          emailController.text,
          passwordController.text,
        );
        if (success) controller.completeAuthentication();
        break;
      case AuthMode.signUp:
        success = await controller.signUp(
          emailController.text,
          passwordController.text,
          usernameController.text,
          _termsRevision(controller),
        );
        if (success) controller.completeAuthentication();
        break;
    }
    if (!success && mounted) {
      showAppToast(context, controller.consumeError() ?? '操作失败');
    }
  }

  bool _validateSubmission() {
    final isSignUp = widget.mode == AuthMode.signUp;
    final isSignIn = widget.mode == AuthMode.signIn;
    if (!isSignUp && !isSignIn) return true;
    final account = emailController.text.trim();
    final username = usernameController.text.trim();
    final password = passwordController.text;
    setState(() {
      accountError = account.isEmpty
          ? (isSignIn ? '请输入用户名、邮箱或手机号' : '请输入邮箱')
          : isSignUp && !_isEmail(account)
          ? '邮箱格式不正确'
          : null;
      usernameError = isSignUp && username.length < 2 ? '用户名至少 2 个字符' : null;
      passwordError = password.isEmpty
          ? '请输入密码'
          : isSignUp && password.length < 8
          ? '密码至少 8 位'
          : null;
    });
    final valid =
        accountError == null && usernameError == null && passwordError == null;
    if (!valid) return false;
    return _ensureConsent();
  }

  bool _ensureConsent() {
    if (consentAgreed) return true;
    showAppToast(context, '请先阅读并同意用户协议与隐私政策');
    return false;
  }

  bool _isEmail(String value) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);

  @override
  Widget build(BuildContext context) {
    final copy = _copyFor(widget.mode);
    return AppPage(
      title: copy.$1,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.x6),
        children: [
          const SizedBox(height: AppSpacing.x8),
          Text(copy.$1, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.x2),
          Text(
            '安全同步你的会员、订单与偏好设置。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.x6),
          TextField(
            controller: emailController,
            keyboardType: widget.mode == AuthMode.phone
                ? TextInputType.phone
                : TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: _accountLabel(),
              errorText: accountError,
            ),
          ),
          if (widget.mode == AuthMode.signUp) ...[
            const SizedBox(height: AppSpacing.x3),
            TextField(
              controller: usernameController,
              decoration: InputDecoration(
                labelText: '用户名',
                errorText: usernameError,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.x3),
          if (widget.mode != AuthMode.forgot &&
              (widget.mode != AuthMode.phone || phoneCodeSent)) ...[
            TextField(
              controller: passwordController,
              obscureText: widget.mode != AuthMode.verify,
              decoration: InputDecoration(
                labelText:
                    widget.mode == AuthMode.verify ||
                        widget.mode == AuthMode.phone
                    ? '验证码'
                    : '密码',
                errorText: passwordError,
              ),
            ),
            const SizedBox(height: AppSpacing.x4),
          ],
          AppButton(
            label: AppScope.of(context).busy ? '正在处理…' : copy.$2,
            onPressed: () => submit(),
          ),
          if (widget.mode == AuthMode.signIn) ...[
            const SizedBox(height: AppSpacing.x5),
            const AuthProviderDivider(),
            const SizedBox(height: AppSpacing.x3),
            AuthProviderRow(onPressed: _socialSignIn),
            TextButton(
              onPressed: () =>
                  AppScope.of(context).navigate(AppRoute.forgotPassword),
              child: const Text('忘记密码'),
            ),
            TextButton(
              onPressed: () => AppScope.of(context).navigate(AppRoute.signUp),
              child: const Text('创建账号'),
            ),
          ],
          if (_requiresConsent) ...[
            const SizedBox(height: AppSpacing.x4),
            AuthConsent(
              value: consentAgreed,
              onChanged: (value) => setState(() => consentAgreed = value),
            ),
          ],
        ],
      ),
    );
  }

  bool get _requiresConsent =>
      widget.mode == AuthMode.signIn || widget.mode == AuthMode.signUp;

  String _accountLabel() => switch (widget.mode) {
    AuthMode.phone => '手机号',
    AuthMode.signIn => '用户名、邮箱或手机号',
    _ => '邮箱',
  };

  Future<void> _socialSignIn(String provider) async {
    if (!_ensureConsent()) return;
    final controller = AppScope.of(context);
    final success = await controller.socialSignIn(provider);
    if (success) controller.completeAuthentication();
  }

  String _termsRevision(AppController controller) {
    final legal = controller.config?.legal;
    if (legal == null || legal.isEmpty) return 'unknown';
    return legal.first.revision;
  }

  (String, String) _copyFor(AuthMode mode) {
    return switch (mode) {
      AuthMode.signIn => ('欢迎回来', '登录'),
      AuthMode.signUp => ('创建账号', '注册'),
      AuthMode.phone => ('手机号登录', phoneCodeSent ? '验证并登录' : '发送验证码'),
      AuthMode.forgot => ('找回密码', '发送验证码'),
      AuthMode.verify => ('验证邮箱', '确认验证码'),
      AuthMode.reset => ('设置新密码', '确认修改'),
    };
  }
}
