import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/duration_formatter.dart';
import '../../data/models/track.dart';
import '../../state/audio_player_provider.dart';
import '../../state/music_provider.dart';
import '../features/library/album_detail_screen.dart';
import '../features/library/artist_detail_screen.dart';
import 'animated_like_button.dart';
import 'cached_cover_art.dart';
import 'circular_download_button.dart';
import 'pressable_scale.dart';

class TrackRow extends StatefulWidget {
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
  State<TrackRow> createState() => _TrackRowState();
}

class _TrackRowState extends State<TrackRow> with TickerProviderStateMixin {
  late final AnimationController _translateController;
  late Animation<double> _translateAnimation;

  late final AnimationController _iconScaleController;
  late final Animation<double> _iconScaleAnimation;

  double _rawDrag = 0.0;
  double _dragOffset = 0.0;
  bool _thresholdCrossed = false;

  @override
  void initState() {
    super.initState();
    _translateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _translateAnimation = const AlwaysStoppedAnimation<double>(0.0);
    _translateController.addListener(() {
      if (mounted) {
        setState(() {
          _dragOffset = _translateAnimation.value;
        });
      }
    });

    _iconScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _iconScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.25,
    ).animate(
      CurvedAnimation(
        parent: _iconScaleController,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant TrackRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.id != widget.track.id) {
      if (_translateController.isAnimating) {
        _translateController.stop();
      }
      _rawDrag = 0.0;
      _dragOffset = 0.0;
      _thresholdCrossed = false;
      _iconScaleController.reset();
    }
  }

