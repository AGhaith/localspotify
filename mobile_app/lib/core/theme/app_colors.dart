import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Minimalist Monochrome Palette (Album art is the only color)
  static const Color background = Color(0xFF000000);
  static const Color card = Color(0xFF0E0E0E);
  static const Color cardHover = Color(0xFF222222);
  static const Color surface = Color(0xFF1A1A1A);
  static const Color inputBackground = Color(0xFF1A1A1A);

  // Primary: Monochrome White (Black foreground)
  static const Color primary = Color(0xFFFFFFFF);

  // Borders & Dividers
  static const Color border = Color(0xFF262626);
  static const Color borderStrong = Color(0xFF333333);

  // Shadows
  static const Color shadow = Color(0xFF000000);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA0A0A0);
  static const Color textMuted = Color(0xFF6B6B6B);
  static const Color textDark = Color(0xFF000000);

  // Status (Error for errors & destructive actions only)
  static const Color error = Color(0xFFE5484D);
}
