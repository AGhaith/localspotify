import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
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
import '../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  MusicProvider? _music;
  AudioPlayerProvider? _player;
  int _seenDownloadError = 0;
  int _seenPlaybackError = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final music = context.read<MusicProvider>();
    final player = context.read<AudioPlayerProvider>();
    if (_music != music) {
      _music?.removeListener(_showProviderErrors);
      _music = music;
      _seenDownloadError = music.downloadErrorVersion;
      music.addListener(_showProviderErrors);
    }
    if (_player != player) {
      _player?.removeListener(_showProviderErrors);
      _player = player;
      _seenPlaybackError = player.playbackErrorVersion;
      player.addListener(_showProviderErrors);
    }
  }

  void _showProviderErrors() {
    final music = _music;
    final player = _player;
    if (music != null && music.downloadErrorVersion != _seenDownloadError) {
      _seenDownloadError = music.downloadErrorVersion;
      final track = music.failedDownloadTrack;
      if (track != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Download failed'),
          action: SnackBarAction(
              label: 'Retry', onPressed: () => music.downloadTrack(track)),
        ));
      }
    }
    if (player != null && player.playbackErrorVersion != _seenPlaybackError) {
      _seenPlaybackError = player.playbackErrorVersion;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Can't play this song")),
      );
    }
  }

  @override
  void dispose() {
    _music?.removeListener(_showProviderErrors);
    _player?.removeListener(_showProviderErrors);
    super.dispose();
  }

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

    final albumsToDisplay =
        music.newestAlbums.isNotEmpty ? music.newestAlbums : music.recentAlbums;
    final displayedFrequentAlbums = music.frequentAlbums;

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
              // Profile and Liked Songs
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.screenH,
                      AppSpacing.md, AppSpacing.screenH, AppSpacing.sectionGap),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Semantics(
                            label: 'Profile and settings',
                            button: true,
                            child: PressableScale(
                              onTap: () => _showUserMenu(context, auth),
                              scaleFactor: 0.90,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    auth.session?.username.isNotEmpty == true
                                        ? auth.session!.username[0]
                                            .toUpperCase()
                                        : 'U',
                                    style: AppTypography.labelLarge.copyWith(
                                      color: AppColors.textDark,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),

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
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: AppColors.border, width: 1.0),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.cardHover,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: AppColors.border, width: 1.0),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.favorite_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.lg),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Liked Songs',
                                      style: AppTypography.titleLarge
                                          .copyWith(fontSize: 16),
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      '${music.starredTracks.length} ${music.starredTracks.length == 1 ? 'song' : 'songs'}',
                                      style: AppTypography.bodySmall
                                          .copyWith(color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded,
                                  color: Colors.white70),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (music.libraryError != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenH),
                    child: Row(
                      children: [
                        Expanded(
                            child: Text('Could not load Library',
                                style: AppTypography.bodySmall)),
                        TextButton(
                          onPressed: music.retryLibrary,
                          child: const Text('Retry',
                              style: TextStyle(color: AppColors.textPrimary)),
                        ),
                      ],
                    ),
                  ),
                ),

              // Recently Added Albums
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, 0,
                      AppSpacing.screenH, AppSpacing.rowGap),
                  child: Text(
                    'Recently Added',
                    style: AppTypography.titleLarge,
                  ),
                ),
              ),

              // Horizontal Album Carousel
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 215,
                  child: music.isLoadingHome && albumsToDisplay.isEmpty
                      ? _buildAlbumSkeletons()
                      : albumsToDisplay.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.screenH),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      music.homeError != null
                                          ? 'Could not load Library'
                                          : 'No albums found in Library',
                                      style: AppTypography.titleMedium.copyWith(
                                        color: music.homeError != null
                                            ? AppColors.error
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.refresh_rounded,
                                          size: 16),
                                      label: const Text('Retry'),
                                      onPressed: () => music.loadHomeFeed(
                                          showLoadingSkeleton: true),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.screenH),
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: albumsToDisplay.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: AppSpacing.lg),
                              itemBuilder: (ctx, i) {
                                final album = albumsToDisplay[i];
                                return _sizedAlbumCard(AlbumCard(
                                  album: album,
                                  coverUrl: music.getCoverArtUrl(
                                      album.coverArtId,
                                      size: 250),
                                  onTap: () => _openAlbum(context, album.id),
                                  onPlayTap: () async {
                                    final detailed =
                                        await music.getAlbumDetails(album.id);
                                    if (detailed.tracks.isNotEmpty) {
                                      player.playTracks(
                                          tracks: detailed.tracks,
                                          initialIndex: 0);
                                    }
                                  },
                                ));
                              },
                            ),
                ),
              ),

              // Popular Artists Section
              if (music.artists.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenH,
                        AppSpacing.sectionGap,
                        AppSpacing.screenH,
                        AppSpacing.rowGap),
                    child: Text('Artists You Might Like',
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
                      physics: const BouncingScrollPhysics(),
                      itemCount: music.artists.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: AppSpacing.lg),
                      itemBuilder: (ctx, i) {
                        final artist = music.artists[i];
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ArtistDetailScreen(artistId: artist.id),
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
                                placeholderIcon: Icons.person_rounded,
                              ),
                              const SizedBox(height: AppSpacing.sm),
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

              // Frequently Played Albums Header
              if (displayedFrequentAlbums.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenH,
                        AppSpacing.sectionGap,
                        AppSpacing.screenH,
                        AppSpacing.rowGap),
                    child: Text(
                      'Frequently Played',
                      style: AppTypography.titleLarge,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 215,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.screenH),
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: displayedFrequentAlbums.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: AppSpacing.lg),
                      itemBuilder: (ctx, i) {
                        final album = displayedFrequentAlbums[i];
                        return _sizedAlbumCard(AlbumCard(
                          album: album,
                          coverUrl:
                              music.getCoverArtUrl(album.coverArtId, size: 250),
                          onTap: () => _openAlbum(context, album.id),
                          onPlayTap: () async {
                            final detailed =
                                await music.getAlbumDetails(album.id);
                            if (detailed.tracks.isNotEmpty) {
                              player.playTracks(
                                  tracks: detailed.tracks, initialIndex: 0);
                            }
                          },
                        ));
                      },
                    ),
                  ),
                ),
              ],
              SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + AppSpacing.xl)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlbumSkeletons() => ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.lg),
        itemBuilder: (_, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _skeleton(150, 150),
            const SizedBox(height: AppSpacing.sm),
            _skeleton(110, AppSpacing.md),
            const SizedBox(height: AppSpacing.xs),
            _skeleton(75, AppSpacing.sm),
          ],
        ),
      );

  Widget _sizedAlbumCard(Widget card) => SizedBox(
        width: 150,
        child: Transform.scale(
          scale: 150 / 140,
          alignment: Alignment.topLeft,
          child: SizedBox(width: 140, child: card),
        ),
      );

  Widget _skeleton(double width, double height) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(8),
        ),
      );

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
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.person_rounded,
                      color: AppColors.primary),
                  title: Text(auth.session?.username ?? 'User',
                      style: AppTypography.titleMedium),
                  subtitle: Text(auth.session?.serverUrl ?? '',
                      style: AppTypography.bodySmall),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.settings_rounded,
                      color: AppColors.textPrimary),
                  title: Text('Settings & Storage',
                      style: AppTypography.bodyLarge),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
                ListTile(
                  leading:
                      const Icon(Icons.logout_rounded, color: AppColors.error),
                  title: Text('Log Out',
                      style: AppTypography.bodyLarge
                          .copyWith(color: AppColors.error)),
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
