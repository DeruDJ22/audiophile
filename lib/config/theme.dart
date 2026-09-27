/// Design tokens for the Kuroakai (黒赤) theme.
/// Black-red dark mode palette consistent across all screens.
library;

import 'package:flutter/material.dart';

class KuroakaiTheme {
  // ─── Background & Surface ───
  static const Color background = Color(0xFF0F0F13);
  static const Color surface = Color(0xFF181820);
  static const Color surfaceAlt = Color(0xFF14141A);
  static const Color card = Color(0xFF1E1E28);

  // ─── Accent Colors (赤 = Red) ───
  static const Color primary = Color(0xFFE50914);
  static const Color secondary = Color(0xFFFF3344);
  static const Color primaryGlow = Color(0x40E50914); // 25% opacity

  // ─── Text ───
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0x8AFFFFFF); // 54%
  static const Color textTertiary = Color(0x61FFFFFF); // 38%

  // ─── Borders & Dividers ───
  static const Color divider = Colors.white12;
  static const Color border = Colors.white10;

  // ─── Functional ───
  static const Color success = Color(0xFF4ADE80);
  static const Color warning = Color(0xFFFFD700);

  /// Full ThemeData for MaterialApp
  static ThemeData get darkTheme => ThemeData.dark().copyWith(
        scaffoldBackgroundColor: background,
        primaryColor: primary,
        colorScheme: const ColorScheme.dark(
          primary: primary,
          secondary: secondary,
          surface: surface,
        ),
        cardColor: card,
        dividerColor: divider,
        sliderTheme: const SliderThemeData(
          activeTrackColor: primary,
          inactiveTrackColor: Colors.white12,
          thumbColor: secondary,
          overlayColor: Color(0x33E50914),
          trackHeight: 3.0,
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: card,
          contentTextStyle: TextStyle(color: textPrimary),
          behavior: SnackBarBehavior.floating,
        ),
      );

  /// Gradient for full player background based on dominant color
  static LinearGradient playerGradient(Color dominantColor) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        dominantColor.withValues(alpha: 0.8),
        dominantColor.withValues(alpha: 0.4),
        background,
        background,
      ],
      stops: const [0.0, 0.3, 0.7, 1.0],
    );
  }

  /// Standard card decoration
  static BoxDecoration get cardDecoration => BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      );

  /// Elevated card with glow
  static BoxDecoration get glowCardDecoration => BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.15),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      );
}
