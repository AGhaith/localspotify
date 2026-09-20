import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'pressable_scale.dart';

class NeoCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;
  final Color borderColor;
  final double borderRadius;
  final double shadowOffset;

  const NeoCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(12),
    this.backgroundColor = AppColors.card,
    this.borderColor = AppColors.border,
    this.borderRadius = 14,
    this.shadowOffset = 3,
  });

  @override
  Widget build(BuildContext context) {
    final cardContent = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor == AppColors.border ? Colors.white.withValues(alpha: 0.08) : borderColor,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return PressableScale(
        onTap: onTap,
        scaleFactor: 0.97,
        child: cardContent,
      );
    }

    return cardContent;
  }
}
