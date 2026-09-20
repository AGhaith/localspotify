import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
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
        horizontal: 10,
        vertical: isStandalone ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2E2E2E), width: 1.0),
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                          borderRadius: 8,
                        ),
                        const SizedBox(width: 12),
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
                const SizedBox(width: 4),
                // Play / Pause Button
                PressableScale(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    player.togglePlay();
                  },
                  scaleFactor: 0.88,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(
                      player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: AppColors.textPrimary,
                      size: 28,
                    ),
                  ),
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
        minimum: const EdgeInsets.only(bottom: 12),
        child: content,
      );
    }

    return content;
  }
}
