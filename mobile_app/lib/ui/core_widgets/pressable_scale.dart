import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A high-performance, tactile micro-animation wrapper that provides a subtle,
/// responsive spring-down bounce and haptic feedback when pressed.
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleFactor;
  final Duration pressDuration;
  final Duration releaseDuration;
  final bool enableHaptic;
  final HitTestBehavior behavior;

  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleFactor = 0.95,
    this.pressDuration = const Duration(milliseconds: 90),
    this.releaseDuration = const Duration(milliseconds: 140),
    this.enableHaptic = true,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.pressDuration,
      reverseDuration: widget.releaseDuration,
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleFactor,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant PressableScale oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scaleFactor != widget.scaleFactor) {
      _scaleAnimation = Tween<double>(
        begin: 1.0,
        end: widget.scaleFactor,
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeOutCubic,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap != null || widget.onLongPress != null) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onTap != null || widget.onLongPress != null) {
      _controller.reverse();
    }
  }

  void _onTapCancel() {
    if (widget.onTap != null || widget.onLongPress != null) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isInteractive = widget.onTap != null || widget.onLongPress != null;

    if (!isInteractive) {
      return widget.child;
    }

    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: () {
        if (widget.enableHaptic) {
          HapticFeedback.lightImpact();
        }
        widget.onTap?.call();
      },
      onLongPress: widget.onLongPress != null
          ? () {
              if (widget.enableHaptic) {
                HapticFeedback.mediumImpact();
              }
              widget.onLongPress?.call();
            }
          : null,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
