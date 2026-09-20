import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/artist.dart';
import '../../../state/audio_player_provider.dart';
import '../../../state/music_provider.dart';
import '../../core_widgets/album_card.dart';
import '../../core_widgets/cached_cover_art.dart';
import '../../core_widgets/neo_button.dart';
import '../../core_widgets/track_row.dart';
import '../player/mini_player_bar.dart';
import 'album_detail_screen.dart';

class ArtistDetailScreen extends StatefulWidget {
  final String artistId;

  const ArtistDetailScreen({super.key, required this.artistId});

  @override
  State<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends State<ArtistDetailScreen> {
  late Future<Artist> _artistFuture;
  bool _isBioExpanded = false;

  @override
  void initState() {
    super.initState();
    _artistFuture = context.read<MusicProvider>().getArtistDetails(widget.artistId);
  }

  void _retry() {
    setState(() {
      _artistFuture = context.read<MusicProvider>().getArtistDetails(widget.artistId, forceRefresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final player = context.watch<AudioPlayerProvider>();

    return FutureBuilder<Artist>(
      future: _artistFuture,
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
                ? const MiniPlayerBar(isStandalone: true)
                : null,
            body: const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
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
                ? const MiniPlayerBar(isStandalone: true)
                : null,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Failed to load artist details', style: AppTypography.bodyMedium),
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

        final artist = snapshot.data!;
        final coverUrl = artist.artistImageUrl ??
            music.getCoverArtUrl(artist.coverArtId, size: 600);

        return Scaffold(
          backgroundColor: AppColors.background,
          bottomNavigationBar: player.hasTrack
              ? const MiniPlayerBar(isStandalone: true)
              : null,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Hero AppBar
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                backgroundColor: AppColors.card,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: () => Navigator.maybePop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    artist.name,
                    style: AppTypography.titleLarge.copyWith(color: Colors.white),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedCoverArt(
                        imageUrl: coverUrl,
                        borderRadius: 0,
                        placeholderIcon: Icons.person_rounded,
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.5),
                              AppColors.background,
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Action Buttons & Stats
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${artist.albums.length} Albums • ${artist.topTracks.length} Top Songs',
                        style: AppTypography.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          if (artist.topTracks.isNotEmpty) ...[
                            NeoButton(
                              text: 'Play All',
                              icon: Icons.play_arrow_rounded,
                              onPressed: () {
                                HapticFeedback.heavyImpact();
                                player.playTracks(tracks: artist.topTracks, initialIndex: 0);
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
                                final shuffled = List.of(artist.topTracks)..shuffle();
                                player.playTracks(tracks: shuffled, initialIndex: 0);
                              },
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Last.fm Biography Card (if available)
              if (artist.biography != null && artist.biography!.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
                              const SizedBox(width: 8),
                              Text('About the Artist', style: AppTypography.titleMedium),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _cleanBio(artist.biography!),
                            maxLines: _isBioExpanded ? 100 : 3,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.4),
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () => setState(() => _isBioExpanded = !_isBioExpanded),
                            child: Text(
                              _isBioExpanded ? 'Show less' : 'Read more',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],

              // Popular Top Tracks
              if (artist.topTracks.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                    child: Text('Popular Songs', style: AppTypography.titleLarge),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final track = artist.topTracks[i];
                      return TrackRow(
                        track: track,
                        index: i + 1,
                        onTap: () {
                          player.playTracks(tracks: artist.topTracks, initialIndex: i);
                        },
                      );
                    },
                    childCount: artist.topTracks.length,
                  ),
                ),
              ],

              // Discography / Albums Carousel
              if (artist.albums.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                    child: Text('Discography', style: AppTypography.titleLarge),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 200,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: artist.albums.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (ctx, i) {
                        final album = artist.albums[i];
                        return AlbumCard(
                          album: album,
                          coverUrl: music.getCoverArtUrl(album.coverArtId, size: 250),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AlbumDetailScreen(albumId: album.id),
                              ),
                            );
                          },
                          onPlayTap: () async {
                            final detailed = await music.getAlbumDetails(album.id);
                            if (detailed.tracks.isNotEmpty) {
                              player.playTracks(tracks: detailed.tracks, initialIndex: 0);
                            }
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],

              // Similar Artists (if available)
              if (artist.similarArtists.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                    child: Text('Fans Also Like', style: AppTypography.titleLarge),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 120,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: artist.similarArtists.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 14),
                      itemBuilder: (ctx, i) {
                        final sim = artist.similarArtists[i];
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ArtistDetailScreen(artistId: sim.id),
                              ),
                            );
                          },
                          child: Column(
                            children: [
                              CachedCoverArt(
                                imageUrl: sim.artistImageUrl ??
                                    music.getCoverArtUrl(sim.coverArtId, size: 150),
                                width: 72,
                                height: 72,
                                borderRadius: 99,
                                placeholderIcon: Icons.person_rounded,
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: 80,
                                child: Text(
                                  sim.name,
                                  maxLines: 1,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        );
      },
    );
  }

  String _cleanBio(String raw) {
    // Strip HTML tags from Last.fm summary
    return raw.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), '').trim();
  }
}
