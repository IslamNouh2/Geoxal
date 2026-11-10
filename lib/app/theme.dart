import 'package:flutter/material.dart';

class AppColors {
  // Deep Space Blue: #1c3144
  static const Color deepSpaceBlue = Color(0xFF1C3144);
  // Brick Ember: #d00000
  static const Color brickEmber = Color(0xFFD00000);
  // Amber Flame: #ffba08
  static const Color amberFlame = Color(0xFFFFBA08);
  // Cool Steel: #a2aebb
  static const Color coolSteel = Color(0xFFA2AEBB);
  // Steel Blue: #3f88c5
  static const Color steelBlue = Color(0xFF3F88C5);

  // Common UI Aliases
  static const Color primary = deepSpaceBlue;
  static const Color secondary = steelBlue;
  static const Color error = brickEmber;
  static const Color warning = amberFlame;
  static const Color success = Color(0xFF2E7D32);
  static const Color background = Color(0xFFF9FAFB);
  static const Color surface = Color(0xFFF3F4F6);
  static const Color border = Color(0xFFE5E7EB);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.deepSpaceBlue,
        primary: AppColors.deepSpaceBlue,
        secondary: AppColors.steelBlue,
        error: AppColors.brickEmber,
        surface: Colors.white,
      ),
      useMaterial3: true,
      fontFamily: 'Segoe UI',
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.deepSpaceBlue,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}