  @override
  void dispose() {
    _translateController.dispose();
    _iconScaleController.dispose();
    super.dispose();
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    if (_translateController.isAnimating) {
      _translateController.stop();
    }
    _rawDrag = _dragOffset;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details, double rowWidth) {
    final delta = details.primaryDelta ?? details.delta.dx;
    if (_rawDrag == 0 && delta <= 0) {
      return;
    }

    _rawDrag = (_rawDrag + delta).clamp(0.0, rowWidth * 1.5);

    final resistanceThreshold = rowWidth * 0.35;
    double newOffset;
    if (_rawDrag <= resistanceThreshold) {
      newOffset = _rawDrag;
    } else {
      final excess = _rawDrag - resistanceThreshold;
      newOffset = resistanceThreshold + (excess * 0.25);
    }

    final threshold = rowWidth * 0.25;
    if (newOffset >= threshold && !_thresholdCrossed) {
      _thresholdCrossed = true;
      HapticFeedback.mediumImpact();
      _iconScaleController.forward();
    } else if (newOffset < threshold && _thresholdCrossed) {
      _thresholdCrossed = false;
      _iconScaleController.reverse();
    }

    setState(() {
      _dragOffset = newOffset;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details, double rowWidth) {
    final threshold = rowWidth * 0.25;
    final passedThreshold = _thresholdCrossed || _dragOffset >= threshold;

    if (passedThreshold) {
      context.read<AudioPlayerProvider>().addToQueue(widget.track);
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Added to queue'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    _animateReset();
  }

  void _onHorizontalDragCancel() {
    _animateReset();
  }

  void _animateReset() {
    _thresholdCrossed = false;
    _iconScaleController.reverse();

    if (_dragOffset == 0.0) {
      _rawDrag = 0.0;
      return;
    }

    _translateAnimation = Tween<double>(
      begin: _dragOffset,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: _translateController,
        curve: Curves.easeOutBack,
      ),
    );

    _rawDrag = 0.0;
    _translateController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<AudioPlayerProvider>();
    final music = context.watch<MusicProvider>();
    final isCurrent = player.currentTrack?.id == widget.track.id;
    final isPlaying = isCurrent && player.isPlaying;
    final isDownloaded = music.isDownloaded(widget.track.id);

    return LayoutBuilder(
      builder: (context, constraints) {
        final rowWidth = constraints.maxWidth;
        final stripWidth = _dragOffset.clamp(0.0, rowWidth);

        return GestureDetector(
          key: Key('track_row_${widget.track.id}_${widget.index ?? 0}'),
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: _onHorizontalDragStart,
          onHorizontalDragUpdate: (details) => _onHorizontalDragUpdate(details, rowWidth),
          onHorizontalDragEnd: (details) => _onHorizontalDragEnd(details, rowWidth),
          onHorizontalDragCancel: _onHorizontalDragCancel,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              if (stripWidth > 0)
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: stripWidth,
                      height: double.infinity,
                      child: ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.centerLeft,
                          minWidth: rowWidth,
                          maxWidth: rowWidth,
                          child: Container(
                            color: AppColors.primary,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 20),
                            child: ScaleTransition(
                              scale: _iconScaleAnimation,
                              child: const Icon(
                                Icons.queue_music_rounded,
                                color: Colors.black,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Transform.translate(
                offset: Offset(_dragOffset, 0),
                child: PressableScale(
                  onTap: widget.onTap,
                  scaleFactor: 0.98,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isCurrent ? AppColors.surface.withValues(alpha: 0.4) : Colors.transparent,
                      border: isCurrent
                          ? const Border(left: BorderSide(color: AppColors.primary, width: 3))
                          : null,
                    ),
                    child: Row(
                      children: [
                        if (widget.index != null && !widget.showCover) ...[
                          SizedBox(
                            width: 28,
                            child: isPlaying
                                ? const Icon(Icons.graphic_eq_rounded, color: AppColors.primary, size: 18)
                                : Text(
                                    '${widget.index}',
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: isCurrent ? AppColors.primary : AppColors.textMuted,
                                      fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (widget.showCover) ...[
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              CachedCoverArt(
                                imageUrl: music.getCoverArtUrl(widget.track.coverArtId, albumName: widget.track.album, size: 150),
                                localImagePath: widget.track.localCoverArtPath,
                                width: 48,
                                height: 48,
                                borderRadius: 8,
                              ),
                              if (isPlaying)
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.graphic_eq_rounded,
                                    color: AppColors.primary,
                                    size: 22,
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
                                widget.track.title,
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
                                      Icons.check_circle_rounded,
                                      color: AppColors.primary,
                                      size: 13,
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Expanded(
                                    child: Text(
                                      '${widget.track.artist} • ${widget.track.album}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Optimistic Animated Like Button
                        AnimatedLikeButton(track: widget.track, size: 20),
                        const SizedBox(width: 4),
                        // Duration
                        Text(
                          DurationFormatter.format(widget.track.duration),
                          style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                        ),
                        const SizedBox(width: 2),
                        // 3-Dot Options
                        IconButton(
                          icon: const Icon(
                            Icons.more_vert_rounded,
                            color: AppColors.textMuted,
                            size: 20,
                          ),
                          onPressed: () => _showTrackOptions(context, widget.track, music, player),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTrackOptions(
    BuildContext context,
    Track track,
    MusicProvider music,
    AudioPlayerProvider player,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181818),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Track Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      CachedCoverArt(
                        imageUrl: music.getCoverArtUrl(track.coverArtId, albumName: track.album, size: 250),
                        localImagePath: track.localCoverArtPath,
                        width: 54,
                        height: 54,
                        borderRadius: 10,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.titleMedium.copyWith(fontSize: 16),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${track.artist} • ${track.album}',
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
                const SizedBox(height: 16),

                // Quick Action Bar (Like, Download, Share/Playlist)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF222222),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedLikeButton(track: track, size: 24),
                            const SizedBox(height: 2),
                            Text('Like', style: AppTypography.bodySmall.copyWith(fontSize: 11, color: AppColors.textMuted)),
                          ],
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularDownloadButton(track: track, size: 30),
                            const SizedBox(height: 2),
                            Text('Download', style: AppTypography.bodySmall.copyWith(fontSize: 11, color: AppColors.textMuted)),
                          ],
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.playlist_add_rounded, color: Colors.white, size: 22),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _showAddToPlaylistDialog(context, track, music);
                              },
                            ),
                            const SizedBox(height: 2),
                            Text('Playlist', style: AppTypography.bodySmall.copyWith(fontSize: 11, color: AppColors.textMuted)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Divider(color: Color(0xFF2A2A2A)),

                // Action List Tiles
                _buildActionTile(
                  icon: Icons.playlist_play_rounded,
                  title: 'Play Next',
                  onTap: () {
                    Navigator.pop(ctx);
                    player.playNext(track);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Playing next'), duration: Duration(seconds: 1)),
                    );
                  },
                ),
                _buildActionTile(
                  icon: Icons.queue_music_rounded,
                  title: 'Add to Queue',
                  onTap: () {
                    Navigator.pop(ctx);
                    player.addToQueue(track);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Added to queue'), duration: Duration(seconds: 1)),
                    );
                  },
                ),
                _buildActionTile(
                  icon: Icons.radio_rounded,
                  title: 'Start Song Radio',
                  titleColor: AppColors.primary,
                  onTap: () async {
                    Navigator.pop(ctx);
                    final radioTracks = await music.getRadioStation(track);
                    if (radioTracks.isNotEmpty) {
                      player.playTracks(tracks: [track, ...radioTracks], initialIndex: 0);
                    } else {
                      player.playTrack(track);
                    }
                  },
                ),
                if (track.albumId != null && track.albumId!.isNotEmpty)
                  _buildActionTile(
                    icon: Icons.album_rounded,
                    title: 'View Album',
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AlbumDetailScreen(albumId: track.albumId!),
                        ),
                      );
                    },
                  ),
                if (track.individualArtists.length > 1) ...[
                  for (final artistName in track.individualArtists)
                    _buildActionTile(
                      icon: Icons.person_rounded,
                      title: 'View $artistName',
                      onTap: () {
                        Navigator.pop(ctx);
                        music.openArtistByName(context, artistName);
                      },
                    ),
                ] else if (track.artistId != null && track.artistId!.isNotEmpty) ...[
                  _buildActionTile(
                    icon: Icons.person_rounded,
                    title: 'View Artist',
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ArtistDetailScreen(artistId: track.artistId!),
                        ),
                      );
                    },
                  ),
                ] else if (track.artist.isNotEmpty) ...[
                  _buildActionTile(
                    icon: Icons.person_rounded,
                    title: 'View ${track.artist}',
                    onTap: () {
                      Navigator.pop(ctx);
                      music.openArtistByName(context, track.artist);
                    },
                  ),
                ],
                _buildActionTile(
                  icon: Icons.info_outline_rounded,
                  title: 'Audio Specs & File Info',
                  onTap: () {
                    Navigator.pop(ctx);
                    _showSongSpecsDialog(context, track);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: titleColor ?? Colors.white70, size: 22),
      title: Text(
        title,
        style: AppTypography.bodyLarge.copyWith(
          color: titleColor ?? Colors.white,
          fontSize: 15,
        ),
      ),
      onTap: onTap,
    );
  }

  void _showAddToPlaylistDialog(BuildContext context, Track track, MusicProvider music) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181818),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Add to Playlist', style: AppTypography.titleLarge),
                    TextButton.icon(
                      icon: const Icon(Icons.add_rounded, color: AppColors.primary, size: 20),
                      label: Text('New', style: AppTypography.labelMedium.copyWith(color: AppColors.primary)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showCreatePlaylistDialog(context, music, initialTrackId: track.id);
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFF282828)),
              if (music.playlists.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('No playlists created yet', style: AppTypography.bodySmall),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: music.playlists.length,
                    itemBuilder: (ctx, i) {
                      final pl = music.playlists[i];
                      return ListTile(
                        leading: const Icon(Icons.queue_music_rounded, color: AppColors.primary),
                        title: Text(pl.name, style: AppTypography.titleMedium),
                        subtitle: Text('${pl.songCount} songs', style: AppTypography.bodySmall),
                        onTap: () async {
                          Navigator.pop(ctx);
                          final ok = await music.addTrackToPlaylist(pl.id, track.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(ok ? 'Added to ${pl.name}' : 'Failed to add track'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, MusicProvider music, {String? initialTrackId}) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('New Playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: AppTypography.bodyLarge,
          decoration: const InputDecoration(hintText: 'Playlist name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(ctx);
                final pl = await music.createPlaylist(
                  name,
                  songIds: initialTrackId != null ? [initialTrackId] : null,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(pl != null ? 'Created "$name"' : 'Failed to create playlist'),
                    ),
                  );
                }
              }
            },
            child: const Text('Create', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSongSpecsDialog(BuildContext context, Track track) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(track.title, style: AppTypography.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _specRow('Artist', track.artist),
            _specRow('Album', track.album),
            _specRow('Duration', DurationFormatter.format(track.duration)),
            if (track.suffix != null) _specRow('Format / Codec', track.suffix!.toUpperCase()),
            if (track.bitRate != null) _specRow('Bitrate', '${track.bitRate} kbps'),
            if (track.year != null) _specRow('Year', '${track.year}'),
            if (track.genre != null) _specRow('Genre', track.genre!),
            if (track.path != null) _specRow('Server Path', track.path!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _specRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted)),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
