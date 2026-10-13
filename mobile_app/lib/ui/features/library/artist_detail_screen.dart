import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/artist.dart';
import '../../../data/models/track.dart';
import '../../../data/services/spotify_service.dart';
import '../../../state/audio_player_provider.dart';
import '../../../state/music_provider.dart';
import '../../core_widgets/album_card.dart';
import '../../core_widgets/cached_cover_art.dart';
import '../../core_widgets/catalog_track_row.dart';
import '../../core_widgets/floating_sync_banner.dart';
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

  ArtistCatalog? _catalog;
  bool _isLoadingCatalog = false;
  bool _catalogFailed = false;
  String? _catalogArtistName;

  @override
  void initState() {
    super.initState();
    _loadArtist();
  }

  void _loadArtist({bool forceRefresh = false}) {
    _artistFuture = context.read<MusicProvider>().getArtistDetails(
      widget.artistId,
      forceRefresh: forceRefresh,
    );
    _artistFuture.then((artist) {
      if (mounted) {
        _fetchCatalog(artist.name);
      }
    }).catchError((_) {
      if (mounted) {
        setState(() {
          _isLoadingCatalog = false;
          _catalogFailed = true;
        });
      }
    });
  }

  void _retry() {
    setState(() {
      _catalog = null;
      _isLoadingCatalog = false;
      _catalogFailed = false;
      _catalogArtistName = null;
      _loadArtist(forceRefresh: true);
    });
  }

  Future<void> _fetchCatalog(String artistName) async {
    final clean = artistName.trim();
    if (clean.isEmpty || (_catalogArtistName == clean && _catalog != null)) return;
    _catalogArtistName = clean;

    setState(() {
      _isLoadingCatalog = true;
      _catalogFailed = false;
    });

    try {
      final catalog = await context.read<MusicProvider>().getArtistCatalog(clean);
      if (mounted) {
        setState(() {
          _catalog = catalog;
          _isLoadingCatalog = false;
          _catalogFailed = catalog.top.isEmpty && catalog.albums.isEmpty;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _catalog = null;
          _isLoadingCatalog = false;
          _catalogFailed = true;
        });
      }
    }
  }

  String _cleanString(String s) {
    var str = s.toLowerCase();
    str = str.replaceAll(
      RegExp(
        r'\s*[\(\[](?:feat\.?|ft\.?|with|live|remaster(?:ed)?|deluxe|version|radio edit|bonus|instrumental|edit|mix)[^\)\]]*[\)\]]',
        caseSensitive: false,
      ),
      '',
    );
    str = str.replaceAll(RegExp(r'[^\w\s\u0600-\u06FF]'), ' ');
    return str.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Track? _findLibraryMatch(SpotifyTrackItem catalogTrack, List<Track> libraryTracks) {
    final catTitle = _cleanString(catalogTrack.title);
    if (catTitle.isEmpty) return null;

    final catArtist = _cleanString(catalogTrack.artist);
    final catPrimary = _cleanString(catalogTrack.primaryArtist);

    for (final libTrack in libraryTracks) {
      final libTitle = _cleanString(libTrack.title);
      if (libTitle == catTitle) {
        final libArtist = _cleanString(libTrack.artist);
        if (libArtist.isEmpty || catArtist.isEmpty) {
          return libTrack;
        }
        if (libArtist == catArtist ||
            libArtist == catPrimary ||
            (catPrimary.isNotEmpty && libArtist.contains(catPrimary)) ||
            (catArtist.isNotEmpty && libArtist.contains(catArtist)) ||
            (libArtist.isNotEmpty && catArtist.contains(libArtist))) {
          return libTrack;
        }
      }
    }
    return null;
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

        // Collect all distinct library tracks for this artist
        final seenTrackIds = <String>{};
        final libraryTracks = <Track>[];
        for (final t in [...artist.topTracks, for (final alb in artist.albums) ...alb.tracks]) {
          if (seenTrackIds.add(t.id)) {
            libraryTracks.add(t);
          }
        }

        final catalog = _catalog;
        final hasCatalogTop = catalog != null && catalog.top.isNotEmpty;
        final hasCatalogAlbums = catalog != null && catalog.albums.isNotEmpty;

        return Scaffold(
          backgroundColor: AppColors.background,
          bottomNavigationBar: player.hasTrack
              ? const MiniPlayerBar(isStandalone: true)
              : null,
          body: Stack(
            children: [
              CustomScrollView(
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
                                  backgroundColor: AppColors.surface,
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

                  // 1. Popular (top 10)
                  if (hasCatalogTop) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                        child: Text('Popular', style: AppTypography.titleLarge),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final catTrack = catalog.top[i];
                          final libMatch = _findLibraryMatch(catTrack, libraryTracks);
                          if (libMatch != null) {
                            return TrackRow(
                              track: libMatch,
                              index: i + 1,
                              onTap: () {
                                final playList = artist.topTracks.contains(libMatch)
                                    ? artist.topTracks
                                    : libraryTracks;
                                final idx = playList.indexOf(libMatch);
                                player.playTracks(
                                  tracks: playList,
                                  initialIndex: idx >= 0 ? idx : 0,
                                );
                              },
                            );
                          }
                          return CatalogTrackRow(
                            item: catTrack,
                            index: i + 1,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                          );
                        },
                        childCount: catalog.top.length > 10 ? 10 : catalog.top.length,
                      ),
                    ),
                  ] else if (artist.topTracks.isNotEmpty) ...[
                    // While catalog is loading or if catalog failed, show library top tracks immediately
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                        child: Text('Popular', style: AppTypography.titleLarge),
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

                  // 2. Catalog loading skeleton
                  if (_isLoadingCatalog)
                    SliverToBoxAdapter(
                      child: _buildCatalogSkeleton(),
                    ),

                  // 3. Subtle line if catalog failed
                  if (_catalogFailed && !_isLoadingCatalog)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Divider(color: AppColors.border, height: 1),
                      ),
                    ),

                  // 4. All songs grouped by album
                  if (hasCatalogAlbums) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                        child: Text('All songs', style: AppTypography.titleLarge),
                      ),
                    ),
                    for (final album in catalog.albums) ...[
                      // Album header row: small cover, title, year
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: album.coverUrl != null && album.coverUrl!.isNotEmpty
                                    ? Image.network(
                                        album.coverUrl!,
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 40,
                                          height: 40,
                                          color: AppColors.card,
                                          child: const Icon(
                                            Icons.album_rounded,
                                            color: AppColors.textMuted,
                                            size: 20,
                                          ),
                                        ),
                                      )
                                    : Container(
                                        width: 40,
                                        height: 40,
                                        color: AppColors.card,
                                        child: const Icon(
                                          Icons.album_rounded,
                                          color: AppColors.textMuted,
                                          size: 20,
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      album.albumTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.titleMedium.copyWith(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (album.year != null && album.year!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        album.year!,
                                        style: AppTypography.bodySmall.copyWith(
                                          color: AppColors.textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Album tracks
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) {
                            final catTrack = album.tracks[i];
                            final libMatch = _findLibraryMatch(catTrack, libraryTracks);
                            if (libMatch != null) {
                              return TrackRow(
                                track: libMatch,
                                onTap: () {
                                  final playList = artist.topTracks.contains(libMatch)
                                      ? artist.topTracks
                                      : libraryTracks;
                                  final idx = playList.indexOf(libMatch);
                                  player.playTracks(
                                    tracks: playList,
                                    initialIndex: idx >= 0 ? idx : 0,
                                  );
                                },
                              );
                            }
                            return CatalogTrackRow(
                              item: catTrack,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                            );
                          },
                          childCount: album.tracks.length,
                        ),
                      ),
                    ],
                  ] else if ((_catalogFailed || catalog == null) && artist.albums.isNotEmpty) ...[
                    // Fallback to library discography carousel when catalog is not available
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
                            final alb = artist.albums[i];
                            return AlbumCard(
                              album: alb,
                              coverUrl: music.getCoverArtUrl(alb.coverArtId, size: 250),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AlbumDetailScreen(albumId: alb.id),
                                  ),
                                );
                              },
                              onPlayTap: () async {
                                final detailed = await music.getAlbumDetails(alb.id);
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
              // Floating Sync Progress Banner
              const FloatingSyncBanner(bottomOffset: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCatalogSkeleton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 100,
            height: 18,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < 4; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 14,
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 140,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 80,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _cleanBio(String raw) {
    // Strip HTML tags from Last.fm summary
    return raw.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), '').trim();
  }
}
