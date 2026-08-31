import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/generated/app_localizations.dart';
import '../navigation/app_route.dart';
import '../navigation/app_route_paths.dart';
import '../theme/app_tokens.dart';

class AuthConsent extends StatelessWidget {
  const AuthConsent({required this.value, required this.onChanged, super.key});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // 点普通文字（"我已阅读并同意"/"与"）切换勾选；点链接（用户协议/隐私政策）跳转。
    return Semantics(
      container: true,
      label: l10n.authConsentLabel,
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
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2),
                child: Text(l10n.authConsentPrefix),
              ),
            ),
            _LegalLink(label: l10n.authTerms, route: AppRoute.termsOfService),
            InkWell(
              onTap: () => onChanged(!value),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2),
                child: Text(l10n.authConsentMiddle),
              ),
            ),
            _LegalLink(label: l10n.authPrivacy, route: AppRoute.privacyPolicy),
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
