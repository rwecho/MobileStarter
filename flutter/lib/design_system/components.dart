import 'package:flutter/material.dart';
import '../app/app_scope.dart';
import '../navigation/app_route.dart';
import '../theme/app_tokens.dart';
import 'app_icon.dart';

class AppPage extends StatelessWidget {
  const AppPage({
    required this.title,
    required this.child,
    this.bottomNavigationBar,
    super.key,
  });

  final String title;
  final Widget child;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(title),
        leading: controller.canGoBack
            ? AppIconButton(
                label: '返回',
                icon: AppIconName.arrowLeft,
                onPressed: controller.back,
              )
            : const SizedBox.shrink(),
      ),
      body: child,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String label;
  final AppIconName icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: InkResponse(
        onTap: onPressed,
        radius: 24,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(child: AppIcon(icon)),
        ),
      ),
    );
  }
}

class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.destructive = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppIconName? icon;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = destructive ? scheme.error : scheme.primary;
    final foreground = destructive ? scheme.onError : scheme.onPrimary;
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: color,
        foregroundColor: foreground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            AppIcon(icon!, color: foreground, size: 20),
            const SizedBox(width: AppSpacing.x2),
          ],
          Text(label),
        ],
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: scheme.outline),
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class AppListTile extends StatelessWidget {
  const AppListTile({
    required this.label,
    this.route,
    this.value,
    this.icon,
    super.key,
  });

  final String label;
  final AppRoute? route;
  final String? value;
  final AppIconName? icon;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ListTile(
      minTileHeight: 56,
      leading: icon == null ? null : AppIcon(icon!, color: muted, size: 20),
      title: Text(label),
      subtitle: value == null ? null : Text(value!),
      trailing: route == null
          ? null
          : AppIcon(AppIconName.chevronRight, color: muted, size: 18),
      onTap: route == null ? null : () => AppScope.of(context).navigate(route!),
    );
  }
}
