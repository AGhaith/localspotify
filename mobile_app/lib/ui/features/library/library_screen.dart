import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../state/music_provider.dart';
import '../../core_widgets/cached_cover_art.dart';
import '../offline/offline_screen.dart';
import 'artist_detail_screen.dart';
import 'liked_songs_screen.dart';
import 'playlist_detail_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
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
        content: TextField(
          controller: controller,
          autofocus: true,
          style: AppTypography.bodyLarge,
          decoration: const InputDecoration(hintText: 'My Favorite Mix'),
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
                      IconButton(
                        icon: const Icon(Icons.add_rounded, color: AppColors.primary, size: 28),
                        onPressed: () => _showCreatePlaylistDialog(context, music),
                      ),
                    ],
                  ),
                ),
              ),

              // Pinned Shortcuts (Liked Songs & Offline Downloads)
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

              // Playlists Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Playlists', style: AppTypography.titleLarge),
                      TextButton.icon(
                        icon: const Icon(Icons.add_rounded, size: 18, color: AppColors.primary),
                        label: Text('New', style: AppTypography.labelMedium.copyWith(color: AppColors.primary)),
                        onPressed: () => _showCreatePlaylistDialog(context, music),
                      ),
                    ],
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

              // Artists Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                  child: Text('Artists', style: AppTypography.titleLarge),
                ),
              ),

              // Artists Horizontal List
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
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
          ),
        ),
      ),
    );
  }
}
