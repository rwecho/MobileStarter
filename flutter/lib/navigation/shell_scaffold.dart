import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/localized_text.dart';
import '../design_system/app_icon.dart';
import '../telemetry/telemetry.dart';

/// The persistent shell: bottom NavigationBar + the current branch's page.
/// Each branch in the StatefulShellRoute keeps its own stateful navigator, so
/// switching tabs does NOT destroy the other tabs' scroll/state.
class ShellScaffold extends StatelessWidget {
  const ShellScaffold({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
    // Tab-switch screen telemetry. A shared NavigatorObserver can't be attached
    // to both the root and branch navigators (NavigatorState asserts a single
    // navigator per observer), so we emit here on the branch change.
    if (_branchPaths.length > index) telemetry.screen(_branchPaths[index]);
  }

  static const _branchPaths = ['/home', '/membership', '/profile'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _goBranch,
        destinations: [
          NavigationDestination(
            icon: AppIcon(
              AppIconName.home,
              color: IconTheme.of(context).color,
            ),
            label: localizedText(context, '首页', 'Home'),
          ),
          NavigationDestination(
            icon: AppIcon(
              AppIconName.crown,
              color: IconTheme.of(context).color,
            ),
            label: localizedText(context, '会员', 'Membership'),
          ),
          NavigationDestination(
            icon: AppIcon(
              AppIconName.user,
              color: IconTheme.of(context).color,
            ),
            label: localizedText(context, '我的', 'Profile'),
          ),
        ],
      ),
    );
  }
}
