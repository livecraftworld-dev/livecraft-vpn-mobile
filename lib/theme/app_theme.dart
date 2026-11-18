import 'package:flutter/material.dart';

class LiveCraftTheme {
  // Live Craft Brand Palette (Deep coniferous graphite + Emerald neon)
  static const Color background = Color(0xFF0F1611);
  static const Color surface = Color(0xFF141C16);
  static const Color card = Color(0xFF18221A);
  static const Color border = Color(0xFF223326);
  
  static const Color primary = Color(0xFF10B981);      // Emerald Neon
  static const Color primaryHover = Color(0xFF34D399);
  static const Color accent = Color(0xFF10B981);       // Neon Accent
  static const Color gold = Color(0xFF10B981);         // Emerald accent for buttons/focus
  static const Color activeGreen = Color(0xFF10B981);  // Connected Emerald
  static const Color activeGlow = Color(0x3310B981);
  
  static const Color text = Color(0xFFF3F4F6);
  static const Color subtext = Color(0xFF9CA3AF);
  static const Color error = Color(0xFFEF4444);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      cardColor: card,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: surface,
      ),
      fontFamily: 'sans-serif',
    );
  }
}
