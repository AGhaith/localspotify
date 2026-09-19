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
import '../../core_widgets/neo_button.dart';
import '../../core_widgets/track_row.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final String playlistId;

  const PlaylistDetailScreen({super.key, required this.playlistId});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final player = context.read<AudioPlayerProvider>();

    final isDownloading = music.downloadingEntityId == widget.playlistId;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<Playlist>(
        future: music.getPlaylistDetails(widget.playlistId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Scaffold(
              backgroundColor: AppColors.background,
              appBar: AppBar(leading: const BackButton()),
              body: Center(
                child: Text('Failed to load playlist', style: AppTypography.bodyMedium),
              ),
            );
          }

          final playlist = snapshot.data!;
          final coverUrl = music.getCoverArtUrl(playlist.coverArtId, size: 500);

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 260,
                pinned: true,
                backgroundColor: AppColors.card,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
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
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (playlist.tracks.isNotEmpty) ...[
                            NeoButton(
                              text: 'Play All',
                              icon: Icons.play_arrow_rounded,
                              onPressed: () {
                                HapticFeedback.heavyImpact();
                                player.playTracks(tracks: playlist.tracks, initialIndex: 0);
                              },
                            ),
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
                            // Download Playlist Button
                            NeoButton(
                              text: isDownloading
                                  ? '${(music.downloadingProgress * 100).toInt()}%'
                                  : 'Download All',
                              icon: isDownloading
                                  ? Icons.hourglass_top_rounded
                                  : Icons.download_rounded,
                              backgroundColor: isDownloading
                                  ? AppColors.primary.withValues(alpha: 0.2)
                                  : const Color(0xFF1E293B),
                              textColor: isDownloading ? AppColors.primary : AppColors.textPrimary,
                              borderColor: isDownloading ? AppColors.primary : AppColors.border,
                              onPressed: isDownloading
                                  ? null
                                  : () {
                                      HapticFeedback.lightImpact();
                                      music.downloadPlaylist(playlist);
                                    },
                            ),
                          ],
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
          );
        },
      ),
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog
              await music.deletePlaylist(playlist.id);
              if (mounted) Navigator.pop(context); // Close screen
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
