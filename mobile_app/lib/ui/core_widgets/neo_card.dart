import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

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
    this.borderRadius = 12,
    this.shadowOffset = 3,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              offset: Offset(shadowOffset, shadowOffset),
              blurRadius: 0,
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
