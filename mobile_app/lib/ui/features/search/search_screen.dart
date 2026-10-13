import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../state/audio_player_provider.dart';
import '../../../state/music_provider.dart';
import '../../core_widgets/album_card.dart';
import '../../core_widgets/cached_cover_art.dart';
import '../../core_widgets/catalog_track_row.dart';
import '../../core_widgets/floating_sync_banner.dart';
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
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _triggerSearch(String query) {
    _searchController.text = query;
    _searchController.selection =
        TextSelection.fromPosition(TextPosition(offset: query.length));
    context.read<MusicProvider>().search(query);
  }

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final player = context.watch<AudioPlayerProvider>();
    final query = _searchController.text.trim();

    // Compute dynamic suggestions matching recent searches
    final matchingRecent = query.isNotEmpty
        ? music.recentSearches
            .where((s) => s.toLowerCase().contains(query.toLowerCase()))
            .toList()
        : <String>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                // Search Input Field
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.screenH,
                      AppSpacing.md, AppSpacing.screenH, AppSpacing.md),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => music.searchDebounced(val),
                    style: AppTypography.bodyLarge,
                    decoration: InputDecoration(
                      hintText: 'What do you want to listen to?',
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: AppColors.textSecondary),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  color: AppColors.textSecondary),
                              onPressed: () {
                                _searchController.clear();
                                music.search('');
                              },
                            )
                          : null,
                    ),
                  ),
                ),

                // Results / Suggestions View
                Expanded(
                  child: query.isEmpty
                      ? _buildEmptyView()
                      : CustomScrollView(
                          physics: const BouncingScrollPhysics(),
                          slivers: [
                            if (music.isSearching)
                              const SliverToBoxAdapter(
                                child: LinearProgressIndicator(
                                  minHeight: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.primary),
                                  backgroundColor: Colors.transparent,
                                ),
                              ),

                            if (!music.isSearching && music.searchError != null)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.all(
                                      AppSpacing.sectionGap),
                                  child: Column(
                                    children: [
                                      Text("Couldn't search. Try again.",
                                          style: AppTypography.titleMedium),
                                      TextButton(
                                        onPressed: () => music.search(query),
                                        child: const Text('Retry',
                                            style: TextStyle(
                                                color: AppColors.textPrimary)),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else if (!music.isSearching &&
                                !music.isSearchingSpotify &&
                                music.searchTracks.isEmpty &&
                                music.searchAlbums.isEmpty &&
                                music.searchArtists.isEmpty &&
                                music.searchPlaylists.isEmpty &&
                                music.spotifySearchTracks.isEmpty)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.all(
                                      AppSpacing.sectionGap),
                                  child: Center(
                                      child: Text('No results for $query',
                                          style: AppTypography.titleMedium)),
                                ),
                              ),

                            // Dynamic Search Suggestions
                            if (matchingRecent.isNotEmpty) ...[
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      AppSpacing.screenH,
                                      AppSpacing.sectionGap,
                                      AppSpacing.screenH,
                                      AppSpacing.rowGap),
                                  child: Text(
                                    'SUGGESTIONS',
                                    style: AppTypography.labelSmall.copyWith(
                                      color: AppColors.textMuted,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                              ),
                              SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (ctx, i) {
                                    final suggestion = matchingRecent[i];
                                    return _buildSuggestionTile(
                                      text: suggestion,
                                      query: query,
                                      isHistory: true,
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        _triggerSearch(suggestion);
                                      },
                                      onFill: () {
                                        _searchController.text = suggestion;
                                        _searchController.selection =
                                            TextSelection.fromPosition(
                                          TextPosition(
                                              offset: suggestion.length),
                                        );
                                        music.search(suggestion);
                                      },
                                      onRemove: () {
                                        music.removeRecentSearch(suggestion);
                                      },
                                    );
                                  },
                                  childCount: matchingRecent.length > 5
                                      ? 5
                                      : matchingRecent.length,
                                ),
                              ),
                              const SliverToBoxAdapter(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: AppSpacing.screenH),
                                  child: Divider(
                                      color: AppColors.border, height: 16),
                                ),
                              ),
                            ],

                            // 1. Artists Section
                            if (music.searchArtists.isNotEmpty) ...[
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      AppSpacing.screenH,
                                      AppSpacing.sectionGap,
                                      AppSpacing.screenH,
                                      AppSpacing.rowGap),
                                  child: Text('Artists',
                                      style: AppTypography.titleLarge),
                                ),
                              ),
                              SliverToBoxAdapter(
                                child: SizedBox(
                                  height: 132,
                                  child: ListView.separated(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.screenH),
                                    scrollDirection: Axis.horizontal,
                                    itemCount: music.searchArtists.length,
                                    separatorBuilder: (_, __) => const SizedBox(
                                        width: AppSpacing.rowGap),
                                    itemBuilder: (ctx, i) {
                                      final artist = music.searchArtists[i];
                                      return GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  ArtistDetailScreen(
                                                      artistId: artist.id),
                                            ),
                                          );
                                        },
                                        child: Column(
                                          children: [
                                            CachedCoverArt(
                                              imageUrl: music.getCoverArtUrl(
                                                  artist.coverArtId,
                                                  size: 150),
                                              width: 104,
                                              height: 104,
                                              borderRadius: 99,
                                              placeholderIcon:
                                                  Icons.person_rounded,
                                            ),
                                            const SizedBox(
                                                height: AppSpacing.sm),
                                            SizedBox(
                                              width: 104,
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
                                  padding: const EdgeInsets.fromLTRB(
                                      AppSpacing.screenH,
                                      AppSpacing.sectionGap,
                                      AppSpacing.screenH,
                                      AppSpacing.rowGap),
                                  child: Text('Songs',
                                      style: AppTypography.titleLarge),
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
                                  padding: const EdgeInsets.fromLTRB(
                                      AppSpacing.screenH,
                                      AppSpacing.sectionGap,
                                      AppSpacing.screenH,
                                      AppSpacing.rowGap),
                                  child: Text('Albums',
                                      style: AppTypography.titleLarge),
                                ),
                              ),
                              SliverToBoxAdapter(
                                child: SizedBox(
                                  height: 200,
                                  child: ListView.separated(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.screenH),
                                    scrollDirection: Axis.horizontal,
                                    itemCount: music.searchAlbums.length,
                                    separatorBuilder: (_, __) => const SizedBox(
                                        width: AppSpacing.rowGap),
                                    itemBuilder: (ctx, i) {
                                      final album = music.searchAlbums[i];
                                      return AlbumCard(
                                        album: album,
                                        coverUrl: music.getCoverArtUrl(
                                            album.coverArtId,
                                            size: 250),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => AlbumDetailScreen(
                                                  albumId: album.id),
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
                                  padding: const EdgeInsets.fromLTRB(
                                      AppSpacing.screenH,
                                      AppSpacing.sectionGap,
                                      AppSpacing.screenH,
                                      AppSpacing.rowGap),
                                  child: Text('Playlists',
                                      style: AppTypography.titleLarge),
                                ),
                              ),
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.screenH),
                                sliver: SliverList.separated(
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: AppSpacing.rowGap),
                                  itemBuilder: (ctx, i) {
                                    final pl = music.searchPlaylists[i];
                                    return InkWell(
                                      onTap: () {
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  PlaylistDetailScreen(
                                                      playlistId: pl.id),
                                            ));
                                      },
                                      child: SizedBox(
                                          height: 64,
                                          child: Row(children: [
                                            CachedCoverArt(
                                              imageUrl: music.getCoverArtUrl(
                                                  pl.coverArtId,
                                                  size: 150),
                                              width: 56,
                                              height: 56,
                                              borderRadius: 4,
                                              placeholderIcon:
                                                  Icons.queue_music_rounded,
                                            ),
                                            const SizedBox(
                                                width: AppSpacing.rowGap),
                                            Expanded(
                                                child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(pl.name,
                                                    style: AppTypography
                                                        .titleMedium,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis),
                                                const SizedBox(
                                                    height: AppSpacing.xs),
                                                Text(
                                                    'Playlist • ${pl.songCount} ${pl.songCount == 1 ? "song" : "songs"}',
                                                    style: AppTypography
                                                        .bodySmall),
                                              ],
                                            )),
                                          ])),
                                    );
                                  },
                                  itemCount: music.searchPlaylists.length,
                                ),
                              ),
                            ],

                            // 5. Spotify Global Catalog Section (On-Demand Sync & Play)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.screenH,
                                    AppSpacing.sectionGap,
                                    AppSpacing.screenH,
                                    AppSpacing.rowGap),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.public_rounded,
                                            color: AppColors.primary, size: 18),
                                        const SizedBox(width: AppSpacing.sm),
                                        Text('Catalog',
                                            style: AppTypography.titleLarge),
                                      ],
                                    ),
                                    if (music.isSearchingSpotify)
                                      const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.primary),
                                      )
                                    else if (music
                                            .spotifySearchTracks.isEmpty &&
                                        query.isNotEmpty)
                                      GestureDetector(
                                        onTap: () {
                                          HapticFeedback.lightImpact();
                                          music.searchSpotify(query);
                                        },
                                        child: Text(
                                          'Get More Results',
                                          style:
                                              AppTypography.labelSmall.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),

                            if (music.spotifySearchTracks.isNotEmpty)
                              SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (ctx, i) {
                                    final item = music.spotifySearchTracks[i];
                                    return CatalogTrackRow(item: item);
                                  },
                                  childCount: music.spotifySearchTracks.length,
                                ),
                              )
                            else if (!music.isSearchingSpotify &&
                                music.searchTracks.isEmpty &&
                                query.isNotEmpty)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.all(
                                      AppSpacing.sectionGap),
                                  child: Center(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.primary,
                                        side: const BorderSide(
                                            color: AppColors.primary),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20, vertical: 12),
                                      ),
                                      icon: const Icon(
                                          Icons.cloud_download_rounded),
                                      label: const Text(
                                          'Search Spotify Catalog for tracks'),
                                      onPressed: () {
                                        HapticFeedback.lightImpact();
                                        music.searchSpotify(query);
                                      },
                                    ),
                                  ),
                                ),
                              ),

                            const SliverToBoxAdapter(
                                child: SizedBox(height: 120)),
                          ],
                        ),
                ),
              ],
            ),
            // Floating Sync Progress Banner
            const FloatingSyncBanner(bottomOffset: 76),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionTile({
    required String text,
    required String query,
    required bool isHistory,
    required VoidCallback onTap,
    required VoidCallback onFill,
    VoidCallback? onRemove,
  }) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenH, vertical: 0),
      leading: Icon(
        isHistory ? Icons.history_rounded : Icons.search_rounded,
        color: AppColors.textMuted,
        size: 20,
      ),
      title: _buildHighlightedText(text, query),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.north_west_rounded,
                size: 18, color: AppColors.textMuted),
            tooltip: 'Insert into search',
            onPressed: onFill,
          ),
          if (onRemove != null)
            IconButton(
              icon: const Icon(Icons.close_rounded,
                  size: 16, color: AppColors.textMuted),
              tooltip: 'Remove',
              onPressed: onRemove,
            ),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildHighlightedText(String text, String query) {
    if (query.isEmpty) {
      return Text(text,
          style:
              AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary));
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final index = lowerText.indexOf(lowerQuery);

    if (index == -1) {
      return Text(text,
          style:
              AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary));
    }

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
        children: [
          if (index > 0)
            TextSpan(
                text: text.substring(0, index),
                style: const TextStyle(color: AppColors.textSecondary)),
          TextSpan(
            text: text.substring(index, index + query.length),
            style: const TextStyle(
                color: AppColors.primary, fontWeight: FontWeight.bold),
          ),
          if (index + query.length < text.length)
            TextSpan(
              text: text.substring(index + query.length),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.card,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Center(
                child: Icon(
                  Icons.search_rounded,
                  color: AppColors.primary,
                  size: 34,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Play what you love',
              style: AppTypography.titleLarge
                  .copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Search for artists, songs, albums, or explore the catalog',
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.textMuted, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
