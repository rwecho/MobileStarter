import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../navigation/app_route.dart';
import '../theme/app_tokens.dart';

class AuthConsent extends StatelessWidget {
  const AuthConsent({required this.value, required this.onChanged, super.key});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
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
            const Text('我已阅读并同意'),
            const _LegalLink(label: '用户协议', route: AppRoute.termsOfService),
            const Text('与'),
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
      onPressed: () => AppScope.of(context).navigate(route),
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x1),
      ),
      child: Text(label),
    );
  }
}
