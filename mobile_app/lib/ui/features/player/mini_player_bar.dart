import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../state/audio_player_provider.dart';
import '../../../state/music_provider.dart';
import '../../core_widgets/animated_like_button.dart';
import '../../core_widgets/cached_cover_art.dart';
import '../../core_widgets/pressable_scale.dart';
import 'now_playing_sheet.dart';

class MiniPlayerBar extends StatelessWidget {
  final bool isStandalone;

  const MiniPlayerBar({
    super.key,
    this.isStandalone = false,
  });

  @override
  Widget build(BuildContext context) {
    final player = context.watch<AudioPlayerProvider>();
    final music = context.watch<MusicProvider>();
    final track = player.currentTrack;

    if (track == null) return const SizedBox.shrink();

    final content = Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: isStandalone ? AppSpacing.xs : 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            offset: Offset(0, 4),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
            child: Row(
              children: [
                // Tap cover art / title to open Now Playing Sheet
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const NowPlayingSheet(),
                      );
                    },
                    child: Row(
                      children: [
                        CachedCoverArt(
                          imageUrl: music.getCoverArtUrl(track.coverArtId, size: 120),
                          localImagePath: track.localCoverArtPath,
                          width: 44,
                          height: 44,
                          borderRadius: AppRadius.coverSmall,
                        ),
                        const SizedBox(width: AppSpacing.rowGap),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.titleMedium.copyWith(fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                track.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Instagram-style Like Button
                AnimatedLikeButton(track: track, size: 22),
                const SizedBox(width: AppSpacing.xs),
                // Play / Pause Button with AnimatedIcon morph & scale press feedback
                _MiniPlayerPlayPauseButton(
                  isPlaying: player.isPlaying,
                  onTap: player.togglePlay,
                ),
              ],
            ),
          ),
          // Bottom Progress Line
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            child: LinearProgressIndicator(
              value: player.progress,
              minHeight: 2.5,
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ],
      ),
    );

    if (isStandalone) {
      return SafeArea(
        top: false,
        bottom: true,
        minimum: const EdgeInsets.only(bottom: AppSpacing.rowGap),
        child: content,
      );
    }

    return content;
  }
}

class _MiniPlayerPlayPauseButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onTap;

  const _MiniPlayerPlayPauseButton({
    required this.isPlaying,
    required this.onTap,
  });

  @override
  State<_MiniPlayerPlayPauseButton> createState() =>
      _MiniPlayerPlayPauseButtonState();
}

class _MiniPlayerPlayPauseButtonState extends State<_MiniPlayerPlayPauseButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    if (widget.isPlaying) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant _MiniPlayerPlayPauseButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying) {
      final disableAnimations =
          MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (disableAnimations) {
        _controller.value = widget.isPlaying ? 1.0 : 0.0;
      } else {
        if (widget.isPlaying) {
          _controller.forward();
        } else {
          _controller.reverse();
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      scaleFactor: 0.88,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: AnimatedIcon(
          icon: AnimatedIcons.play_pause,
          progress: _controller,
          color: AppColors.textPrimary,
          size: 28,
        ),
      ),
    );
  }
}

