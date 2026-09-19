import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Spotify Dark Grey Surface Palette (No pure black)
  static const Color background = Color(0xFF121212); // Exact Spotify charcoal dark grey
  static const Color card = Color(0xFF181818);       // Spotify Elevated Surface
  static const Color cardHover = Color(0xFF282828);  // Spotify Highlight Surface
  static const Color surface = Color(0xFF242424);    // Spotify Elevated Container
  static const Color inputBackground = Color(0xFF242424);

  // Vibrant Accents (Spotify Green + Neo Pop)
  static const Color primary = Color(0xFF22C55E);
  static const Color primaryBright = Color(0xFF1ED760);
  static const Color accentYellow = Color(0xFFFACC15);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color accentPink = Color(0xFFFF477E);
  static const Color accentCyan = Color(0xFF06B6D4);

  // Borders & Dividers
  static const Color border = Color(0x1FFFFFFF);
  static const Color borderStrong = Color(0x33FFFFFF);
  static const Color borderAccent = Color(0xFF22C55E);

  // Shadows
  static const Color shadow = Color(0xFF000000);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA1A1AA);
  static const Color textMuted = Color(0xFF71717A);
  static const Color textDark = Color(0xFF000000);

  // Status
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFFF477E);
  static const Color warning = Color(0xFFFACC15);
}
