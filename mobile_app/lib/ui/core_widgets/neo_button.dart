import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'pressable_scale.dart';

class NeoButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color textColor;
  final Color borderColor;
  final double height;
  final bool isLoading;
  final double borderRadius;

  const NeoButton({
    super.key,
    required this.text,
    this.icon,
    this.onPressed,
    this.backgroundColor = AppColors.primary,
    this.textColor = AppColors.textDark,
    this.borderColor = AppColors.primary,
    this.height = 48,
    this.isLoading = false,
    this.borderRadius = 9999, // Pill by default
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;

    return PressableScale(
      onTap: enabled
          ? () {
              HapticFeedback.lightImpact();
              onPressed?.call();
            }
          : null,
      scaleFactor: 0.96,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: enabled ? backgroundColor : backgroundColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: borderColor == AppColors.primary ? Colors.transparent : borderColor,
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading) ...[
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: textColor,
                ),
              ),
              const SizedBox(width: 10),
            ] else if (icon != null) ...[
              Icon(icon, color: textColor, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              text,
              style: AppTypography.labelLarge.copyWith(
                color: textColor,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
