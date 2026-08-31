import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app/app_scope.dart';
import '../design_system/components.dart';
import '../design_system/feedback.dart';
import '../l10n/generated/app_localizations.dart';
import '../navigation/app_route.dart';
import '../navigation/app_route_paths.dart';
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
  // 服务端认证失败的错误信息，内联显示在提交按钮上方（替代底部 toast，避免
  // 被键盘遮挡/一闪而过，见 issue #12）。输入变化时清空。
  String? authError;

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
        if (success && mounted) context.push(pathFor(AppRoute.verifyEmail));
        break;
      case AuthMode.verify:
        success = await controller.verifyPasswordReset(passwordController.text);
        if (success && mounted) context.push(pathFor(AppRoute.resetPassword));
        break;
      case AuthMode.reset:
        success = await controller.resetPassword(passwordController.text);
        if (success && mounted) context.go(pathFor(AppRoute.signIn));
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
        if (success) _completeAuthentication(controller);
        break;
      case AuthMode.signIn:
        success = await controller.signIn(
          emailController.text,
          passwordController.text,
        );
        if (success) _completeAuthentication(controller);
        break;
      case AuthMode.signUp:
        success = await controller.signUp(
          emailController.text,
          passwordController.text,
          usernameController.text,
          _termsRevision(controller),
        );
        if (success) _completeAuthentication(controller);
        break;
    }
    if (!success && mounted) {
      // 认证失败：错误内联显示在表单（而非底部 toast），见 issue #12。
      final message = controller.consumeError();
      if (message != null) {
        setState(() => authError = message);
      }
    }
  }

  bool _validateSubmission() {
    final l10n = AppLocalizations.of(context)!;
    final isSignUp = widget.mode == AuthMode.signUp;
    final isSignIn = widget.mode == AuthMode.signIn;
    if (!isSignUp && !isSignIn) return true;
    final account = emailController.text.trim();
    final username = usernameController.text.trim();
    final password = passwordController.text;
    setState(() {
      accountError = account.isEmpty
          ? (isSignIn ? l10n.authAccountRequired : l10n.authEmailRequired)
          : isSignUp && !_isEmail(account)
          ? l10n.authEmailInvalid
          : null;
      usernameError = isSignUp && username.length < 2 ? l10n.authUsernameMinLength : null;
      passwordError = password.isEmpty
          ? l10n.authPasswordRequired
          : isSignUp && password.length < 8
          ? l10n.authPasswordMinLength
          : null;
    });
    final valid =
        accountError == null && usernameError == null && passwordError == null;
    if (!valid) return false;
    return _ensureConsent();
  }

  bool _ensureConsent() {
    if (consentAgreed) return true;
    showAppToast(context, AppLocalizations.of(context)!.authConsentRequired);
    return false;
  }

  bool _isEmail(String value) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final copy = _copyFor(l10n, widget.mode);
    final controller = AppScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => AppPage(
        title: copy.$1,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.x6),
          children: [
            const SizedBox(height: AppSpacing.x8),
            Text(copy.$1, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.x2),
            Text(
              l10n.authTagline,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.x6),
            TextField(
              controller: emailController,
              keyboardType: widget.mode == AuthMode.phone
                  ? TextInputType.phone
                  : TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: _accountLabel(l10n),
                errorText: accountError,
              ),
              onChanged: (_) => setState(() => authError = null),
            ),
            if (widget.mode == AuthMode.signUp) ...[
              const SizedBox(height: AppSpacing.x3),
              TextField(
                controller: usernameController,
                decoration: InputDecoration(
                  labelText: l10n.authUsername,
                  errorText: usernameError,
                ),
                onChanged: (_) => setState(() => authError = null),
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
                      ? l10n.authCode
                      : l10n.authPassword,
                  errorText: passwordError,
                ),
                onChanged: (_) => setState(() => authError = null),
              ),
              const SizedBox(height: AppSpacing.x4),
            ],
            if (authError != null) ...[
              Text(
                authError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.x2),
            ],
            AppButton(
              label: controller.busy ? l10n.authProcessing : copy.$2,
              onPressed: () => submit(),
            ),
            if (widget.mode == AuthMode.signIn) ...[
              const SizedBox(height: AppSpacing.x5),
              const AuthProviderDivider(),
              const SizedBox(height: AppSpacing.x3),
              AuthProviderRow(onPressed: _socialSignIn),
              TextButton(
                onPressed: () => context.push(pathFor(AppRoute.forgotPassword)),
                child: Text(l10n.authForgotPassword),
              ),
              TextButton(
                onPressed: () => context.push(pathFor(AppRoute.signUp)),
                child: Text(l10n.authCreateAccount),
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
      ),
    );
  }

  bool get _requiresConsent =>
      widget.mode == AuthMode.signIn || widget.mode == AuthMode.signUp;

  String _accountLabel(AppLocalizations l10n) => switch (widget.mode) {
    AuthMode.phone => l10n.authPhone,
    AuthMode.signIn => l10n.authAccountPlaceholder,
    _ => l10n.authEmail,
  };

  Future<void> _socialSignIn(String provider) async {
    if (!_ensureConsent()) return;
    final controller = AppScope.of(context);
    final success = await controller.socialSignIn(provider);
    if (success) _completeAuthentication(controller);
  }

  /// Resume the pre-login target if the user was redirected from a protected
  /// route; otherwise go to the home shell branch.
  void _completeAuthentication(AppController controller) {
    if (!mounted) return;
    final target = controller.consumeAuthRedirectTarget() ?? AppRoute.home;
    context.go(pathFor(target));
  }

  String _termsRevision(AppController controller) {
    final legal = controller.config?.legal;
    if (legal == null || legal.isEmpty) return 'unknown';
    return legal.first.revision;
  }

  (String, String) _copyFor(AppLocalizations l10n, AuthMode mode) {
    return switch (mode) {
      AuthMode.signIn => (l10n.authSignInTitle, l10n.authSignInAction),
      AuthMode.signUp => (l10n.authSignUpTitle, l10n.authSignUpAction),
      AuthMode.phone => (
        l10n.authPhoneTitle,
        phoneCodeSent ? l10n.authVerifyAndSignIn : l10n.authPhoneAction,
      ),
      AuthMode.forgot => (l10n.authForgotTitle, l10n.authForgotAction),
      AuthMode.verify => (l10n.authVerifyTitle, l10n.authVerifyAction),
      AuthMode.reset => (l10n.authResetTitle, l10n.authResetAction),
    };
  }
}
