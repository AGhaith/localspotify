import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dynamic_palette_service.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../../data/models/track.dart';
import '../../../state/audio_player_provider.dart';
import '../../../state/music_provider.dart';
import '../../core_widgets/animated_like_button.dart';
import '../../core_widgets/cached_cover_art.dart';
import '../../core_widgets/circular_download_button.dart';
import '../../core_widgets/pressable_scale.dart';
import '../library/album_detail_screen.dart';
import '../library/artist_detail_screen.dart';
import '../settings/audio_equalizer_screen.dart';
import 'lyrics_view.dart';
import 'queue_sheet.dart';

class NowPlayingSheet extends StatefulWidget {
  const NowPlayingSheet({super.key});

  @override
  State<NowPlayingSheet> createState() => _NowPlayingSheetState();
}

class _NowPlayingSheetState extends State<NowPlayingSheet> {
  double? _dragValue;
  PaletteColors? _paletteColors;
  String? _lastTrackId;

  void _loadPalette(Track track, MusicProvider music) {
    if (_lastTrackId == track.id) return;
    _lastTrackId = track.id;
    final coverArtUrl = music.getCoverArtUrl(track.coverArtId, albumName: track.album, size: 250);
    DynamicPaletteService().extractColors(
      key: (track.coverArtId != null && track.coverArtId!.isNotEmpty) ? track.coverArtId! : track.id,
      imageUrl: coverArtUrl,
      localImagePath: track.localCoverArtPath,
    ).then((palette) {
      if (mounted) setState(() => _paletteColors = palette);
    });
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<AudioPlayerProvider>();
    final music = context.watch<MusicProvider>();
    final track = player.currentTrack;

    if (track == null) return const SizedBox.shrink();

    _loadPalette(track, music);

    final coverArtUrl = music.getCoverArtUrl(track.coverArtId, albumName: track.album, size: 600);
    final currentSeconds = _dragValue != null
        ? (_dragValue! * player.duration.inSeconds).toInt()
        : player.position.inSeconds;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      height: MediaQuery.of(context).size.height * 0.94,
      decoration: BoxDecoration(
        gradient: _paletteColors?.toAmbientGradient() ??
            const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1B142E), Color(0xFF0F0B1A), Color(0xFF07070B)],
              stops: [0.0, 0.55, 1.0],
            ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),

            // Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textPrimary, size: 28),
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (track.albumId != null && track.albumId!.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AlbumDetailScreen(albumId: track.albumId!),
                            ),
                          );
                        }
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'PLAYING FROM ALBUM',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.textMuted,
                              letterSpacing: 1.2,
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            track.album,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: AppTypography.titleMedium.copyWith(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Equalizer & Audio Options Icon
                      IconButton(
                        icon: const Icon(Icons.tune_rounded, color: AppColors.textSecondary, size: 20),
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _showEqualizerSheet(context),
                      ),
                      const SizedBox(width: 4),
                      // Sleep Timer icon
                      IconButton(
                        icon: Icon(
                          Icons.bedtime_rounded,
                          color: player.hasActiveSleepTimer ? AppColors.primary : AppColors.textSecondary,
                          size: 20,
                        ),
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _showSleepTimerDialog(context, player),
                      ),
                      const SizedBox(width: 4),
                      // Queue Sheet Icon
                      IconButton(
                        icon: const Icon(Icons.queue_music_rounded, color: AppColors.textPrimary, size: 22),
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _showQueue(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    // High-Res Artwork with Swipe-to-Skip
                    Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: GestureDetector(
                          onHorizontalDragEnd: (details) {
                            final velocity = details.primaryVelocity ?? 0;
                            if (velocity < -250) {
                              // Swipe Left -> Skip Next
                              HapticFeedback.lightImpact();
                              player.skipNext();
                            } else if (velocity > 250) {
                              // Swipe Right -> Skip Previous
                              HapticFeedback.lightImpact();
                              player.skipPrevious();
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.0),
                              boxShadow: [
                                BoxShadow(
                                  color: (_paletteColors?.ambientTop ?? AppColors.primary).withValues(alpha: 0.35),
                                  offset: const Offset(0, 14),
                                  blurRadius: 36,
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  offset: const Offset(0, 6),
                                  blurRadius: 18,
                                ),
                              ],
                            ),
                            child: CachedCoverArt(
                              imageUrl: coverArtUrl,
                              localImagePath: track.localCoverArtPath,
                              borderRadius: 14,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Track Info, Download Button & Like Button
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.displayMedium.copyWith(fontSize: 22),
                              ),
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: () {
                                  if (track.artistId != null && track.artistId!.isNotEmpty) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ArtistDetailScreen(artistId: track.artistId!),
                                      ),
                                    );
                                  }
                                },
                                child: Text(
                                  track.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Circular Download Button with real-time progress ring
                        CircularDownloadButton(track: track, size: 34),
                        const SizedBox(width: 8),
                        // Instagram-style Popping Like Button
                        AnimatedLikeButton(track: track, size: 28),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Scrubber Slider
                    Column(
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3.5,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                            activeTrackColor: AppColors.primary,
                            inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
                            thumbColor: AppColors.primary,
                            overlayColor: AppColors.primary.withValues(alpha: 0.2),
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
                          padding: const EdgeInsets.symmetric(horizontal: 4),
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

                    const SizedBox(height: 12),

                    // Controls Row (Shuffle, Previous, Play/Pause, Next, Repeat)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        PressableScale(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            player.toggleShuffle();
                          },
                          scaleFactor: 0.88,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(
                              Icons.shuffle_rounded,
                              color: player.isShuffle ? AppColors.primary : AppColors.textMuted,
                              size: 22,
                            ),
                          ),
                        ),
                        PressableScale(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            player.skipPrevious();
                          },
                          scaleFactor: 0.88,
                          child: const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Icon(
                              Icons.skip_previous_rounded,
                              color: AppColors.textPrimary,
                              size: 34,
                            ),
                          ),
                        ),
                        // Big Play / Pause Button with responsive micro-animation
                        PressableScale(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            player.togglePlay();
                          },
                          scaleFactor: 0.92,
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
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
                        PressableScale(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            player.skipNext();
                          },
                          scaleFactor: 0.88,
                          child: const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Icon(
                              Icons.skip_next_rounded,
                              color: AppColors.textPrimary,
                              size: 34,
                            ),
                          ),
                        ),
                        PressableScale(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            player.toggleRepeat();
                          },
                          scaleFactor: 0.88,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(
                              player.repeatMode == AppRepeatMode.one
                                  ? Icons.repeat_one_rounded
                                  : Icons.repeat_rounded,
                              color: player.repeatMode != AppRepeatMode.off
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Interactive Lyrics Card styled with album-derived dynamic palette
                    LyricsView(track: track, paletteColors: _paletteColors),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEqualizerSheet(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const AudioEqualizerScreen()),
    );
  }

  void _showQueue(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const QueueSheet(),
    );
  }

  void _showSleepTimerDialog(BuildContext context, AudioPlayerProvider player) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bedtime_rounded, color: AppColors.primary, size: 22),
                    const SizedBox(width: 8),
                    Text('Sleep Timer', style: AppTypography.titleLarge),
                  ],
                ),
                if (player.hasActiveSleepTimer) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Active: ${player.sleepTimerRemaining?.inMinutes ?? 0} minutes remaining',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.primary),
                  ),
                ],
                const Divider(height: 24),
                _sleepTimerOption(ctx, player, '15 minutes', const Duration(minutes: 15)),
                _sleepTimerOption(ctx, player, '30 minutes', const Duration(minutes: 30)),
                _sleepTimerOption(ctx, player, '45 minutes', const Duration(minutes: 45)),
                _sleepTimerOption(ctx, player, '1 hour', const Duration(hours: 1)),
                if (player.hasActiveSleepTimer)
                  ListTile(
                    title: Text(
                      'Turn Off Timer',
                      style: AppTypography.titleMedium.copyWith(color: AppColors.error),
                    ),
                    onTap: () {
                      player.cancelSleepTimer();
                      Navigator.pop(ctx);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sleepTimerOption(
    BuildContext ctx,
    AudioPlayerProvider player,
    String title,
    Duration duration,
  ) {
    return ListTile(
      title: Text(title, style: AppTypography.bodyLarge),
      onTap: () {
        HapticFeedback.selectionClick();
        player.setSleepTimer(duration);
        Navigator.pop(ctx);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Music will stop in $title'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }
}
