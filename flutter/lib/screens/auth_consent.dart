import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../navigation/app_route.dart';
import '../navigation/app_route_paths.dart';
import '../theme/app_tokens.dart';

class AuthConsent extends StatelessWidget {
  const AuthConsent({required this.value, required this.onChanged, super.key});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    // 点普通文字（"我已阅读并同意"/"与"）切换勾选；点链接（用户协议/隐私政策）跳转。
    return Semantics(
      container: true,
      label: '登录与注册协议确认',
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Checkbox(
              value: value,
              onChanged: (next) => onChanged(next ?? false),
            ),
            InkWell(
              onTap: () => onChanged(!value),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.x2),
                child: Text('我已阅读并同意'),
              ),
            ),
            const _LegalLink(label: '用户协议', route: AppRoute.termsOfService),
            InkWell(
              onTap: () => onChanged(!value),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.x2),
                child: Text('与'),
              ),
            ),
            const _LegalLink(label: '隐私政策', route: AppRoute.privacyPolicy),
          ],
        ),
      ),
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.route});

  final String label;
  final AppRoute route;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => context.push(pathFor(route)),
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x1),
      ),
      child: Text(label),
    );
  }
}
