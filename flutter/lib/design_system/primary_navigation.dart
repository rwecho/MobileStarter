import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../navigation/app_route.dart';
import '../l10n/localized_text.dart';
import 'app_icon.dart';

class PrimaryNavigation extends StatelessWidget {
  const PrimaryNavigation({required this.selectedIndex, super.key});

  final int selectedIndex;

  @override
  Widget build(BuildContext context) => NavigationBar(
    selectedIndex: selectedIndex,
    onDestinationSelected: (index) {
      AppScope.of(context).replaceAll(_routes[index]);
    },
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
  );
}

const _routes = [AppRoute.home, AppRoute.membership, AppRoute.profile];
