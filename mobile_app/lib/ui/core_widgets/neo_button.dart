import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

class NeoButton extends StatefulWidget {
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
    this.height = 46,
    this.isLoading = false,
    this.borderRadius = 9999, // Pill by default
  });

  @override
  State<NeoButton> createState() => _NeoButtonState();
}

class _NeoButtonState extends State<NeoButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.isLoading;

    return GestureDetector(
      onTapDown: enabled
          ? (_) {
              HapticFeedback.lightImpact();
              setState(() => _isPressed = true);
            }
          : null,
      onTapUp: enabled ? (_) => setState(() => _isPressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _isPressed = false) : null,
      onTap: enabled ? widget.onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 70),
        height: widget.height,
        transform: Matrix4.translationValues(
          _isPressed ? 2.0 : 0.0,
          _isPressed ? 2.0 : 0.0,
          0.0,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: enabled ? widget.backgroundColor : widget.backgroundColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(color: widget.borderColor, width: 1.5),
          boxShadow: _isPressed
              ? []
              : [
                  const BoxShadow(
                    color: AppColors.shadow,
                    offset: Offset(3, 3),
                    blurRadius: 0,
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.isLoading) ...[
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: widget.textColor,
                ),
              ),
              const SizedBox(width: 10),
            ] else if (widget.icon != null) ...[
              Icon(widget.icon, color: widget.textColor, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              widget.text,
              style: AppTypography.labelLarge.copyWith(
                color: widget.textColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
