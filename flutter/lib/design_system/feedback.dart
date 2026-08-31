import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';
import 'app_icon.dart';
import 'components.dart';

/// 顶部 toast，三端统一位置（ArkTS promptAction / RN react-native-toast-message 均为顶部）。
/// SnackBar 只能贴 Scaffold 底部，无法定位到顶部，因此走全局 Overlay。
OverlayEntry? _activeToast;

void showAppToast(BuildContext context, String message, {bool error = false}) {
  _activeToast?.remove();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (overlayContext) => _AppToast(
      message: message,
      error: error,
      onDismissed: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );
  _activeToast = entry;
  Overlay.of(context, rootOverlay: true).insert(entry);
}

class _AppToast extends StatefulWidget {
  const _AppToast({
    required this.message,
    required this.error,
    required this.onDismissed,
  });

  final String message;
  final bool error;
  final VoidCallback onDismissed;

  @override
  State<_AppToast> createState() => _AppToastState();
}

class _AppToastState extends State<_AppToast> {
  static const _showDuration = Duration(milliseconds: 2400);
  static const _transitionDuration = Duration(milliseconds: 200);

  Timer? _hideTimer;
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _shown = true);
    });
    _hideTimer = Timer(_showDuration, () {
      if (mounted) setState(() => _shown = false);
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      top: MediaQuery.paddingOf(context).top + AppSpacing.x3,
      left: AppSpacing.x4,
      right: AppSpacing.x4,
      child: AnimatedSlide(
        offset: _shown ? Offset.zero : const Offset(0, -0.25),
        duration: _transitionDuration,
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: _shown ? 1 : 0,
          duration: _transitionDuration,
          onEnd: () {
            if (!_shown) widget.onDismissed();
          },
          child: Material(
            color: scheme.surface,
            elevation: 2,
            shadowColor: Colors.black26,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.control),
              side: BorderSide(color: scheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x4,
                vertical: AppSpacing.x3,
              ),
              child: Row(
                children: [
                  AppIcon(
                    widget.error ? AppIconName.alert : AppIconName.check,
                    color: widget.error ? scheme.error : AppColors.success,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.x3),
                  Expanded(child: Text(widget.message)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
