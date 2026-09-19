import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../../data/models/playlist.dart';
import '../../../state/audio_player_provider.dart';
import '../../../state/music_provider.dart';
import '../../core_widgets/cached_cover_art.dart';
import '../../core_widgets/download_action_button.dart';
import '../../core_widgets/neo_button.dart';
import '../../core_widgets/track_row.dart';
import '../player/mini_player_bar.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final String playlistId;

  const PlaylistDetailScreen({super.key, required this.playlistId});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  late Future<Playlist> _playlistFuture;

  @override
  void initState() {
    super.initState();
    _playlistFuture = context.read<MusicProvider>().getPlaylistDetails(widget.playlistId);
  }

  void _retry() {
    setState(() {
      _playlistFuture = context.read<MusicProvider>().getPlaylistDetails(widget.playlistId, forceRefresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final player = context.watch<AudioPlayerProvider>();
    final isDownloading = music.downloadingEntityId == widget.playlistId;

    return FutureBuilder<Playlist>(
      future: _playlistFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
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
                ? const SafeArea(top: false, child: MiniPlayerBar())
                : null,
            body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
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
                ? const SafeArea(top: false, child: MiniPlayerBar())
                : null,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Failed to load playlist', style: AppTypography.bodyMedium),
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

        final playlist = snapshot.data!;
        final coverUrl = music.getCoverArtUrl(playlist.coverArtId, size: 500);
        final isDownloaded = playlist.tracks.isNotEmpty &&
            playlist.tracks.every((t) => music.isDownloaded(t.id));

        return Scaffold(
          backgroundColor: AppColors.background,
          bottomNavigationBar: player.hasTrack
              ? const SafeArea(top: false, child: MiniPlayerBar())
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
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.white70),
                    onPressed: () => _confirmDelete(context, music, playlist),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    playlist.name,
                    style: AppTypography.titleLarge.copyWith(color: Colors.white),
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
                        '${playlist.tracks.length} songs • ${DurationFormatter.format(playlist.duration)}',
                        style: AppTypography.bodySmall,
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
                              backgroundColor: const Color(0xFF222430),
                              textColor: AppColors.textPrimary,
                              borderColor: AppColors.border,
                              onPressed: () {
                                HapticFeedback.heavyImpact();
                                final shuffled = List.of(playlist.tracks)..shuffle();
                                player.playTracks(tracks: shuffled, initialIndex: 0);
                              },
                            ),
                            const SizedBox(width: 14),
                            // Spotify-grade circular download button with spinner and checkmark
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

              // Tracks List
              if (playlist.tracks.isEmpty)
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
      },
    );
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
              Navigator.maybePop(ctx); // Close dialog
              await music.deletePlaylist(playlist.id);
              if (mounted) Navigator.maybePop(context); // Close screen
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
