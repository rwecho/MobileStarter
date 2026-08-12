import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/localized_text.dart';
import '../design_system/app_icon.dart';

/// The persistent shell: bottom NavigationBar + the current branch's page.
/// Each branch in the StatefulShellRoute keeps its own stateful navigator, so
/// switching tabs does NOT destroy the other tabs' scroll/state.
class ShellScaffold extends StatelessWidget {
  const ShellScaffold({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _goBranch(BuildContext context, int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => _goBranch(context, index),
        destinations: [
          NavigationDestination(
            icon: const AppIcon(AppIconName.home),
            label: localizedText(context, '首页', 'Home'),
          ),
          NavigationDestination(
            icon: const AppIcon(AppIconName.crown),
            label: localizedText(context, '会员', 'Membership'),
          ),
          NavigationDestination(
            icon: const AppIcon(AppIconName.user),
            label: localizedText(context, '我的', 'Profile'),
          ),
        ],
      ),
    );
  }
}
