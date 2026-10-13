import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/album.dart';
import 'cached_cover_art.dart';
import 'pressable_scale.dart';

class AlbumCard extends StatefulWidget {
  final Album album;
  final String coverUrl;
  final VoidCallback onTap;
  final VoidCallback? onPlayTap;

  const AlbumCard({
    super.key,
    required this.album,
    required this.coverUrl,
    required this.onTap,
    this.onPlayTap,
  });

  @override
  State<AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends State<AlbumCard> {
  bool _isHovered = false;
  bool _isPressed = false;
  bool _isLongPressed = false;

  bool get _showPlayButton =>
      widget.onPlayTap != null && (_isHovered || _isPressed || _isLongPressed);

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        if (mounted) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (mounted) {
          setState(() {
            _isHovered = false;
            _isLongPressed = false;
          });
        }
      },
      cursor: SystemMouseCursors.click,
      child: Listener(
        onPointerDown: (_) {
          if (mounted) setState(() => _isPressed = true);
        },
        onPointerUp: (_) {
          if (mounted) setState(() => _isPressed = false);
        },
        onPointerCancel: (_) {
          if (mounted) setState(() => _isPressed = false);
        },
        child: PressableScale(
          onTap: () {
            if (_isLongPressed && mounted) {
              setState(() => _isLongPressed = false);
            }
            HapticFeedback.selectionClick();
            widget.onTap();
          },
          onLongPress: () {
            if (mounted) setState(() => _isLongPressed = true);
          },
          scaleFactor: 0.96,
          child: SizedBox(
            width: 140,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.cardBorderRadius,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: AppRadius.cardBorderRadius,
                            child: CachedCoverArt(
                              imageUrl: widget.coverUrl,
                              borderRadius: AppRadius.card,
                            ),
                          ),
                        ),
                        if (widget.onPlayTap != null)
                          Positioned(
                            right: AppSpacing.sm,
                            bottom: AppSpacing.sm,
                            child: AnimatedSlide(
                              duration: const Duration(milliseconds: 150),
                              curve: Curves.easeOutCubic,
                              offset: _showPlayButton
                                  ? Offset.zero
                                  : const Offset(0, 0.2),
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 150),
                                curve: Curves.easeOutCubic,
                                opacity: _showPlayButton ? 1.0 : 0.0,
                                child: IgnorePointer(
                                  ignoring: !_showPlayButton,
                                  child: PressableScale(
                                    onTap: () {
                                      if (_isLongPressed && mounted) {
                                        setState(() => _isLongPressed = false);
                                      }
                                      HapticFeedback.heavyImpact();
                                      widget.onPlayTap!();
                                    },
                                    scaleFactor: 0.88,
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.35),
                                            offset: const Offset(0, 4),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.play_arrow_rounded,
                                          color: AppColors.textDark,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  widget.album.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyLarge.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.album.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
