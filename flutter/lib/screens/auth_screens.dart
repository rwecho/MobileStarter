import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../app/app_scope.dart';
import '../design_system/components.dart';
import '../design_system/feedback.dart';
import '../navigation/app_route.dart';
import '../theme/app_tokens.dart';

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
        );
        if (success) controller.completeAuthentication();
        break;
    }
    if (!success && mounted) {
      showAppToast(context, controller.consumeError() ?? '操作失败');
    }
  }

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
              labelText: widget.mode == AuthMode.phone ? '手机号' : '邮箱',
            ),
          ),
          if (widget.mode == AuthMode.signUp) ...[
            const SizedBox(height: AppSpacing.x3),
            TextField(
              controller: usernameController,
              decoration: const InputDecoration(labelText: '用户名'),
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
            const _ProviderDivider(),
            const SizedBox(height: AppSpacing.x3),
            const _ProviderRow(),
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
        ],
      ),
    );
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

class _ProviderDivider extends StatelessWidget {
  const _ProviderDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider()),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.x3),
          child: Text('其他登录方式'),
        ),
        Expanded(child: Divider()),
      ],
    );
  }
}

class _ProviderRow extends StatelessWidget {
  const _ProviderRow();

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ProviderButton(
          asset: 'assets/icons/apple.svg',
          label: 'Apple',
          enabled: controller.authProviders['apple'] == true,
          onPressed: null,
        ),
        _ProviderButton(
          asset: 'assets/icons/google.svg',
          label: 'Google',
          enabled: controller.authProviders['google'] == true,
          onPressed: null,
        ),
        _ProviderButton(
          asset: 'assets/icons/github.svg',
          label: 'GitHub',
          enabled: controller.authProviders['github'] == true,
          onPressed: null,
        ),
        _ProviderButton(
          asset: 'assets/icons/phone.svg',
          label: '手机号',
          enabled: controller.authProviders['phone'] == true,
          onPressed: () => AppScope.of(context).navigate(AppRoute.phoneSignIn),
        ),
      ],
    );
  }
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.asset,
    required this.label,
    required this.onPressed,
    this.enabled = true,
  });

  final String asset;
  final String label;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        enabled: enabled,
        label: '$label 登录',
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: enabled ? onPressed : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2),
            child: Column(
              children: [
                Opacity(
                  opacity: enabled ? 1 : .38,
                  child: SvgPicture.asset(asset, width: 24, height: 24),
                ),
                const SizedBox(height: AppSpacing.x1),
                Text(label, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
