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

class AlbumDetailScreen extends StatelessWidget {
  final String albumId;

  const AlbumDetailScreen({super.key, required this.albumId});

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final player = context.read<AudioPlayerProvider>();

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
                              Colors.black.withOpacity(0.6),
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
                      Text(
                        album.artist,
                        style: AppTypography.titleMedium.copyWith(color: AppColors.primary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${album.tracks.length} songs • ${DurationFormatter.format(album.duration)} ${album.year != null ? "• ${album.year}" : ""}',
                        style: AppTypography.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          NeoButton(
                            text: 'Play',
                            icon: Icons.play_arrow_rounded,
                            onPressed: () {
                              HapticFeedback.heavyImpact();
                              player.playTracks(tracks: album.tracks, initialIndex: 0);
                            },
                          ),
                          const SizedBox(width: 12),
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
