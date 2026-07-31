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
    brandSoft: AppColors.brandSoft,
    error: AppColors.error,
    errorSoft: const Color(0xFFFDE8E8),
  );

  static ThemeData get dark => _build(
    brightness: Brightness.dark,
    background: AppDarkColors.background,
    surface: AppDarkColors.surface,
    surfaceMuted: AppDarkColors.surfaceMuted,
    text: AppDarkColors.text,
    secondaryText: AppDarkColors.secondaryText,
    border: AppDarkColors.border,
    brandSoft: AppDarkColors.brandSoft,
    error: AppDarkColors.error,
    errorSoft: AppDarkColors.errorSoft,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color surfaceMuted,
    required Color text,
    required Color secondaryText,
    required Color border,
    required Color brandSoft,
    required Color error,
    required Color errorSoft,
  }) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = isDark
        ? ColorScheme.dark(
            primary: AppColors.brand,
            onPrimary: AppColors.onBrand,
            primaryContainer: brandSoft,
            onPrimaryContainer: text,
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
            onError: AppColors.onBrand,
            errorContainer: errorSoft,
            onErrorContainer: text,
            surfaceContainerHighest: surfaceMuted,
            outlineVariant: const Color(0xFF3A3E46),
          )
        : ColorScheme.light(
            primary: AppColors.brand,
            onPrimary: AppColors.onBrand,
            primaryContainer: brandSoft,
            onPrimaryContainer: AppColors.brand,
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
            onError: AppColors.onBrand,
            errorContainer: errorSoft,
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
        indicatorColor: brandSoft,
        backgroundColor: surface,
        labelTextStyle: WidgetStatePropertyAll(TextStyle(color: text)),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.brand
                : secondaryText,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceMuted,
        contentTextStyle: TextStyle(color: text),
        actionTextColor: isDark ? const Color(0xFFFFA0A0) : AppColors.brand,
        behavior: SnackBarBehavior.floating,
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
        titleMedium: TextStyle(color: text, fontSize: 16),
        labelLarge: TextStyle(color: text, fontSize: 14),
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
