import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../state/audio_player_provider.dart';
import '../../../state/music_provider.dart';
import '../../core_widgets/album_card.dart';
import '../../core_widgets/cached_cover_art.dart';
import '../../core_widgets/track_row.dart';
import '../library/album_detail_screen.dart';
import '../library/artist_detail_screen.dart';
import '../library/playlist_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _triggerSearch(String query) {
    _searchController.text = query;
    _searchController.selection = TextSelection.fromPosition(TextPosition(offset: query.length));
    context.read<MusicProvider>().search(query);
  }

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final player = context.read<AudioPlayerProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Search Input Field
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => music.searchDebounced(val),
                style: AppTypography.bodyLarge,
                decoration: InputDecoration(
                  hintText: 'What do you want to listen to?',
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                          onPressed: () {
                            _searchController.clear();
                            music.search('');
                          },
                        )
                      : null,
                ),
              ),
            ),

            // Results View
            Expanded(
              child: music.isSearching
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _searchController.text.isEmpty
                      ? _buildEmptyOrRecentView(music)
                      : CustomScrollView(
                          physics: const BouncingScrollPhysics(),
                          slivers: [
                            // 1. Artists Section
                            if (music.searchArtists.isNotEmpty) ...[
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                                  child: Text('Artists', style: AppTypography.titleLarge),
                                ),
                              ),
                              SliverToBoxAdapter(
                                child: SizedBox(
                                  height: 110,
                                  child: ListView.separated(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    scrollDirection: Axis.horizontal,
                                    itemCount: music.searchArtists.length,
                                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                                    itemBuilder: (ctx, i) {
                                      final artist = music.searchArtists[i];
                                      return GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ArtistDetailScreen(artistId: artist.id),
                                            ),
                                          );
                                        },
                                        child: Column(
                                          children: [
                                            CachedCoverArt(
                                              imageUrl: music.getCoverArtUrl(artist.coverArtId, size: 150),
                                              width: 70,
                                              height: 70,
                                              borderRadius: 99,
                                              placeholderIcon: Icons.person_rounded,
                                            ),
                                            const SizedBox(height: 6),
                                            SizedBox(
                                              width: 76,
                                              child: Text(
                                                artist.name,
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

                            // 2. Songs Section
                            if (music.searchTracks.isNotEmpty) ...[
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                  child: Text('Songs', style: AppTypography.titleLarge),
                                ),
                              ),
                              SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (ctx, i) {
                                    final track = music.searchTracks[i];
                                    return TrackRow(
                                      track: track,
                                      onTap: () => player.playTracks(
                                        tracks: music.searchTracks,
                                        initialIndex: i,
                                      ),
                                    );
                                  },
                                  childCount: music.searchTracks.length,
                                ),
                              ),
                            ],

                            // 3. Albums Section
                            if (music.searchAlbums.isNotEmpty) ...[
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                                  child: Text('Albums', style: AppTypography.titleLarge),
                                ),
                              ),
                              SliverToBoxAdapter(
                                child: SizedBox(
                                  height: 190,
                                  child: ListView.separated(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    scrollDirection: Axis.horizontal,
                                    itemCount: music.searchAlbums.length,
                                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                                    itemBuilder: (ctx, i) {
                                      final album = music.searchAlbums[i];
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
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],

                            // 4. Playlists Section
                            if (music.searchPlaylists.isNotEmpty) ...[
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                                  child: Text('Playlists', style: AppTypography.titleLarge),
                                ),
                              ),
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (ctx, i) {
                                      final pl = music.searchPlaylists[i];
                                      return ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: CachedCoverArt(
                                          imageUrl: music.getCoverArtUrl(pl.coverArtId, size: 150),
                                          width: 48,
                                          height: 48,
                                          borderRadius: 6,
                                          placeholderIcon: Icons.queue_music_rounded,
                                        ),
                                        title: Text(pl.name, style: AppTypography.titleMedium),
                                        subtitle: Text('${pl.songCount} songs', style: AppTypography.bodySmall),
                                        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => PlaylistDetailScreen(playlistId: pl.id),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                    childCount: music.searchPlaylists.length,
                                  ),
                                ),
                              ),
                            ],

                            const SliverToBoxAdapter(child: SizedBox(height: 100)),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyOrRecentView(MusicProvider music) {
    if (music.recentSearches.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent Searches', style: AppTypography.titleMedium),
                TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    music.clearRecentSearches();
                  },
                  child: Text('Clear', style: AppTypography.bodySmall.copyWith(color: AppColors.primary)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: music.recentSearches.map((query) {
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _triggerSearch(query);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.history_rounded, size: 16, color: AppColors.textMuted),
                        const SizedBox(width: 6),
                        Text(query, style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.search_rounded,
            color: AppColors.textMuted,
            size: 54,
          ),
          const SizedBox(height: 12),
          Text('Play what you love', style: AppTypography.titleLarge),
          const SizedBox(height: 4),
          Text('Search for artists, songs, albums, or playlists', style: AppTypography.bodySmall),
        ],
      ),
    );
  }
}
