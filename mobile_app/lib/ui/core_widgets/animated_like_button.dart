import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/track.dart';
import '../../state/music_provider.dart';

/// A sleek Spotify-grade like button featuring:
/// - Like: Heart scale pop (1.0 -> 1.25 -> 1.0) with filled transition + subtle circular burst ring
/// - Unlike: Quick shrink-and-outline (1.0 -> 0.8 -> 1.0)
/// - Light tactile haptic feedback
/// - Full respect for MediaQuery.disableAnimations (reduced motion)
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
    with TickerProviderStateMixin {
  late final AnimationController _likeController;
  late final Animation<double> _likeScaleAnimation;
  late final Animation<double> _burstScaleAnimation;
  late final Animation<double> _burstOpacityAnimation;

  late final AnimationController _unlikeController;
  late final Animation<double> _unlikeScaleAnimation;

  @override
  void initState() {
    super.initState();

    // Like Pop: 1.0 -> 1.25 -> 1.0 (260ms)
    _likeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _likeScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.25)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.25, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 60,
      ),
    ]).animate(_likeController);

    // Subtle burst ring: scale 0.7 -> 1.45, opacity 0.8 -> 0.0
    _burstScaleAnimation = Tween<double>(begin: 0.7, end: 1.45).animate(
      CurvedAnimation(
        parent: _likeController,
        curve: Curves.easeOutQuad,
      ),
    );
    _burstOpacityAnimation = Tween<double>(begin: 0.8, end: 0.0).animate(
      CurvedAnimation(
        parent: _likeController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );

    // Unlike shrink: 1.0 -> 0.8 -> 1.0 (180ms)
    _unlikeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _unlikeScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.8)
            .chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.8, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 55,
      ),
    ]).animate(_unlikeController);
  }

  @override
  void dispose() {
    _likeController.dispose();
    _unlikeController.dispose();
    super.dispose();
  }

  void _handleTap() async {
    final music = context.read<MusicProvider>();
    final currentlyStarred = music.isTrackStarred(widget.track.id);
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    HapticFeedback.lightImpact();

    if (!disableAnimations) {
      if (!currentlyStarred) {
        _unlikeController.reset();
        _likeController.forward(from: 0.0);
      } else {
        _likeController.reset();
        _unlikeController.forward(from: 0.0);
      }
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
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return Semantics(
      button: true,
      selected: isStarred,
      label: isStarred ? 'Unlike' : 'Like',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        child: Padding(
          padding: widget.padding,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Subtle circular burst ring (only during like animation)
              if (!disableAnimations)
                AnimatedBuilder(
                  animation: _likeController,
                  builder: (context, child) {
                    if (!_likeController.isAnimating) {
                      return const SizedBox.shrink();
                    }
                    return Opacity(
                      opacity: _burstOpacityAnimation.value.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: _burstScaleAnimation.value,
                        child: Container(
                          width: widget.size * 1.3,
                          height: widget.size * 1.3,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: activeColor.withValues(alpha: 0.8),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

              // Heart Icon with Scale Pop
              AnimatedBuilder(
                animation: Listenable.merge([_likeController, _unlikeController]),
                builder: (context, child) {
                  double scale = 1.0;
                  if (!disableAnimations) {
                    if (_likeController.isAnimating) {
                      scale = _likeScaleAnimation.value;
                    } else if (_unlikeController.isAnimating) {
                      scale = _unlikeScaleAnimation.value;
                    }
                  }

                  return Transform.scale(
                    scale: scale,
                    child: Icon(
                      isStarred
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: isStarred ? activeColor : inactiveColor,
                      size: widget.size,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
