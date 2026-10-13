import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import 'pressable_scale.dart';

/// A Spotify-grade circular download button supporting:
/// - Idle: Download-arrow-in-circle outline icon
/// - Downloading: Circular progress ring with stop affordance
/// - Done: Filled white circle with black checkmark + scale-in completion animation
class DownloadActionButton extends StatefulWidget {
  final bool isDownloaded;
  final bool isDownloading;
  final double progress;
  final VoidCallback onDownload;
  final VoidCallback? onRemove;
  final VoidCallback? onCancel;
  final double size;

  const DownloadActionButton({
    super.key,
    required this.isDownloaded,
    required this.isDownloading,
    this.progress = 0.0,
    required this.onDownload,
    this.onRemove,
    this.onCancel,
    this.size = 36.0,
  });

  @override
  State<DownloadActionButton> createState() => _DownloadActionButtonState();
}

class _DownloadActionButtonState extends State<DownloadActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _completionController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _completionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _completionController,
        curve: Curves.easeOutBack,
      ),
    );

    if (widget.isDownloaded) {
      _completionController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant DownloadActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isDownloaded && widget.isDownloaded) {
      final disableAnimations =
          MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (disableAnimations) {
        _completionController.value = 1.0;
      } else {
        _completionController.forward(from: 0.0);
      }
    } else if (oldWidget.isDownloaded && !widget.isDownloaded) {
      _completionController.reset();
    }
  }

  @override
  void dispose() {
    _completionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;

    if (widget.isDownloading) {
      return Semantics(
        button: true,
        label: 'Cancel download',
        child: PressableScale(
          onTap: () {
            HapticFeedback.lightImpact();
            (widget.onCancel ?? widget.onRemove)?.call();
          },
          scaleFactor: 0.9,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            child: Center(
              child: SizedBox(
                width: size,
                height: size,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: size - 4,
                      height: size - 4,
                      child: CircularProgressIndicator(
                        value: widget.progress > 0.0 ? widget.progress : null,
                        strokeWidth: 2.2,
                        color: AppColors.primary,
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    // Stop affordance (square)
                    Container(
                      width: size * 0.32,
                      height: size * 0.32,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (widget.isDownloaded) {
      final disableAnimations =
          MediaQuery.maybeDisableAnimationsOf(context) ?? false;

      return Semantics(
        button: true,
        label: 'Remove download',
        child: PressableScale(
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onRemove?.call();
          },
          scaleFactor: 0.9,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            child: Center(
              child: AnimatedBuilder(
                animation: _completionController,
                builder: (context, child) {
                  final scale = disableAnimations
                      ? 1.0
                      : (_completionController.isAnimating
                          ? _scaleAnimation.value
                          : 1.0);
                  return Transform.scale(
                    scale: scale,
                    child: child,
                  );
                },
                child: Container(
                  width: size,
                  height: size,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.check_rounded,
                      color: AppColors.textDark,
                      size: size * 0.65,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Idle: download-arrow-in-circle outline icon
    return Semantics(
      button: true,
      label: 'Download',
      child: PressableScale(
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onDownload();
        },
        scaleFactor: 0.9,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          child: Center(
            child: SizedBox(
              width: size,
              height: size,
              child: Center(
                child: Icon(
                  Icons.arrow_circle_down_outlined,
                  color: AppColors.textSecondary,
                  size: size,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
