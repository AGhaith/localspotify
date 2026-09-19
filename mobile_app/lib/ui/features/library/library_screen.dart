import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../state/audio_player_provider.dart';
import '../../../state/music_provider.dart';
import '../../core_widgets/cached_cover_art.dart';
import '../offline/offline_screen.dart';
import 'artist_detail_screen.dart';
import 'import_spotify_playlist_sheet.dart';
import 'liked_songs_screen.dart';
import 'playlist_detail_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _selectedFilter = 'All'; // 'All', 'Playlists', 'Artists', 'Downloaded'
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MusicProvider>().loadLibrary();
    });
  }

  void _showCreatePlaylistDialog(BuildContext context, MusicProvider music) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Create New Playlist'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              style: AppTypography.bodyLarge,
              decoration: const InputDecoration(hintText: 'My Favorite Mix'),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1DB954),
                side: const BorderSide(color: Color(0xFF1DB954)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('Import from Spotify instead'),
              onPressed: () {
                Navigator.pop(ctx);
                ImportSpotifyPlaylistSheet.show(context);
              },
            ),
          ],
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
                final pl = await music.createPlaylist(name);
                if (context.mounted && pl != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlaylistDetailScreen(playlistId: pl.id),
                    ),
                  );
                }
              }
            },
            child: const Text('Create', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.card,
          onRefresh: () => music.loadLibrary(),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Your Library', style: AppTypography.displayMedium),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.playlist_add_check_rounded, color: Color(0xFF1DB954), size: 26),
                            tooltip: 'Import Spotify Playlist',
                            onPressed: () => ImportSpotifyPlaylistSheet.show(context),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_rounded, color: AppColors.primary, size: 28),
                            tooltip: 'Create New Playlist',
                            onPressed: () => _showCreatePlaylistDialog(context, music),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Filter Pills
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildFilterPill('All', 'All'),
                        const SizedBox(width: 8),
                        _buildFilterPill('Playlists', 'Playlists'),
                        const SizedBox(width: 8),
                        _buildFilterPill('Artists', 'Artists'),
                        const SizedBox(width: 8),
                        _buildFilterPill('Downloaded', '💾 Downloaded'),
                      ],
                    ),
                  ),
                ),
              ),

              // Pinned Shortcuts (Liked Songs & Offline Downloads) - Show if 'All'
              if (_selectedFilter == 'All')
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        // Liked Songs
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF450AF5), Color(0xFF8E8EE5)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 26),
                          ),
                          title: Text('Liked Songs', style: AppTypography.titleMedium),
                          subtitle: Text('${music.starredTracks.length} songs', style: AppTypography.bodySmall),
                          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const LikedSongsScreen()),
                          ),
                        ),
                        const Divider(),
                        // Offline Downloads
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.arrow_circle_down_rounded, color: AppColors.primary, size: 26),
                          ),
                          title: Text('Downloaded Music', style: AppTypography.titleMedium),
                          subtitle: Text('${music.offlineTracks.length} tracks available offline', style: AppTypography.bodySmall),
                          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const OfflineScreen()),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Playlists Section - Show if 'All' or 'Playlists'
              if (_selectedFilter == 'All' || _selectedFilter == 'Playlists') ...[
                // Playlists Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Playlists', style: AppTypography.titleLarge),
                        Row(
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.download_rounded, size: 16, color: Color(0xFF1DB954)),
                              label: Text('Import Spotify', style: AppTypography.labelMedium.copyWith(color: const Color(0xFF1DB954))),
                              onPressed: () => ImportSpotifyPlaylistSheet.show(context),
                            ),
                            const SizedBox(width: 4),
                            TextButton.icon(
                              icon: const Icon(Icons.add_rounded, size: 18, color: AppColors.primary),
                              label: Text('New', style: AppTypography.labelMedium.copyWith(color: AppColors.primary)),
                              onPressed: () => _showCreatePlaylistDialog(context, music),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Spotify Import Highlight Card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: GestureDetector(
                      onTap: () => ImportSpotifyPlaylistSheet.show(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF132018),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF1DB954).withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1DB954),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.playlist_add_check_rounded, color: Colors.black, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Import Spotify Playlist',
                                    style: AppTypography.titleMedium.copyWith(fontSize: 14, color: Colors.white),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Download tracks to server & add to your account',
                                    style: AppTypography.bodySmall.copyWith(color: Colors.white60, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Color(0xFF1DB954)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Playlists List
                if (music.playlists.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('No playlists found on server', style: AppTypography.bodySmall),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final pl = music.playlists[i];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 4),
                            leading: CachedCoverArt(
                              imageUrl: music.getCoverArtUrl(pl.coverArtId, size: 150),
                              width: 50,
                              height: 50,
                              borderRadius: 8,
                              placeholderIcon: Icons.queue_music_rounded,
                            ),
                            title: Text(pl.name, style: AppTypography.titleMedium),
                            subtitle: Text('${pl.songCount} songs', style: AppTypography.bodySmall),
                            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PlaylistDetailScreen(playlistId: pl.id),
                                ),
                              );
                            },
                          );
                        },
                        childCount: music.playlists.length,
                      ),
                    ),
                  ),
              ],

              // Artists Section - Show if 'All' or 'Artists'
              if (_selectedFilter == 'All' || _selectedFilter == 'Artists') ...[
                // Artists Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                    child: Text('Artists', style: AppTypography.titleLarge),
                  ),
                ),

                // Artists List
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, _selectedFilter == 'Artists' ? 100 : 24),
                  sliver: SliverToBoxAdapter(
                    child: SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: music.artists.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (ctx, i) {
                          final artist = music.artists[i];
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
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
                                  width: 76,
                                  height: 76,
                                  borderRadius: 99,
                                  placeholderIcon: Icons.person_rounded,
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  width: 80,
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
                ),
              ],

              // Downloaded Only Section
              if (_selectedFilter == 'Downloaded') ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Downloaded Tracks', style: AppTypography.titleLarge),
                        Text(
                          '${music.offlineTracks.length} tracks',
                          style: AppTypography.bodySmall.copyWith(color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ),
                if (music.offlineTracks.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border, width: 1.5),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.textMuted),
                            const SizedBox(height: 12),
                            Text('No downloaded tracks', style: AppTypography.titleMedium),
                            const SizedBox(height: 6),
                            Text(
                              'Download songs or albums to enjoy your music offline anywhere.',
                              style: AppTypography.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final track = music.offlineTracks[i];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 4),
                            leading: CachedCoverArt(
                              imageUrl: music.getCoverArtUrl(track.coverArtId, size: 100),
                              localImagePath: track.localCoverArtPath,
                              width: 48,
                              height: 48,
                              borderRadius: 8,
                            ),
                            title: Text(track.title, style: AppTypography.titleMedium, maxLines: 1),
                            subtitle: Text(track.artist, style: AppTypography.bodySmall, maxLines: 1),
                            trailing: const Icon(Icons.arrow_circle_down_rounded, color: AppColors.primary, size: 20),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              context.read<AudioPlayerProvider>().playTracks(
                                    tracks: music.offlineTracks,
                                    initialIndex: i,
                                  );
                            },
                          );
                        },
                        childCount: music.offlineTracks.length,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterPill(String id, String label) {
    final active = _selectedFilter == id;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedFilter = id);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : const Color(0xFF222430),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.border,
            width: 1.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              offset: Offset(2, 2),
              blurRadius: 0,
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.labelLarge.copyWith(
              color: active ? AppColors.textDark : AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
