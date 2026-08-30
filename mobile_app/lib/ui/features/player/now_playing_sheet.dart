import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../../state/audio_player_provider.dart';
import '../../../state/music_provider.dart';
import '../../core_widgets/cached_cover_art.dart';

class NowPlayingSheet extends StatefulWidget {
  const NowPlayingSheet({super.key});

  @override
  State<NowPlayingSheet> createState() => _NowPlayingSheetState();
}

class _NowPlayingSheetState extends State<NowPlayingSheet> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<AudioPlayerProvider>();
    final music = context.watch<MusicProvider>();
    final track = player.currentTrack;

    if (track == null) return const SizedBox.shrink();

    final coverArtUrl = music.getCoverArtUrl(track.coverArtId, size: 600);
    final currentSeconds = _dragValue != null
        ? (_dragValue! * player.duration.inSeconds).toInt()
        : player.position.inSeconds;

    return Container(
      height: MediaQuery.of(context).size.height * 0.94,
      decoration: const BoxDecoration(
        color: Color(0xFF0A0B10),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
            // Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textPrimary, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Column(
                    children: [
                      Text(
                        'PLAYING FROM ALBUM',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textMuted,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        track.album,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMedium.copyWith(fontSize: 13),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert_rounded, color: AppColors.textPrimary),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            const Spacer(flex: 1),
            // High-Res Artwork
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderStrong, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.shadow,
                          offset: Offset(6, 6),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: CachedCoverArt(
                      imageUrl: coverArtUrl,
                      borderRadius: 14,
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(flex: 1),
            // Track Info & Like Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.displayMedium.copyWith(fontSize: 20),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      track.isStarred ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: track.isStarred ? AppColors.primary : AppColors.textSecondary,
                      size: 26,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      music.toggleStar(track);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Timeline Scrubber Slider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3.5,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                      activeTrackColor: AppColors.primary,
                      inactiveTrackColor: Colors.white.withOpacity(0.12),
                      thumbColor: AppColors.primary,
                      overlayColor: AppColors.primary.withOpacity(0.2),
                    ),
                    child: Slider(
                      value: _dragValue ?? player.progress,
                      onChanged: (val) {
                        setState(() => _dragValue = val);
                      },
                      onChangeEnd: (val) {
                        player.seekPercent(val);
                        setState(() => _dragValue = null);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DurationFormatter.format(currentSeconds),
                          style: AppTypography.bodySmall,
                        ),
                        Text(
                          DurationFormatter.format(player.duration.inSeconds),
                          style: AppTypography.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Controls (Shuffle, Previous, Play/Pause, Next, Repeat)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.shuffle_rounded,
                      color: player.isShuffle ? AppColors.primary : AppColors.textMuted,
                      size: 22,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      player.toggleShuffle();
                    },
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.skip_previous_rounded,
                      color: AppColors.textPrimary,
                      size: 32,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      player.skipPrevious();
                    },
                  ),
                  // Big Play/Pause Button
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      player.togglePlay();
                    },
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.shadow,
                            offset: Offset(3, 3),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: AppColors.textDark,
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.skip_next_rounded,
                      color: AppColors.textPrimary,
                      size: 32,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      player.skipNext();
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      player.repeatMode == AppRepeatMode.one
                          ? Icons.repeat_one_rounded
                          : Icons.repeat_rounded,
                      color: player.repeatMode != AppRepeatMode.off
                          ? AppColors.primary
                          : AppColors.textMuted,
                      size: 24,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      player.toggleRepeat();
                    },
                  ),
                ],
              ),
            ),
            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }
}
