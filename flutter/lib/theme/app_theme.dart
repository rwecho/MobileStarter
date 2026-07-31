import 'package:flutter/material.dart';
import 'app_tokens.dart';

abstract final class AppTheme {
  static ThemeData get light => _build(
        brightness: Brightness.light,
        background: AppColors.background,
        surface: AppColors.surface,
        surfaceMuted: AppColors.surfaceMuted,
        text: AppColors.text,
        secondaryText: AppColors.secondaryText,
        border: AppColors.border,
        error: AppColors.error,
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        background: const Color(0xFF0F1115),
        surface: const Color(0xFF1A1D24),
        surfaceMuted: const Color(0xFF23272F),
        text: const Color(0xFFE6E8EC),
        secondaryText: const Color(0xFF9AA1AD),
        border: const Color(0xFF2C313A),
        error: const Color(0xFFE06C6C),
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color surfaceMuted,
    required Color text,
    required Color secondaryText,
    required Color border,
    required Color error,
  }) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = isDark
        ? ColorScheme.dark(
            primary: AppColors.brand,
            surface: surface,
            error: error,
            onSurface: text,
            onSurfaceVariant: secondaryText,
            outline: border,
            // Fill missing roles — was defaulting to M2 #03DAC6 teal.
            secondary: secondaryText,
            onSecondary: background,
            secondaryContainer: surfaceMuted,
            onSecondaryContainer: text,
            tertiary: AppColors.warning,
            onTertiary: surface,
            tertiaryContainer: border,
            onTertiaryContainer: text,
            errorContainer: const Color(0xFF3D1A1A),
            onErrorContainer: error,
            surfaceContainerHighest: surfaceMuted,
            outlineVariant: const Color(0xFF3A3E46),
          )
        : ColorScheme.light(
            primary: AppColors.brand,
            surface: surface,
            error: error,
            onSurface: text,
            onSurfaceVariant: secondaryText,
            outline: border,
            // Fill missing roles — was defaulting to M2 #03DAC6 teal.
            secondary: secondaryText,
            onSecondary: surface,
            secondaryContainer: surfaceMuted,
            onSecondaryContainer: text,
            tertiary: AppColors.warning,
            onTertiary: surface,
            tertiaryContainer: AppColors.brandSoft,
            onTertiaryContainer: AppColors.brand,
            errorContainer: const Color(0xFFFDE8E8),
            onErrorContainer: error,
            surfaceContainerHighest: surfaceMuted,
            outlineVariant: const Color(0xFFEEF0F2),
          );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      colorScheme: colorScheme,
      dividerColor: border,
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: AppColors.brandSoft,
        backgroundColor: surface,
      ),
      textTheme: TextTheme(
        headlineMedium: TextStyle(
          color: text,
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: TextStyle(
          color: text,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(color: text, fontSize: 16),
        bodyMedium: TextStyle(color: secondaryText, fontSize: 14),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: BorderSide(color: border),
        ),
      ),
    );
  }
}
