import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/album.dart';
import '../../../data/models/artist.dart';
import '../../../data/models/playlist.dart';
import '../../../state/music_provider.dart';
import '../../core_widgets/cached_cover_art.dart';
import '../../core_widgets/pressable_scale.dart';
import 'artist_detail_screen.dart';
import 'album_detail_screen.dart';
import 'import_spotify_playlist_sheet.dart';
import 'liked_songs_screen.dart';
import 'playlist_detail_screen.dart';

sealed class _LibraryEntry {
  final String title;
  const _LibraryEntry(this.title);
}

class _LikedSongsEntry extends _LibraryEntry {
  const _LikedSongsEntry() : super('Liked Songs');
}

class _PlaylistEntry extends _LibraryEntry {
  final Playlist playlist;
  _PlaylistEntry(this.playlist) : super(playlist.name);
}

class _ArtistEntry extends _LibraryEntry {
  final Artist artist;
  _ArtistEntry(this.artist) : super(artist.name);
}

class _AlbumEntry extends _LibraryEntry {
  final Album album;
  _AlbumEntry(this.album) : super(album.name);
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String? _selectedFilter; // null = all

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MusicProvider>().loadLibrary();
    });
  }

  void _showAddBottomSheet(BuildContext context, MusicProvider music) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.music_note_rounded,
                    color: Colors.white, size: 24),
                title: Text('Playlist', style: AppTypography.titleMedium),
                subtitle: Text('Create a playlist with songs',
                    style: AppTypography.bodySmall),
                onTap: () {
                  Navigator.pop(ctx);
                  _showCreatePlaylistDialog(context, music);
                },
              ),
              ListTile(
                leading: const Icon(Icons.download_rounded,
                    color: AppColors.primary, size: 24),
                title: Text('Import from Spotify',
                    style: AppTypography.titleMedium),
                subtitle: Text('Sync a Spotify playlist into your library',
                    style: AppTypography.bodySmall),
                onTap: () {
                  Navigator.pop(ctx);
                  ImportSpotifyPlaylistSheet.show(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
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
            child: const Text('Create',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();

    final List<_LibraryEntry> items = [];
    if (_selectedFilter == 'Artists') {
      for (final artist in music.libraryArtists) {
        items.add(_ArtistEntry(artist));
      }
    } else if (_selectedFilter == 'Albums') {
      items.addAll(music.savedAlbums.map(_AlbumEntry.new));
    } else if (_selectedFilter == 'Playlists') {
      items.add(const _LikedSongsEntry());
      final sortedPlaylists = List<Playlist>.from(music.playlists)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      for (final pl in sortedPlaylists) {
        items.add(_PlaylistEntry(pl));
      }
    } else {
      // All (no filter)
      items.add(const _LikedSongsEntry());
      final List<_LibraryEntry> otherEntries = [];
      for (final pl in music.playlists) {
        otherEntries.add(_PlaylistEntry(pl));
      }
      for (final album in music.savedAlbums) {
        otherEntries.add(_AlbumEntry(album));
      }
      otherEntries.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      items.addAll(otherEntries);
    }

    final showEmptyPlaylists = music.playlists.isEmpty &&
        (_selectedFilter == null || _selectedFilter == 'Playlists');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.card,
          onRefresh: () => music.loadLibrary(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.screenH,
                      AppSpacing.lg, AppSpacing.sm, AppSpacing.lg),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Your Library', style: AppTypography.displayMedium),
                      IconButton(
                        icon: const Icon(Icons.add_rounded,
                            color: AppColors.textPrimary, size: 28),
                        tooltip: 'Create or import',
                        onPressed: () => _showAddBottomSheet(context, music),
                      ),
                    ],
                  ),
                ),
              ),

              // Filter Chips
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.lg),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        if (_selectedFilter != null) ...[
                          _buildClearFilterChip(),
                          const SizedBox(width: AppSpacing.sm),
                          _buildFilterPill(_selectedFilter!, _selectedFilter!),
                        ] else ...[
                          _buildFilterPill('Playlists', 'Playlists'),
                          if (music.savedAlbums.isNotEmpty) ...[
                            const SizedBox(width: AppSpacing.sm),
                            _buildFilterPill('Albums', 'Albums'),
                          ],
                          const SizedBox(width: AppSpacing.sm),
                          _buildFilterPill('Artists', 'Artists'),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              if (music.libraryError != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenH,
                        vertical: AppSpacing.rowGap),
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

              // Unified Single Vertical List
              if (music.libraryError == null)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenH),
                  sliver: SliverList.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.rowGap),
                    itemBuilder: (ctx, i) {
                      final entry = items[i];
                      return switch (entry) {
                        _LikedSongsEntry() =>
                          _buildLikedSongsRow(context, music),
                        _PlaylistEntry(:final playlist) =>
                          _buildPlaylistRow(context, music, playlist),
                        _ArtistEntry(:final artist) =>
                          _buildArtistRow(context, music, artist),
                        _AlbumEntry(:final album) =>
                          _buildAlbumRow(context, music, album),
                      };
                    },
                  ),
                ),

              if (_selectedFilter == 'Albums' && items.isEmpty &&
                  music.libraryError == null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sectionGap),
                    child: Center(
                      child: Text('No saved albums yet',
                          style: AppTypography.bodySmall),
                    ),
                  ),
                ),

              // Empty state when there are no playlists
              if (showEmptyPlaylists && music.libraryError == null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sectionGap),
                    child: Center(
                      child: InkWell(
                        onTap: () => _showAddBottomSheet(context, music),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.screenH,
                              vertical: AppSpacing.sm),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add_rounded,
                                  color: AppColors.textMuted, size: 18),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                'Create your first playlist',
                                style: AppTypography.bodySmall
                                    .copyWith(color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Bottom padding so mini-player does not cover last row
              const SliverToBoxAdapter(
                child: SizedBox(height: 140),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClearFilterChip() {
    return Semantics(
      label: 'Clear filter',
      button: true,
      child: PressableScale(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedFilter = null);
        },
        scaleFactor: 0.94,
        child: Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: AppColors.cardHover,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.close_rounded, color: Colors.white, size: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterPill(String id, String label) {
    final active = _selectedFilter == id;
    return PressableScale(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          if (_selectedFilter == id) {
            _selectedFilter = null;
          } else {
            _selectedFilter = id;
          }
        });
      },
      scaleFactor: 0.94,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.cardHover,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.labelLarge.copyWith(
              color: active ? Colors.black : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow({
    required Widget leading,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? subtitleColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            leading,
            const SizedBox(width: AppSpacing.rowGap),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle,
                    style: AppTypography.bodySmall.copyWith(
                      color: subtitleColor ?? AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLikedSongsRow(BuildContext context, MusicProvider music) {
    final count = music.starredTracks.length;
    final countText = '$count ${count == 1 ? 'song' : 'songs'}';
    return _buildRow(
      leading: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.border),
        ),
        child:
            const Icon(Icons.favorite_rounded, color: Colors.white, size: 26),
      ),
      title: 'Liked Songs',
      subtitle: 'Playlist • $countText',
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LikedSongsScreen()),
        );
      },
    );
  }

  Widget _buildPlaylistRow(
      BuildContext context, MusicProvider music, Playlist pl) {
    final coverUrl = music.getCoverArtUrl(
      pl.coverArtId,
      size: 150,
      playlistId: pl.id,
      playlistName: pl.name,
      songCount: pl.songCount,
    );
    final importedTracks = music.getImportedPlaylistTracks(pl.id).isNotEmpty
        ? music.getImportedPlaylistTracks(pl.id)
        : music.getImportedPlaylistTracks(pl.name);
    final effectiveCount =
        pl.songCount > 0 ? pl.songCount : importedTracks.length;
    final countText =
        '$effectiveCount ${effectiveCount == 1 ? 'song' : 'songs'}';
    final isSyncing = pl.songCount == 0 && effectiveCount > 0;
    final subtitle = isSyncing
        ? 'Playlist • $countText • Syncing...'
        : 'Playlist • $countText';

    return _buildRow(
      leading: CachedCoverArt(
        imageUrl: coverUrl,
        width: 56,
        height: 56,
        borderRadius: 4,
        placeholderIcon: Icons.queue_music_rounded,
      ),
      title: pl.name,
      subtitle: subtitle,
      subtitleColor: isSyncing ? AppColors.primary : AppColors.textSecondary,
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
  }

  Widget _buildArtistRow(
      BuildContext context, MusicProvider music, Artist artist) {
    return _buildRow(
      leading: CachedCoverArt(
        imageUrl: music.getCoverArtUrl(artist.coverArtId, size: 150),
        width: 56,
        height: 56,
        borderRadius: 28,
        placeholderIcon: Icons.person_rounded,
      ),
      title: artist.name,
      subtitle: 'Artist',
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ArtistDetailScreen(artistId: artist.id),
          ),
        );
      },
    );
  }

  Widget _buildAlbumRow(
      BuildContext context, MusicProvider music, Album album) {
    return _buildRow(
      leading: CachedCoverArt(
        imageUrl: music.getCoverArtUrl(album.coverArtId, size: 150),
        width: 56,
        height: 56,
        borderRadius: 4,
        placeholderIcon: Icons.album_rounded,
      ),
      title: album.name,
      subtitle: 'Album • ${album.artist}',
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AlbumDetailScreen(albumId: album.id),
          ),
        );
      },
    );
  }
}
