import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../state/audio_player_provider.dart';
import '../../../state/auth_provider.dart';
import '../../../state/music_provider.dart';
import '../../core_widgets/album_card.dart';
import '../../core_widgets/cached_cover_art.dart';
import '../../core_widgets/pressable_scale.dart';
import '../library/album_detail_screen.dart';
import '../library/artist_detail_screen.dart';
import '../library/liked_songs_screen.dart';
import '../offline/offline_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MusicProvider>().loadHomeFeed();
    });
  }


  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final auth = context.watch<AuthProvider>();
    final player = context.read<AudioPlayerProvider>();

    final isDownloadedOnly = music.activeFilter == 'downloaded';
    final offlineAlbumIds = music.offlineTracks.map((t) => t.albumId).toSet();
    final displayedNewestAlbums = isDownloadedOnly
        ? music.newestAlbums.where((a) => offlineAlbumIds.contains(a.id)).toList()
        : music.newestAlbums;
    final displayedRecentAlbums = isDownloadedOnly
        ? music.recentAlbums.where((a) => offlineAlbumIds.contains(a.id)).toList()
        : music.recentAlbums;
    final albumsToDisplay = displayedNewestAlbums.isNotEmpty
        ? displayedNewestAlbums
        : displayedRecentAlbums;
    final displayedFrequentAlbums = isDownloadedOnly
        ? music.frequentAlbums.where((a) => offlineAlbumIds.contains(a.id)).toList()
        : music.frequentAlbums;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.card,
          onRefresh: () => music.loadHomeFeed(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // Top Bar (Avatar, Filter Pills, Settings)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // User Avatar with initial
                          PressableScale(
                            onTap: () => _showUserMenu(context, auth),
                            scaleFactor: 0.90,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  auth.session?.username.isNotEmpty == true
                                      ? auth.session!.username[0].toUpperCase()
                                      : 'U',
                                  style: AppTypography.labelLarge.copyWith(
                                    color: AppColors.textDark,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Fixed Filter Pills (All & Downloaded only)
                          _buildPill(music, 'all', 'All', () => music.setFilter('all')),
                          const SizedBox(width: 8),
                          _buildPill(music, 'downloaded', 'Downloaded', () => music.setFilter('downloaded')),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Liked Songs Quick Shortcut
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LikedSongsScreen(),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2E0249), Color(0xFF570A57)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.0),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF570A57).withValues(alpha: 0.3),
                                offset: const Offset(0, 4),
                                blurRadius: 14,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF450AF5), Color(0xFF8E8EE5)],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.favorite_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Liked Songs',
                                      style: AppTypography.titleLarge.copyWith(fontSize: 16),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${music.starredTracks.length} tracks',
                                      style: AppTypography.bodySmall.copyWith(color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded, color: Colors.white70),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Recently Added / Downloaded Albums Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Text(
                    isDownloadedOnly ? 'Downloaded Albums' : 'Recently Added',
                    style: AppTypography.titleLarge,
                  ),
                ),
              ),

              // Horizontal Album Carousel or Downloaded Empty State
              SliverToBoxAdapter(
                child: isDownloadedOnly && displayedRecentAlbums.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border, width: 1.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('No downloaded albums yet', style: AppTypography.titleMedium),
                              const SizedBox(height: 6),
                              Text(
                                'Tracks and albums you download for offline playback will appear here.',
                                style: AppTypography.bodySmall,
                              ),
                              const SizedBox(height: 14),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.black,
                                ),
                                icon: const Icon(Icons.arrow_circle_down_rounded, size: 18),
                                label: const Text('View All Downloaded Tracks'),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const OfflineScreen()),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      )
                    : SizedBox(
                        height: 200,
                        child: music.isLoadingHome && albumsToDisplay.isEmpty
                            ? const Center(
                                child: CircularProgressIndicator(color: AppColors.primary),
                              )
                            : albumsToDisplay.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 20),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            music.homeError != null
                                                ? 'Could not connect to music vault'
                                                : 'No albums found in vault',
                                            style: AppTypography.titleMedium.copyWith(
                                              color: music.homeError != null ? AppColors.error : AppColors.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          OutlinedButton.icon(
                                            icon: const Icon(Icons.refresh_rounded, size: 16),
                                            label: const Text('Retry'),
                                            onPressed: () => music.loadHomeFeed(showLoadingSkeleton: true),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    itemCount: albumsToDisplay.length,
                                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                                    itemBuilder: (ctx, i) {
                                      final album = albumsToDisplay[i];
                                      return AlbumCard(
                                        album: album,
                                        coverUrl: music.getCoverArtUrl(album.coverArtId, size: 250),
                                        onTap: () => _openAlbum(context, album.id),
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

              // Popular Artists Section (only when not filtered to downloaded)
              if (!isDownloadedOnly && music.artists.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                    child: Text('Artists You Might Like', style: AppTypography.titleLarge),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 115,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: music.artists.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 14),
                      itemBuilder: (ctx, i) {
                        final artist = music.artists[i];
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
                                width: 72,
                                height: 72,
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

              // Frequently Played Albums Header
              if (displayedFrequentAlbums.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                    child: Text(
                      'Frequently Played',
                      style: AppTypography.titleLarge,
                    ),
                  ),
                ),

                // Frequent Albums Grid
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.8,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final album = displayedFrequentAlbums[i];
                        return AlbumCard(
                          album: album,
                          coverUrl: music.getCoverArtUrl(album.coverArtId, size: 250),
                          onTap: () => _openAlbum(context, album.id),
                          onPlayTap: () async {
                            final detailed = await music.getAlbumDetails(album.id);
                            if (detailed.tracks.isNotEmpty) {
                              player.playTracks(tracks: detailed.tracks, initialIndex: 0);
                            }
                          },
                        );
                      },
                      childCount: displayedFrequentAlbums.length,
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

  Widget _buildPill(MusicProvider music, String id, String label, VoidCallback onTap) {
    final active = music.activeFilter == id;

    return PressableScale(
      onTap: onTap,
      scaleFactor: 0.92,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : const Color(0xFF282828),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.labelLarge.copyWith(
              color: active ? Colors.black : Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  void _openAlbum(BuildContext context, String albumId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AlbumDetailScreen(albumId: albumId),
      ),
    );
  }

  void _showUserMenu(BuildContext context, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.person_rounded, color: AppColors.primary),
                  title: Text(auth.session?.username ?? 'User', style: AppTypography.titleMedium),
                  subtitle: Text(auth.session?.serverUrl ?? '', style: AppTypography.bodySmall),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.settings_rounded, color: AppColors.textPrimary),
                  title: Text('Settings & Storage', style: AppTypography.bodyLarge),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: AppColors.error),
                  title: Text('Log Out', style: AppTypography.bodyLarge.copyWith(color: AppColors.error)),
                  onTap: () {
                    Navigator.pop(ctx);
                    auth.logout();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
