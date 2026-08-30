import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTypography {
  AppTypography._();

  static TextStyle displayLarge = GoogleFonts.plusJakartaSans(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static TextStyle displayMedium = GoogleFonts.plusJakartaSans(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );

  static TextStyle titleLarge = GoogleFonts.plusJakartaSans(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.2,
  );

  static TextStyle titleMedium = GoogleFonts.plusJakartaSans(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle bodyLarge = GoogleFonts.plusJakartaSans(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static TextStyle bodyMedium = GoogleFonts.plusJakartaSans(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static TextStyle bodySmall = GoogleFonts.plusJakartaSans(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
  );

  static TextStyle labelLarge = GoogleFonts.plusJakartaSans(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static TextStyle labelSmall = GoogleFonts.plusJakartaSans(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: AppColors.textSecondary,
    letterSpacing: 0.5,
  );
}
