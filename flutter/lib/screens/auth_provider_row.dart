import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../app/app_scope.dart';
import '../navigation/app_route.dart';
import '../navigation/app_route_paths.dart';
import '../theme/app_tokens.dart';

class AuthProviderDivider extends StatelessWidget {
  const AuthProviderDivider({super.key});

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

class AuthProviderRow extends StatelessWidget {
  const AuthProviderRow({required this.onPressed, super.key});

  final ValueChanged<String> onPressed;

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
          onPressed: () => onPressed('apple'),
        ),
        _ProviderButton(
          asset: 'assets/icons/google.svg',
          label: 'Google',
          enabled: controller.authProviders['google'] == true,
          onPressed: () => onPressed('google'),
        ),
        _ProviderButton(
          asset: 'assets/icons/github.svg',
          label: 'GitHub',
          enabled: controller.authProviders['github'] == true,
          onPressed: () => onPressed('github'),
        ),
        _ProviderButton(
          asset: 'assets/icons/phone.svg',
          label: '手机号',
          enabled: controller.authProviders['phone'] == true,
          onPressed: () => context.push(pathFor(AppRoute.phoneSignIn)),
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
  final VoidCallback onPressed;
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
