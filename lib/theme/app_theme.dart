import 'package:flutter/material.dart';
import 'admin_tokens.dart';

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
  static const Color textDark = Color(0xFF203F35);

  // Semantic status colors shared across customer + admin surfaces
  static const Color warningAmber = Color(0xFFC9962E);
  static const Color infoBlueGray = Color(0xFF4A5568);

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
        bodyLarge: TextStyle(color: textDark, height: 1.4),
        bodyMedium: TextStyle(color: textDark, height: 1.4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceIvory,
        hintStyle: const TextStyle(color: mutedGray),
        labelStyle: const TextStyle(color: mutedGray, fontWeight: FontWeight.w500),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: borderWarm)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: borderWarm)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primaryCrimson, width: 1.8)),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: textDark,
        selectionColor: secondaryGold,
        selectionHandleColor: textDark,
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

/// Centralized Admin/Staff portal palette + typography.
/// Single source of truth para sa lahat ng admin screens — 
/// para hindi na paulit-ulit ang hardcoded hex values.
class AdminTheme {
  static const Color deepGreen = AdminTokens.ink;
  static const Color deepGreenSelected = AdminTokens.inkSoft;
  static const Color goldAccent = AdminTokens.gold;
  static const Color bronzeGold = Color(0xFFA47C3D);
  static const Color background = AdminTokens.canvas;
  static const Color surfaceIvory = AdminTokens.surface;
  static const Color textDark = AdminTokens.text;
  static const Color mutedDark = Color(0xFF687368);
  static const Color mutedGray = Color(0xFF788078);
  static const Color border = AdminTokens.line;
  static const Color danger = AdminTokens.danger;
  static const Color successBg = Color(0xFFEAF0E9);
  static const Color successFg = Color(0xFF53766C);
  static const Color warningBg = Color(0xFFF5EBD7);
  static const Color warningFg = Color(0xFF846228);
  static const Color infoText = Color(0xFF4A5568);
  static const Color preparingBg = Color(0xFFF7EAE4);
  static const Color priorityFg = Color(0xFF8A6D3B);

  static const TextStyle brandTitle = AdminTokens.display;

  static const TextStyle sectionTitle = TextStyle(
    fontFamily: 'Libre Baskerville',
    fontSize: 18,
    height: 1.2,
    color: textDark,
  );

  static const TextStyle sectionCaption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.bold,
    color: mutedDark,
    letterSpacing: 0.4,
  );

  static const TextStyle body = TextStyle(
    fontFamily: 'Manrope',
    fontSize: 13.5,
    height: 1.45,
    color: textDark,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: 'Manrope',
    fontSize: 12,
    height: 1.4,
    color: mutedDark,
  );

  static const TextStyle overline = TextStyle(
    fontFamily: 'Manrope',
    fontSize: 10.5,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.6,
    color: AdminTokens.goldDeep,
  );
}
