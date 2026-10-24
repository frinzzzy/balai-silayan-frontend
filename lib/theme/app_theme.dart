import 'package:flutter/material.dart';

class AppTheme {
  // Brand Color Palette inspired by Balai Silayan Korean & Filipino Cuisine logo
  static const Color primaryCrimson = Color(0xFF8B1E24);
  static const Color secondaryGold = Color(0xFFC5A880);
  static const Color backgroundCream = Color(0xFFF8F5F0);
  static const Color surfaceIvory = Color(0xFFFFFDFA);
  static const Color darkCharcoal = Color(0xFF1E2229);
  static const Color mutedGray = Color(0xFF788078);
  static const Color borderWarm = Color(0xFFEAE3D9);
  static const Color warmTint = Color(0xFFF3EFEA);
  static const Color cherryPink = Color(0xFFF2BAC9);
  static const Color successGreen = Color(0xFF10B981);
  static const Color errorRust = Color(0xFF8E5136);

  static ThemeData get lightTheme {
    return ThemeData.light().copyWith(
      scaffoldBackgroundColor: backgroundCream,
      colorScheme: const ColorScheme.light(
        primary: primaryCrimson,
        secondary: secondaryGold,
        surface: surfaceIvory,
        error: errorRust,
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(fontWeight: FontWeight.bold, color: darkCharcoal, letterSpacing: -0.3),
        bodyMedium: TextStyle(color: mutedGray, height: 1.4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceIvory,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        labelStyle: const TextStyle(color: mutedGray, fontWeight: FontWeight.w500),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: borderWarm)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: borderWarm)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primaryCrimson, width: 1.8)),
      ),
      cardTheme: CardThemeData(
        color: surfaceIvory,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: borderWarm),
        ),
      ),
    );
  }
}
