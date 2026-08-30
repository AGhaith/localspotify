import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../state/audio_player_provider.dart';
import '../../../state/music_provider.dart';
import '../../core_widgets/cached_cover_art.dart';
import 'now_playing_sheet.dart';

class MiniPlayerBar extends StatelessWidget {
  const MiniPlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<AudioPlayerProvider>();
    final music = context.watch<MusicProvider>();
    final track = player.currentTrack;

    if (track == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const NowPlayingSheet(),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF14151E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderStrong, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              offset: Offset(0, 4),
              blurRadius: 16,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  CachedCoverArt(
                    imageUrl: music.getCoverArtUrl(track.coverArtId, size: 120),
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
                          style: AppTypography.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  // Like Button
                  IconButton(
                    icon: Icon(
                      track.isStarred ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: track.isStarred ? AppColors.primary : AppColors.textSecondary,
                      size: 22,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      music.toggleStar(track);
                    },
                  ),
                  // Play / Pause Button
                  IconButton(
                    icon: Icon(
                      player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: AppColors.textPrimary,
                      size: 28,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      player.togglePlay();
                    },
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
                backgroundColor: Colors.white.withOpacity(0.08),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
