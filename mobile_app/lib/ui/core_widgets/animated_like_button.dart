import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/track.dart';
import '../../state/music_provider.dart';

/// An Instagram-style high-impact bouncing like button with immediate optimistic
/// UI feedback, haptic pop, and automatic error rollback.
class AnimatedLikeButton extends StatefulWidget {
  final Track track;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;
  final EdgeInsets padding;

  const AnimatedLikeButton({
    super.key,
    required this.track,
    this.size = 24.0,
    this.activeColor,
    this.inactiveColor,
    this.padding = const EdgeInsets.all(8.0),
  });

  @override
  State<AnimatedLikeButton> createState() => _AnimatedLikeButtonState();
}

class _AnimatedLikeButtonState extends State<AnimatedLikeButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    // Instagram-style overshoot bounce: 1.0 -> 0.75 -> 1.4 -> 1.0
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.75).chain(CurveTween(curve: Curves.easeIn)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.75, end: 1.35).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.35, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() async {
    final music = context.read<MusicProvider>();
    final currentlyStarred = music.isTrackStarred(widget.track.id);

    // Trigger Instagram pop animation if turning active
    HapticFeedback.lightImpact();
    if (!currentlyStarred) {
      _controller.forward(from: 0.0);
    }

    try {
      await music.toggleStar(widget.track);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update like status: $e'),
            duration: const Duration(seconds: 2),
            backgroundColor: AppColors.surface,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final isStarred = music.isTrackStarred(widget.track.id);
    final activeColor = widget.activeColor ?? AppColors.primary;
    final inactiveColor = widget.inactiveColor ?? AppColors.textSecondary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: Padding(
        padding: widget.padding,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _controller.isAnimating ? _scaleAnimation.value : 1.0,
              child: Icon(
                isStarred ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: isStarred ? activeColor : inactiveColor,
                size: widget.size,
              ),
            );
          },
        ),
      ),
    );
  }
}
