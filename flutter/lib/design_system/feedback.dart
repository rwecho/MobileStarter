import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';
import 'app_icon.dart';
import 'components.dart';

void showAppToast(BuildContext context, String message, {bool error = false}) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          AppIcon(
            error ? AppIconName.alert : AppIconName.check,
            color: error ? scheme.error : AppColors.success,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}

Future<bool> showAppConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const AppIcon(
        AppIconName.alert,
        color: AppColors.warning,
        size: 32,
      ),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('取消'),
        ),
        SizedBox(
          width: 120,
          child: AppButton(
            label: confirmLabel,
            destructive: true,
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}
