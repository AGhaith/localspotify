import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dynamic_palette_service.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../../data/models/track.dart';
import '../../../state/audio_player_provider.dart';
import '../../../state/music_provider.dart';
import '../../core_widgets/animated_like_button.dart';
import '../../core_widgets/cached_cover_art.dart';
import '../../core_widgets/download_action_button.dart';
import '../../core_widgets/pressable_scale.dart';
import '../library/album_detail_screen.dart';
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
              colors: [
                AppColors.surface,
                AppColors.card,
                AppColors.background,
              ],
              stops: [0.0, 0.55, 1.0],
            ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          // Subtle dark scrim gradient at top of ambient background for WCAG AA contrast
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 140,
            child: Container(
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.72),
                    Colors.black.withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),

          SafeArea(
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
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ),

                // Header Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down_rounded,
                            color: Colors.white, size: 28),
                        constraints:
                            const BoxConstraints(minWidth: 44, minHeight: 44),
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (track.albumId != null &&
                                track.albumId!.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AlbumDetailScreen(albumId: track.albumId!),
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
                                  color: Colors.white70,
                                  letterSpacing: 1.2,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
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
                                style: AppTypography.titleMedium.copyWith(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Equalizer & Audio Options Icon
                          IconButton(
                            icon: const Icon(Icons.tune_rounded,
                                color: Colors.white70, size: 20),
                            constraints: const BoxConstraints(
                                minWidth: 44, minHeight: 44),
                            tooltip: 'Equalizer',
                            onPressed: () => _showEqualizerSheet(context),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          // Sleep Timer icon
                          IconButton(
                            icon: Icon(
                              Icons.bedtime_rounded,
                              color: player.hasActiveSleepTimer
                                  ? AppColors.primary
                                  : Colors.white70,
                              size: 20,
                            ),
                            constraints: const BoxConstraints(
                                minWidth: 44, minHeight: 44),
                            tooltip: 'Sleep timer',
                            onPressed: () =>
                                _showSleepTimerDialog(context, player),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sectionGap),
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.md),
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
                                  color: Colors.black.withValues(alpha: 0.5),
                                  offset: const Offset(0, 14),
                                  blurRadius: 36,
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
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

                    const SizedBox(height: AppSpacing.sectionGap),

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
                              const SizedBox(height: AppSpacing.xs),
                              GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  if (track.individualArtists.length > 1) {
                                    _showMultipleArtistsSheet(context, track);
                                  } else {
                                    context.read<MusicProvider>().openArtistByName(context, track.primaryArtist);
                                  }
                                },
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        track.artist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
                                      ),
                                    ),
                                    if (track.individualArtists.length > 1) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${track.individualArtists.length} Artists',
                                          style: AppTypography.labelSmall.copyWith(
                                            color: AppColors.primary,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Download Button with outline idle, progress ring, and done checkmark
                        DownloadActionButton(
                          isDownloaded: music.isDownloaded(track.id),
                          isDownloading:
                              music.downloadingEntityId == track.id,
                          progress: music.downloadingProgress,
                          size: 34,
                          onDownload: () => music.downloadTrack(track),
                          onRemove: () => music.deleteOfflineTrack(track.id),
                          onCancel: () => music.deleteOfflineTrack(track.id),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        // Instagram-style Popping Like Button
                        AnimatedLikeButton(track: track, size: 28),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Scrubber Slider
                    Column(
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3.5,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 14),
                            activeTrackColor: AppColors.primary,
                            inactiveTrackColor:
                                Colors.white.withValues(alpha: 0.12),
                            thumbColor: AppColors.primary,
                            overlayColor:
                                AppColors.primary.withValues(alpha: 0.2),
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DurationFormatter.format(currentSeconds),
                                style: AppTypography.bodySmall,
                              ),
                              Text(
                                DurationFormatter.format(
                                    player.duration.inSeconds),
                                style: AppTypography.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Controls Row (Shuffle, Previous, Play/Pause, Next, Repeat)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Animated Shuffle Button
                        _ShuffleButton(
                          isShuffle: player.isShuffle,
                          onTap: player.toggleShuffle,
                        ),
                        // Nudgeable Skip Previous Button (-5px slide nudge)
                        _NudgeIconButton(
                          icon: Icons.skip_previous_rounded,
                          nudgeOffset: -5.0,
                          tooltip: 'Previous',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            player.skipPrevious();
                          },
                          size: 36,
                        ),
                        // Big Play / Pause Button with AnimatedIcon morph & scale press feedback
                        _PlayerBigPlayPauseButton(
                          isPlaying: player.isPlaying,
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            player.togglePlay();
                          },
                        ),
                        // Nudgeable Skip Next Button (+5px slide nudge)
                        _NudgeIconButton(
                          icon: Icons.skip_next_rounded,
                          nudgeOffset: 5.0,
                          tooltip: 'Next',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            player.skipNext();
                          },
                          size: 36,
                        ),
                        // Animated Repeat Button with Repeat-One variant & active dot
                        _RepeatButton(
                          repeatMode: player.repeatMode,
                          onTap: player.toggleRepeat,
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.xs),

                    // Secondary Bottom Bar Row: [Devices on left ... Share + Queue on right]
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Left: Devices / Audio output affordance
                          PressableScale(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Playing on this device'),
                                  duration: Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: AppColors.surface,
                                ),
                              );
                            },
                            scaleFactor: 0.9,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.xs,
                                  horizontal: AppSpacing.xs),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.devices_rounded,
                                    color: AppColors.textSecondary,
                                    size: 19,
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Text(
                                    'This Device',
                                    style: AppTypography.labelSmall.copyWith(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Right: Share and Queue icons
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.share_rounded,
                                  color: AppColors.textSecondary,
                                  size: 20,
                                ),
                                constraints: const BoxConstraints(
                                    minWidth: 40, minHeight: 40),
                                tooltip: 'Share',
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  Clipboard.setData(
                                    ClipboardData(
                                        text:
                                            '${track.title} • ${track.artist}'),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Copied "${track.title}" to clipboard'),
                                      duration: const Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                      backgroundColor: AppColors.surface,
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.queue_music_rounded,
                                  color: AppColors.textPrimary,
                                  size: 22,
                                ),
                                constraints: const BoxConstraints(
                                    minWidth: 40, minHeight: 40),
                                tooltip: 'Queue',
                                onPressed: () => _showQueue(context),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.sectionGap),

                    // Interactive Lyrics Card styled with album-derived dynamic palette
                    LyricsView(track: track, paletteColors: _paletteColors),

                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ],
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
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bedtime_rounded, color: AppColors.primary, size: 22),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Sleep Timer', style: AppTypography.titleLarge),
                  ],
                ),
                if (player.hasActiveSleepTimer) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Active: ${player.sleepTimerRemaining?.inMinutes ?? 0} minutes remaining',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.primary),
                  ),
                ],
                const Divider(height: AppSpacing.sectionGap),
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

  void _showMultipleArtistsSheet(BuildContext context, Track track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: AppSpacing.sm),
                  child: Row(
                    children: [
                      const Icon(Icons.people_alt_rounded, color: AppColors.primary, size: 22),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Artists',
                        style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Text(
                        '${track.individualArtists.length} found',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                const Divider(color: AppColors.border),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: track.individualArtists.length,
                    itemBuilder: (context, index) {
                      final artistName = track.individualArtists[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.card,
                          child: Text(
                            artistName.isNotEmpty ? artistName[0].toUpperCase() : '?',
                            style: AppTypography.titleMedium.copyWith(color: AppColors.primary),
                          ),
                        ),
                        title: Text(
                          artistName,
                          style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'View artist profile & tracks',
                          style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                        onTap: () {
                          Navigator.pop(ctx);
                          context.read<MusicProvider>().openArtistByName(context, artistName);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PlayerBigPlayPauseButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onTap;

  const _PlayerBigPlayPauseButton({
    required this.isPlaying,
    required this.onTap,
  });

  @override
  State<_PlayerBigPlayPauseButton> createState() =>
      _PlayerBigPlayPauseButtonState();
}

class _PlayerBigPlayPauseButtonState extends State<_PlayerBigPlayPauseButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    if (widget.isPlaying) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant _PlayerBigPlayPauseButton oldWidget) {
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
      onTap: widget.onTap,
      scaleFactor: 0.92,
      child: Container(
        width: 64,
        height: 64,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: AnimatedIcon(
            icon: AnimatedIcons.play_pause,
            progress: _controller,
            color: AppColors.textDark,
            size: 36,
          ),
        ),
      ),
    );
  }
}

class _NudgeIconButton extends StatefulWidget {
  final IconData icon;
  final double nudgeOffset;
  final VoidCallback onTap;
  final double size;
  final String tooltip;

  const _NudgeIconButton({
    required this.icon,
    required this.nudgeOffset,
    required this.onTap,
    this.size = 34,
    required this.tooltip,
  });

  @override
  State<_NudgeIconButton> createState() => _NudgeIconButtonState();
}

class _NudgeIconButtonState extends State<_NudgeIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _animation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: widget.nudgeOffset)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: widget.nudgeOffset, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 60,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!disableAnimations) {
      _controller.forward(from: 0.0);
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: _handleTap,
      scaleFactor: 0.88,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) => Transform.translate(
            offset:
                Offset(_controller.isAnimating ? _animation.value : 0.0, 0),
            child: child,
          ),
          child: Icon(
            widget.icon,
            color: AppColors.textPrimary,
            size: widget.size,
          ),
        ),
      ),
    );
  }
}

