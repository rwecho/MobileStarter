import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum AppIconName {
  alert,
  arrowLeft,
  bell,
  check,
  chevronRight,
  close,
  crown,
  gift,
  globe,
  home,
  lock,
  palette,
  settings,
  trash,
  user,
}

extension AppIconPath on AppIconName {
  String get path {
    return switch (this) {
      AppIconName.alert => 'assets/icons/alert.svg',
      AppIconName.arrowLeft => 'assets/icons/arrow-left.svg',
      AppIconName.bell => 'assets/icons/bell.svg',
      AppIconName.check => 'assets/icons/check.svg',
      AppIconName.chevronRight => 'assets/icons/chevron-right.svg',
      AppIconName.close => 'assets/icons/close.svg',
      AppIconName.crown => 'assets/icons/crown.svg',
      AppIconName.gift => 'assets/icons/gift.svg',
      AppIconName.globe => 'assets/icons/globe.svg',
      AppIconName.home => 'assets/icons/home.svg',
      AppIconName.lock => 'assets/icons/lock.svg',
      AppIconName.palette => 'assets/icons/palette.svg',
      AppIconName.settings => 'assets/icons/settings.svg',
      AppIconName.trash => 'assets/icons/trash.svg',
      AppIconName.user => 'assets/icons/user.svg',
    };
  }
}

class AppIcon extends StatelessWidget {
  const AppIcon(this.name, {this.color, this.size = 24, super.key});

  final AppIconName name;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      name.path,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(
        color ?? Theme.of(context).colorScheme.onSurface,
        BlendMode.srcIn,
      ),
    );
  }
}
