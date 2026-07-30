import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color background = Color(0xFFF6F7F9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF1F3F5);
  static const Color text = Color(0xFF17191D);
  static const Color secondaryText = Color(0xFF667085);
  static const Color border = Color(0xFFE4E7EC);
  static const Color brand = Color(0xFFA84444);
  static const Color brandSoft = Color(0xFFF6E9E9);
  static const Color success = Color(0xFF2C9A5E);
  static const Color warning = Color(0xFFD58B21);
  static const Color error = Color(0xFFD24B4B);
}

abstract final class AppSpacing {
  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x5 = 20;
  static const double x6 = 24;
  static const double x8 = 32;
}

abstract final class AppRadii {
  static const double small = 10;
  static const double control = 12;
  static const double card = 16;
  static const double sheet = 24;
}
