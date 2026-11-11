import 'package:flutter/material.dart';

/// Single source of truth para sa admin UI.
/// Wala nang hardcoded padding/radius/color sa screens.
class AdminTokens {
  AdminTokens._();

  // Spacing scale (4-based)
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;

  // Radii
  static const double rSm = 10;
  static const double rMd = 14;
  static const double rLg = 20;
  static const double rXl = 26;

  // Palette
  static const Color ink = Color(0xFF19382F);
  static const Color inkSoft = Color(0xFF2C4D40);
  static const Color canvas = Color(0xFFF6F2EA);
  static const Color surface = Color(0xFFFFFDFA);
  static const Color line = Color(0xFFE7E1D5);
  static const Color gold = Color(0xFFC3AA7F);
  static const Color goldDeep = Color(0xFF9C7B3C);
  static const Color text = Color(0xFF203F35);
  static const Color textMuted = Color(0xFF6E7A6E);
  static const Color danger = Color(0xFF9A3B3B);
  static const Color success = Color(0xFF2F7D5B);
  static const Color warning = Color(0xFFB4802E);

  // Type scale
  static const TextStyle display = TextStyle(
    fontFamily: 'Libre Baskerville',
    fontSize: 26,
    height: 1.15,
    fontWeight: FontWeight.w400,
    color: text,
    letterSpacing: -0.4,
  );
  static const TextStyle h1 = TextStyle(
    fontFamily: 'Libre Baskerville',
    fontSize: 20,
    height: 1.2,
    color: text,
  );
  static const TextStyle h2 = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: text,
    letterSpacing: -0.2,
  );
  static const TextStyle body = TextStyle(fontSize: 13.5, height: 1.45, color: text);
  static const TextStyle caption = TextStyle(fontSize: 12, height: 1.4, color: textMuted);
  static const TextStyle overline = TextStyle(
    fontSize: 10.5,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.6,
    color: goldDeep,
  );

  // Surfaces
  static BoxDecoration card({bool hovered = false}) => BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(rLg),
        border: Border.all(color: line),
        boxShadow: hovered
            ? const [BoxShadow(color: Color(0x14000000), blurRadius: 22, offset: Offset(0, 10))]
            : null,
      );
}
