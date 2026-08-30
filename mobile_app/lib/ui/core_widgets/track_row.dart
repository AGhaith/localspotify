import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/duration_formatter.dart';
import '../../data/models/track.dart';
import '../../state/audio_player_provider.dart';
import '../../state/music_provider.dart';
import 'cached_cover_art.dart';

class TrackRow extends StatelessWidget {
  final Track track;
  final VoidCallback onTap;
  final int? index;
  final bool showCover;

  const TrackRow({
    super.key,
    required this.track,
    required this.onTap,
    this.index,
    this.showCover = true,
  });

  @override
  Widget build(BuildContext context) {
    final player = context.watch<AudioPlayerProvider>();
    final music = context.watch<MusicProvider>();
    final isCurrent = player.currentTrack?.id == track.id;
    final isPlaying = isCurrent && player.isPlaying;
    final isStarred = track.isStarred;
    final isDownloaded = music.isDownloaded(track.id);

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isCurrent ? AppColors.surface.withOpacity(0.5) : Colors.transparent,
          border: isCurrent
              ? const Border(left: BorderSide(color: AppColors.primary, width: 3))
              : null,
        ),
        child: Row(
          children: [
            if (index != null && !showCover) ...[
              SizedBox(
                width: 28,
                child: isPlaying
                    ? const Icon(PhosphorIconsFill.waveform, color: AppColors.primary, size: 16)
                    : Text(
                        '$index',
                        style: AppTypography.bodyMedium.copyWith(
                          color: isCurrent ? AppColors.primary : AppColors.textMuted,
                          fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
                        ),
                      ),
              ),
              const SizedBox(width: 8),
            ],
            if (showCover) ...[
              Stack(
                alignment: Alignment.center,
                children: [
                  CachedCoverArt(
                    imageUrl: music.getCoverArtUrl(track.coverArtId, size: 150),
                    width: 48,
                    height: 48,
                    borderRadius: 8,
                  ),
                  if (isPlaying)
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        PhosphorIconsFill.waveform,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleMedium.copyWith(
                      color: isCurrent ? AppColors.primary : AppColors.textPrimary,
                      fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (isDownloaded) ...[
                        const Icon(
                          PhosphorIconsFill.arrowCircleDown,
                          color: AppColors.primary,
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          '${track.artist} • ${track.album}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Like Heart Button
            IconButton(
              icon: Icon(
                isStarred ? PhosphorIconsFill.heart : PhosphorIconsRegular.heart,
                color: isStarred ? AppColors.primary : AppColors.textMuted,
                size: 20,
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                music.toggleStar(track);
              },
            ),
            // Duration
            Text(
              DurationFormatter.format(track.duration),
              style: AppTypography.bodySmall,
            ),
            const SizedBox(width: 4),
            // More options popup
            IconButton(
              icon: const Icon(
                PhosphorIconsRegular.dotsThreeVertical,
                color: AppColors.textMuted,
                size: 18,
              ),
              onPressed: () => _showTrackOptions(context, track, music),
            ),
          ],
        ),
      ),
    );
  }

  void _showTrackOptions(BuildContext context, Track track, MusicProvider music) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDownloaded = music.isDownloaded(track.id);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: CachedCoverArt(
                    imageUrl: music.getCoverArtUrl(track.coverArtId, size: 150),
                    width: 44,
                    height: 44,
                    borderRadius: 6,
                  ),
                  title: Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleMedium,
                  ),
                  subtitle: Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall,
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: Icon(
                    isDownloaded ? PhosphorIconsFill.trash : PhosphorIconsRegular.downloadSimple,
                    color: isDownloaded ? AppColors.error : AppColors.textPrimary,
                  ),
                  title: Text(
                    isDownloaded ? 'Delete Download' : 'Download Song',
                    style: AppTypography.bodyLarge.copyWith(
                      color: isDownloaded ? AppColors.error : AppColors.textPrimary,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (isDownloaded) {
                      music.deleteOfflineTrack(track.id);
                    } else {
                      music.downloadTrack(track);
                    }
                  },
                ),
                ListTile(
                  leading: Icon(
                    track.isStarred ? PhosphorIconsFill.heartBreak : PhosphorIconsRegular.heart,
                    color: AppColors.textPrimary,
                  ),
                  title: Text(
                    track.isStarred ? 'Remove from Liked Songs' : 'Save to Liked Songs',
                    style: AppTypography.bodyLarge,
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    music.toggleStar(track);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
