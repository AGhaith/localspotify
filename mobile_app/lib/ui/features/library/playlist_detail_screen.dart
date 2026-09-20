import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../../data/models/playlist.dart';
import '../../../data/models/track.dart';
import '../../../data/services/spotify_service.dart';
import '../../../state/audio_player_provider.dart';
import '../../../state/music_provider.dart';
import '../../core_widgets/cached_cover_art.dart';
import '../../core_widgets/download_action_button.dart';
import '../../core_widgets/neo_button.dart';
import '../../core_widgets/pressable_scale.dart';
import '../../core_widgets/track_row.dart';
import '../player/mini_player_bar.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final String playlistId;

  const PlaylistDetailScreen({super.key, required this.playlistId});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  Playlist? _cachedPlaylist;
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _autoSyncTimer;
  bool _isAutoSyncing = false;
  final Map<String, DateTime> _syncStartTimes = {};

  @override
  void initState() {
    super.initState();
    _loadPlaylist();
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPlaylist({bool force = false}) async {
    if (_cachedPlaylist == null) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final pl = await context.read<MusicProvider>().getPlaylistDetails(
        widget.playlistId,
        forceRefresh: force,
      );
      if (mounted) {
        setState(() {
          _cachedPlaylist = pl;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_cachedPlaylist == null) {
            _errorMessage = 'Failed to load playlist: $e';
          }
        });
      }
    }
  }

  void _retry() {
    _loadPlaylist(force: true);
  }

  void _setupAutoSync(Playlist currentPlaylist, int totalExpected) {
    if (currentPlaylist.tracks.length >= totalExpected || totalExpected == 0) {
      _autoSyncTimer?.cancel();
      _autoSyncTimer = null;
      return;
    }

    if (_autoSyncTimer != null) return;

    _autoSyncTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_isAutoSyncing) return;
      _isAutoSyncing = true;
      try {
        final music = context.read<MusicProvider>();
        final updated = await music.syncPlaylistWithVault(widget.playlistId);
        if (mounted) {
          setState(() {
            _cachedPlaylist = updated;
          });
          if (updated.tracks.length >= totalExpected) {
            timer.cancel();
            _autoSyncTimer = null;
          }
        }
      } catch (_) {
      } finally {
        _isAutoSyncing = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final player = context.watch<AudioPlayerProvider>();
    final isDownloading = music.downloadingEntityId == widget.playlistId;

    if (_isLoading && _cachedPlaylist == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.maybePop(context),
          ),
        ),
        bottomNavigationBar: player.hasTrack
            ? const MiniPlayerBar(isStandalone: true)
            : null,
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_errorMessage != null && _cachedPlaylist == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.maybePop(context),
          ),
        ),
        bottomNavigationBar: player.hasTrack
            ? const MiniPlayerBar(isStandalone: true)
            : null,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage!, style: AppTypography.bodyMedium),
              const SizedBox(height: 12),
              NeoButton(
                text: 'Retry',
                icon: Icons.refresh_rounded,
                onPressed: _retry,
              ),
            ],
          ),
        ),
      );
    }

    final playlist = _cachedPlaylist!;
        final coverUrl = music.getCoverArtUrl(
          playlist.coverArtId,
          size: 500,
          playlistId: playlist.id,
          playlistName: playlist.name,
          songCount: playlist.tracks.length,
        );
        final importedTracks = music.getImportedPlaylistTracks(playlist.id).isNotEmpty
            ? music.getImportedPlaylistTracks(playlist.id)
            : music.getImportedPlaylistTracks(playlist.name);

        final hasImported = importedTracks.isNotEmpty;
        final totalExpected = hasImported ? importedTracks.length : playlist.tracks.length;
        final isFullySynced = playlist.tracks.isNotEmpty && playlist.tracks.length >= totalExpected;
        final syncProgress = totalExpected > 0 ? (playlist.tracks.length / totalExpected) : 0.0;
        final syncPercent = (syncProgress * 100).toInt();

        // Register background sync poller if syncing is needed
        if (hasImported && !isFullySynced) {
          _setupAutoSync(playlist, totalExpected);
        }

        final isDownloaded = playlist.tracks.isNotEmpty &&
            playlist.tracks.every((t) => music.isDownloaded(t.id));

        return Scaffold(
          backgroundColor: AppColors.background,
          bottomNavigationBar: player.hasTrack
              ? const MiniPlayerBar(isStandalone: true)
              : null,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 260,
                pinned: true,
                backgroundColor: AppColors.card,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: () => Navigator.maybePop(context),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                    tooltip: 'Refresh Tracks',
                    onPressed: _retry,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.white70),
                    onPressed: () => _confirmDelete(context, music, playlist),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    playlist.name,
                    style: AppTypography.titleLarge.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedCoverArt(
                        imageUrl: coverUrl,
                        borderRadius: 0,
                        placeholderIcon: Icons.queue_music_rounded,
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.6),
                              AppColors.background,
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Playlist Meta & Actions
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isFullySynced
                            ? '${playlist.tracks.length} songs • ${DurationFormatter.format(playlist.duration)}'
                            : (hasImported
                                ? '${playlist.tracks.length} of $totalExpected tracks ready'
                                : '0 songs'),
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (playlist.comment != null && playlist.comment!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          playlist.comment!,
                          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (playlist.tracks.isNotEmpty)
                        Row(
                          children: [
                            NeoButton(
                              text: 'Play All',
                              icon: Icons.play_arrow_rounded,
                              onPressed: () {
                                HapticFeedback.heavyImpact();
                                player.playTracks(tracks: playlist.tracks, initialIndex: 0);
                              },
                            ),
                            const SizedBox(width: 10),
                            NeoButton(
                              text: 'Shuffle',
                              icon: Icons.shuffle_rounded,
                              backgroundColor: AppColors.surface,
                              textColor: AppColors.textPrimary,
                              borderColor: AppColors.border,
                              onPressed: () {
                                HapticFeedback.heavyImpact();
                                final shuffled = List.of(playlist.tracks)..shuffle();
                                player.playTracks(tracks: shuffled, initialIndex: 0);
                              },
                            ),
                            const SizedBox(width: 14),
                            DownloadActionButton(
                              isDownloaded: isDownloaded,
                              isDownloading: isDownloading,
                              progress: music.downloadingProgress,
                              size: 38,
                              onDownload: () {
                                HapticFeedback.lightImpact();
                                music.downloadPlaylist(playlist);
                              },
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),

              // Sleek Minimalist Syncing Banner
              if (hasImported && !isFullySynced)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF181818),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.0,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Syncing: ${playlist.tracks.length} of $totalExpected tracks ready ($syncPercent%)',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            PressableScale(
                              onTap: _retry,
                              scaleFactor: 0.90,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.refresh_rounded, size: 13, color: Colors.white70),
                                    SizedBox(width: 4),
                                    Text('Refresh', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Thin Clean Linear Progress Bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: syncProgress > 0 ? syncProgress : 0.05,
                            minHeight: 3,
                            backgroundColor: Colors.white12,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Tracks List
              if (hasImported && !isFullySynced)
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final t = importedTracks[i];
                        final Track? matchedTrack = _findMatchedTrack(playlist.tracks, t);
                        final isReady = matchedTrack != null;

                        final trackKey = '${t.title}_${t.artist}'.toLowerCase();
                        if (!isReady && !_syncStartTimes.containsKey(trackKey)) {
                          _syncStartTimes[trackKey] = DateTime.now();
                        }
                        final syncStartTime = _syncStartTimes[trackKey];
                        final isTimedOut = !isReady &&
                            syncStartTime != null &&
                            DateTime.now().difference(syncStartTime).inSeconds >= 30;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: SizedBox(
                            width: 32,
                            child: Center(
                              child: isReady
                                  ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 18)
                                  : isTimedOut
                                      ? const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18)
                                      : Text(
                                          '${i + 1}',
                                          style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                                        ),
                            ),
                          ),
                          title: Text(
                            t.title,
                            style: AppTypography.titleMedium.copyWith(
                              color: isReady
                                  ? Colors.white
                                  : isTimedOut
                                      ? Colors.white54
                                      : Colors.white70,
                              fontWeight: isReady ? FontWeight.w600 : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            isTimedOut ? '${t.artist} • Unavailable (Timed out)' : t.artist,
                            style: AppTypography.bodySmall.copyWith(
                              color: isTimedOut ? AppColors.error.withValues(alpha: 0.8) : AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: isTimedOut
                              ? PressableScale(
                                  onTap: () {
                                    HapticFeedback.mediumImpact();
                                    setState(() {
                                      _syncStartTimes[trackKey] = DateTime.now();
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Retrying sync for "${t.title}"...'),
                                        duration: const Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                        backgroundColor: AppColors.surface,
                                      ),
                                    );
                                    context.read<MusicProvider>().syncPlaylistWithVault(widget.playlistId);
                                  },
                                  scaleFactor: 0.90,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.refresh_rounded, color: AppColors.primary, size: 14),
                                        SizedBox(width: 4),
                                        Text(
                                          'Retry',
                                          style: TextStyle(
                                            color: AppColors.primary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      t.durationFormatted,
                                      style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      isReady ? Icons.play_arrow_rounded : Icons.sync_rounded,
                                      size: 18,
                                      color: isReady ? AppColors.primary : AppColors.textMuted,
                                    ),
                                  ],
                                ),
                          onTap: isReady
                              ? () {
                                  final index = playlist.tracks.indexOf(matchedTrack);
                                  if (index >= 0) {
                                    player.playTracks(tracks: playlist.tracks, initialIndex: index);
                                  }
                                }
                              : () async {
                                  if (isTimedOut) {
                                    setState(() {
                                      _syncStartTimes[trackKey] = DateTime.now();
                                    });
                                    context.read<MusicProvider>().syncPlaylistWithVault(widget.playlistId);
                                  }
                                  HapticFeedback.mediumImpact();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Playing "${t.title}" & syncing to vault...'),
                                      duration: const Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                      backgroundColor: AppColors.surface,
                                    ),
                                  );
                                  final track = await context.read<MusicProvider>().convertAndSyncSpotifyTrack(t);
                                  if (track != null) {
                                    player.playTrack(track);
                                  }
                                },
                        );
                      },
                      childCount: importedTracks.length,
                    ),
                  ),
                )
              else if (playlist.tracks.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.queue_music_rounded, color: AppColors.textMuted, size: 54),
                          const SizedBox(height: 12),
                          Text('This playlist is empty', style: AppTypography.titleLarge),
                          const SizedBox(height: 4),
                          Text('Add songs via the 3-dots menu on any track.', style: AppTypography.bodySmall),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final track = playlist.tracks[i];
                        return TrackRow(
                          track: track,
                          index: i + 1,
                          onTap: () {
                            player.playTracks(tracks: playlist.tracks, initialIndex: i);
                          },
                        );
                      },
                      childCount: playlist.tracks.length,
                    ),
                  ),
                ),
            ],
          ),
        );
  }

  Track? _findMatchedTrack(List<Track> tracks, SpotifyTrackItem imported) {
    final cleanTitle = imported.title.toLowerCase().trim();
    for (final t in tracks) {
      final tTitle = t.title.toLowerCase().trim();
      if (tTitle == cleanTitle ||
          tTitle.contains(cleanTitle) ||
          cleanTitle.contains(tTitle)) {
        return t;
      }
    }
    return null;
  }

  void _confirmDelete(BuildContext context, MusicProvider music, Playlist playlist) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Delete Playlist?'),
        content: Text('Are you sure you want to delete "${playlist.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.maybePop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.maybePop(ctx);
              await music.deletePlaylist(playlist.id);
              if (mounted) Navigator.maybePop(context);
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
