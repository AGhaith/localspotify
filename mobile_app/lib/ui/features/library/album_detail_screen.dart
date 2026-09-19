import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../../data/models/album.dart';
import '../../../state/audio_player_provider.dart';
import '../../../state/music_provider.dart';
import '../../core_widgets/cached_cover_art.dart';
import '../../core_widgets/neo_button.dart';
import '../../core_widgets/track_row.dart';

import 'artist_detail_screen.dart';

class AlbumDetailScreen extends StatelessWidget {
  final String albumId;

  const AlbumDetailScreen({super.key, required this.albumId});

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final player = context.read<AudioPlayerProvider>();
    final isDownloading = music.downloadingEntityId == albumId;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<Album>(
        future: music.getAlbumDetails(albumId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Scaffold(
              backgroundColor: AppColors.background,
              appBar: AppBar(leading: const BackButton()),
              body: Center(
                child: Text('Failed to load album', style: AppTypography.bodyMedium),
              ),
            );
          }

          final album = snapshot.data!;
          final coverUrl = music.getCoverArtUrl(album.coverArtId, size: 500);

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                backgroundColor: AppColors.card,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedCoverArt(imageUrl: coverUrl, borderRadius: 0),
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

              // Album Info & Play Actions
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        album.name,
                        style: AppTypography.displayMedium,
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: (album.artistId != null && album.artistId!.isNotEmpty)
                            ? () {
                                HapticFeedback.lightImpact();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ArtistDetailScreen(artistId: album.artistId!),
                                  ),
                                );
                              }
                            : null,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              album.artist,
                              style: AppTypography.titleMedium.copyWith(
                                color: AppColors.primary,
                                decoration: (album.artistId != null && album.artistId!.isNotEmpty)
                                    ? TextDecoration.underline
                                    : TextDecoration.none,
                              ),
                            ),
                            if (album.artistId != null && album.artistId!.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right_rounded, color: AppColors.primary, size: 18),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${album.tracks.length} songs • ${DurationFormatter.format(album.duration)} ${album.year != null ? "• ${album.year}" : ""}',
                        style: AppTypography.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          NeoButton(
                            text: 'Play',
                            icon: Icons.play_arrow_rounded,
                            onPressed: () {
                              HapticFeedback.heavyImpact();
                              player.playTracks(tracks: album.tracks, initialIndex: 0);
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
                              final shuffled = List.of(album.tracks)..shuffle();
                              player.playTracks(tracks: shuffled, initialIndex: 0);
                            },
                          ),
                          // 1-Tap Download Album Button
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
                                    music.downloadAlbum(album);
                                  },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Track List
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final track = album.tracks[i];
                      return TrackRow(
                        track: track,
                        index: i + 1,
                        showCover: false,
                        onTap: () {
                          player.playTracks(tracks: album.tracks, initialIndex: i);
                        },
                      );
                    },
                    childCount: album.tracks.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
