import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../state/audio_player_provider.dart';
import '../../../state/music_provider.dart';
import '../../../data/services/spotify_service.dart';
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
    _searchController.selection = TextSelection.fromPosition(TextPosition(offset: query.length));
    context.read<MusicProvider>().search(query);
  }

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final player = context.read<AudioPlayerProvider>();
    final query = _searchController.text.trim();

    // Compute dynamic suggestions matching recent searches
    final matchingRecent = query.isNotEmpty
        ? music.recentSearches.where((s) => s.toLowerCase().contains(query.toLowerCase())).toList()
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
                                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                  backgroundColor: Colors.transparent,
                                ),
                              ),

                            // Dynamic Search Suggestions
                            if (matchingRecent.isNotEmpty) ...[
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
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
                                        _searchController.selection = TextSelection.fromPosition(
                                          TextPosition(offset: suggestion.length),
                                        );
                                        music.search(suggestion);
                                      },
                                      onRemove: () {
                                        music.removeRecentSearch(suggestion);
                                      },
                                    );
                                  },
                                  childCount: matchingRecent.length > 5 ? 5 : matchingRecent.length,
                                ),
                              ),
                              const SliverToBoxAdapter(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Divider(color: Colors.white10, height: 16),
                                ),
                              ),
                            ],

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

                            // 5. Spotify Global Catalog Section (On-Demand Sync & Play)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.public_rounded, color: AppColors.primary, size: 18),
                                        const SizedBox(width: 8),
                                        Text('Spotify Catalog', style: AppTypography.titleLarge),
                                      ],
                                    ),
                                    if (music.isSearchingSpotify)
                                      const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                      )
                                    else if (music.spotifySearchTracks.isEmpty && query.isNotEmpty)
                                      GestureDetector(
                                        onTap: () {
                                          HapticFeedback.lightImpact();
                                          music.searchSpotify(query);
                                        },
                                        child: Text(
                                          'Get More Results',
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

                            if (music.spotifySearchTracks.isNotEmpty)
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (ctx, i) {
                                      final item = music.spotifySearchTracks[i];
                                      final syncState = music.getSpotifySyncState(item.id);
                                      final syncProgress = music.getSpotifySyncProgress(item.id);

                                      return ListTile(
                                        contentPadding: const EdgeInsets.symmetric(vertical: 2),
                                        leading: ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: item.coverUrl != null
                                              ? Image.network(
                                                  item.coverUrl!,
                                                  width: 48,
                                                  height: 48,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => Container(
                                                    width: 48,
                                                    height: 48,
                                                    color: AppColors.card,
                                                    child: const Icon(Icons.music_note_rounded, color: AppColors.primary),
                                                  ),
                                                )
                                              : Container(
                                                  width: 48,
                                                  height: 48,
                                                  color: AppColors.card,
                                                  child: const Icon(Icons.music_note_rounded, color: AppColors.primary),
                                                ),
                                        ),
                                        title: Text(
                                          item.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.titleMedium.copyWith(fontSize: 15),
                                        ),
                                        subtitle: Text(
                                          '${item.artist} • ${item.durationFormatted}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                                        ),
                                        trailing: _buildSpotifyTrackTrailing(item, syncState, syncProgress),
                                        onTap: () async {
                                          HapticFeedback.mediumImpact();
                                          final track = await music.convertAndSyncSpotifyTrack(item);
                                          if (track != null) {
                                            await player.playTrack(track);
                                          }
                                        },
                                      );
                                    },
                                    childCount: music.spotifySearchTracks.length,
                                  ),
                                ),
                              )
                            else if (!music.isSearchingSpotify && music.searchTracks.isEmpty && query.isNotEmpty)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Center(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.primary,
                                        side: const BorderSide(color: AppColors.primary),
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      ),
                                      icon: const Icon(Icons.cloud_download_rounded),
                                      label: const Text('Search Spotify Catalog for tracks'),
                                      onPressed: () {
                                        HapticFeedback.lightImpact();
                                        music.searchSpotify(query);
                                      },
                                    ),
                                  ),
                                ),
                              ),

                            const SliverToBoxAdapter(child: SizedBox(height: 120)),
                          ],
                        ),
                ),
              ],
            ),
            // Floating Sync Progress Banner
            _buildFloatingSyncBanner(music, player),
          ],
        ),
      ),
    );
  }

  Widget _buildSpotifyTrackTrailing(SpotifyTrackItem item, SpotifySyncState syncState, double progress) {
    switch (syncState) {
      case SpotifySyncState.syncing:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  value: progress > 0 ? progress : null,
                  strokeWidth: 2,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                progress > 0 ? '${(progress * 100).toInt()}%' : 'Syncing...',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      case SpotifySyncState.playing:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.equalizer_rounded, color: Colors.black, size: 16),
              const SizedBox(width: 4),
              Text(
                'Playing',
                style: AppTypography.labelSmall.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      case SpotifySyncState.error:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.redAccent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.refresh_rounded, color: Colors.redAccent, size: 16),
              const SizedBox(width: 4),
              Text(
                'Retry',
                style: AppTypography.labelSmall.copyWith(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      case SpotifySyncState.idle:
      default:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.play_arrow_rounded, color: AppColors.primary, size: 16),
              const SizedBox(width: 4),
              Text(
                'Play & Sync',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildFloatingSyncBanner(MusicProvider music, AudioPlayerProvider player) {
    final item = music.activeSyncingItem;
    if (item == null) return const SizedBox.shrink();

    final syncState = music.getSpotifySyncState(item.id);
    final progress = music.getSpotifySyncProgress(item.id);
    final message = music.getSpotifySyncMessage(item.id) ?? 'Syncing with server vault...';

    return Positioned(
      left: 16,
      right: 16,
      bottom: 76,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: const Color(0xFF1E222A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: syncState == SpotifySyncState.error
                ? Colors.redAccent.withValues(alpha: 0.6)
                : AppColors.primary.withValues(alpha: 0.5),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: item.coverUrl != null
                          ? Image.network(
                              item.coverUrl!,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 40,
                                height: 40,
                                color: AppColors.card,
                                child: const Icon(Icons.music_note_rounded, color: AppColors.primary, size: 20),
                              ),
                            )
                          : Container(
                              width: 40,
                              height: 40,
                              color: AppColors.card,
                              child: const Icon(Icons.music_note_rounded, color: AppColors.primary, size: 20),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.titleMedium.copyWith(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            message,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySmall.copyWith(
                              color: syncState == SpotifySyncState.error ? Colors.redAccent : AppColors.primary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (syncState == SpotifySyncState.syncing)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      )
                    else if (syncState == SpotifySyncState.error)
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: Colors.redAccent, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () async {
                          HapticFeedback.mediumImpact();
                          final track = await music.convertAndSyncSpotifyTrack(item);
                          if (track != null) {
                            player.playTrack(track);
                          }
                        },
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => music.dismissActiveSyncBanner(),
                      ),
                  ],
                ),
              ),
              if (syncState == SpotifySyncState.syncing)
                LinearProgressIndicator(
                  value: progress > 0 ? progress : null,
                  minHeight: 3,
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
            ],
          ),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
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
            icon: const Icon(Icons.north_west_rounded, size: 18, color: AppColors.textMuted),
            tooltip: 'Insert into search',
            onPressed: onFill,
          ),
          if (onRemove != null)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
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
      return Text(text, style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary));
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final index = lowerText.indexOf(lowerQuery);

    if (index == -1) {
      return Text(text, style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary));
    }

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
        children: [
          if (index > 0)
            TextSpan(text: text.substring(0, index), style: const TextStyle(color: Colors.white70)),
          TextSpan(
            text: text.substring(index, index + query.length),
            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
          ),
          if (index + query.length < text.length)
            TextSpan(
              text: text.substring(index + query.length),
              style: const TextStyle(color: Colors.white70),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.card,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: const Center(
                child: Icon(
                  Icons.search_rounded,
                  color: AppColors.primary,
                  size: 34,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Play what you love',
              style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Search for artists, songs, albums, or explore the global Spotify catalog',
              style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