class _ShuffleButton extends StatelessWidget {
  final bool isShuffle;
  final VoidCallback onTap;

  const _ShuffleButton({
    required this.isShuffle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return PressableScale(
      onTap: onTap,
      scaleFactor: 0.88,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: disableAnimations
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale:
                      Tween<double>(begin: 0.85, end: 1.0).animate(animation),
                  child: child,
                ),
              ),
              child: Icon(
                Icons.shuffle_rounded,
                key: ValueKey('shuffle_$isShuffle'),
                color: isShuffle ? AppColors.primary : AppColors.textMuted,
                size: 22,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedOpacity(
              duration: disableAnimations
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              opacity: isShuffle ? 1.0 : 0.0,
              child: Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RepeatButton extends StatelessWidget {
  final AppRepeatMode repeatMode;
  final VoidCallback onTap;

  const _RepeatButton({
    required this.repeatMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final isActive = repeatMode != AppRepeatMode.off;
    final isOne = repeatMode == AppRepeatMode.one;
    final iconData = isOne ? Icons.repeat_one_rounded : Icons.repeat_rounded;

    return PressableScale(
      onTap: onTap,
      scaleFactor: 0.88,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: disableAnimations
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale:
                      Tween<double>(begin: 0.85, end: 1.0).animate(animation),
                  child: child,
                ),
              ),
              child: Icon(
                iconData,
                key: ValueKey('repeat_$repeatMode'),
                color: isActive ? AppColors.primary : AppColors.textMuted,
                size: 24,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedOpacity(
              duration: disableAnimations
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              opacity: isActive ? 1.0 : 0.0,
              child: Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

