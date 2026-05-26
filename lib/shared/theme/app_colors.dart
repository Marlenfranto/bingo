import 'package:flutter/material.dart';

/// Color design tokens. Do not hard-code hex anywhere else in the app.
abstract final class AppColors {
  AppColors._();

  // Brand
  static const Color accent = Color(0xFF00FF88);
  static const Color accentDark = Color(0xFF00CC66);
  static const Color accentMuted = Color(0x3300FF88);
  static const Color accentGlow = Color(0x6600FF88);

  // Surface (dark-first; the brand is intentionally dark)
  static const Color background = Color(0xFF0D1F1C);
  static const Color surface = Color(0xFF152926);
  static const Color surfaceElevated = Color(0xFF1A3A35);
  static const Color surfaceDim = Color(0xFF0A1614);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xB3FFFFFF);
  static const Color textTertiary = Color(0x80FFFFFF);
  static const Color textDisabled = Color(0x4DFFFFFF);

  // State
  static const Color success = Color(0xFF00FF88);
  static const Color warning = Color(0xFFFFB454);
  static const Color error = Color(0xFFFF5C5C);
  static const Color info = Color(0xFF54B2FF);

  // Brand-adjacent
  static const Color linkedIn = Color(0xFF0077B5);
  static const Color divider = Color(0x1AFFFFFF);
  static const Color overlay = Color(0xCC000000);

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, accentDark],
  );
}
