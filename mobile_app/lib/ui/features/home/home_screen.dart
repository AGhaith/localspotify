import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../state/audio_player_provider.dart';
import '../../../state/auth_provider.dart';
import '../../../state/music_provider.dart';
import '../../core_widgets/album_card.dart';
import '../library/album_detail_screen.dart';
import '../library/liked_songs_screen.dart';

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
                          GestureDetector(
                            onTap: () => _showUserMenu(context, auth),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.shadow,
                                    offset: Offset(2, 2),
                                    blurRadius: 0,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  auth.session?.username.isNotEmpty == true
                                      ? auth.session!.username[0].toUpperCase()
                                      : 'U',
                                  style: AppTypography.labelLarge.copyWith(
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Filter Pills
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                children: [
                                  _buildPill(music, 'all', 'All'),
                                  const SizedBox(width: 8),
                                  _buildPill(music, 'music', 'Music'),
                                  const SizedBox(width: 8),
                                  _buildPill(music, 'radio', 'Radio Stations'),
                                ],
                              ),
                            ),
                          ),
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
                            border: Border.all(color: AppColors.border, width: 1.5),
                            boxShadow: const [
                              BoxShadow(
                                color: AppColors.shadow,
                                offset: Offset(3, 3),
                                blurRadius: 0,
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

              // Recently Added Albums Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Text(
                    'Recently Added',
                    style: AppTypography.titleLarge,
                  ),
                ),
              ),

              // Horizontal Album Carousel
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 200,
                  child: music.isLoadingHome && music.recentAlbums.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(color: AppColors.primary),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: music.recentAlbums.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (ctx, i) {
                            final album = music.recentAlbums[i];
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

              // Frequently Played Albums Header
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
                      final album = music.frequentAlbums[i];
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
                    childCount: music.frequentAlbums.length,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPill(MusicProvider music, String key, String label) {
    final active = music.activeFilter == key;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        music.setFilter(key);
      },
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 14),
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
