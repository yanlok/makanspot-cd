import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFFF7EBD8);
  static const foreground = Color(0xFF3B2921);
  static const surface = Color(0xFFFFF9EF);
  static const primary = Color(0xFFD96C27);
  static const primaryDark = Color(0xFFA9471B);
  static const secondary = Color(0xFFEAD8BE);
  static const secondaryForeground = Color(0xFF7A4B2A);
  static const mutedForeground = Color(0xFF927B6B);
  static const accent = Color(0xFFE5A62F);
  static const destructive = Color(0xFFB84232);
  static const success = Color(0xFF52734D);
  static const shadow = Color(0x1A3B2921);
}

abstract final class AppSpacing {
  static const xSmall = 4.0;
  static const small = 8.0;
  static const medium = 16.0;
  static const large = 24.0;
  static const xLarge = 32.0;
}

abstract final class AppRadii {
  static const control = 12.0;
  static const card = 16.0;
  static const large = 24.0;
}

abstract final class AppTheme {
  static ThemeData get light {
    const bodyTheme = TextTheme(
      bodyLarge: TextStyle(fontFamily: 'Inter', fontSize: 16),
      bodyMedium: TextStyle(fontFamily: 'Inter', fontSize: 14),
      bodySmall: TextStyle(fontFamily: 'Inter', fontSize: 12),
      labelLarge: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      titleSmall: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: AppColors.surface,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.surface,
        primaryContainer: AppColors.secondary,
        onPrimaryContainer: AppColors.foreground,
        secondary: AppColors.secondaryForeground,
        onSecondary: AppColors.surface,
        secondaryContainer: AppColors.secondary,
        onSecondaryContainer: AppColors.foreground,
        surface: AppColors.surface,
        onSurface: AppColors.foreground,
        error: AppColors.destructive,
        onError: AppColors.surface,
        outline: AppColors.secondary,
      ),
      textTheme: bodyTheme.apply(
        bodyColor: AppColors.foreground,
        displayColor: AppColors.foreground,
      ),
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      dividerColor: AppColors.secondary,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: bodyTheme.bodyMedium?.copyWith(
          color: AppColors.mutedForeground,
        ),
        border: _inputBorder(AppColors.secondary),
        enabledBorder: _inputBorder(AppColors.secondary),
        focusedBorder: _inputBorder(AppColors.primary, width: 2),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.medium,
          vertical: 14,
        ),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.card),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
