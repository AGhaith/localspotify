import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/catalog_matcher.dart';
import '../../../data/models/artist.dart';
import '../../../data/models/track.dart';
import '../../../data/services/spotify_service.dart';
import '../../../state/audio_player_provider.dart';
import '../../../state/music_provider.dart';
import '../../core_widgets/album_card.dart';
import '../../core_widgets/cached_cover_art.dart';
import '../../core_widgets/catalog_track_row.dart';
import '../../core_widgets/floating_sync_banner.dart';
import '../../core_widgets/track_row.dart';
import '../player/mini_player_bar.dart';
import 'album_detail_screen.dart';
import 'catalog_album_screen.dart';
import 'catalog_discography_screen.dart';

class ArtistDetailScreen extends StatefulWidget {
  final String artistId;

  const ArtistDetailScreen({super.key, required this.artistId});

  @override
  State<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends State<ArtistDetailScreen> {
  final SpotifyService _spotifyService = SpotifyService();

  Artist? _artist;
  List<Track> _libraryTracks = [];
  bool _isLoadingArtist = true;
  bool _artistFailed = false;

  ArtistProfile? _catalogProfile;
  bool _isLoadingCatalog = false;
  bool _catalogFailed = false;
  String? _catalogArtistName;

  bool _isBioExpanded = false;
  bool _isPopularExpanded = false;
  String _selectedDiscographyFilter = 'Popular releases';
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData({bool forceRefresh = false}) {
    final music = context.read<MusicProvider>();

    if (forceRefresh) {
      setState(() {
        _catalogProfile = null;
        _catalogArtistName = null;
        _catalogFailed = false;
        _isLoadingCatalog = true;
      });
    }

    // Try instant match from already-loaded library artists to render header immediately
    if (_artist == null && !forceRefresh) {
      final cached = music.artists.where((a) => a.id == widget.artistId).firstOrNull;
      if (cached != null) {
        _artist = cached;
        _isLoadingArtist = false;
        _loadLibraryTracks(cached);
        _fetchCatalog(cached.name, forceRefresh: forceRefresh);
      }
    }

    music.getArtistDetails(widget.artistId, forceRefresh: forceRefresh).then((artist) {
      if (mounted) {
        setState(() {
          _artist = artist;
          _isLoadingArtist = false;
          _artistFailed = false;
        });
        _loadLibraryTracks(artist);
        _fetchCatalog(artist.name, forceRefresh: forceRefresh);
      }
    }).catchError((_) {
      if (mounted) {
        setState(() {
          _isLoadingArtist = false;
          if (_artist == null) {
            _artistFailed = true;
          }
        });
      }
    });
  }

  Future<void> _loadLibraryTracks(Artist artist) async {
    try {
      final libTracks = await context.read<MusicProvider>().getArtistLibraryTracks(artist);
      if (mounted) {
        setState(() {
          _libraryTracks = libTracks;
        });
      }
    } catch (_) {
      // Fallback to embedded artist tracks
      if (mounted && _libraryTracks.isEmpty) {
        final fallback = <Track>[
          ...artist.topTracks,
          for (final alb in artist.albums) ...alb.tracks,
        ];
        final seen = <String>{};
        final unique = fallback.where((t) => seen.add(t.id)).toList();
        setState(() {
          _libraryTracks = unique;
        });
      }
    }
  }

  Future<void> _fetchCatalog(String artistName, {bool forceRefresh = false}) async {
    final clean = artistName.trim();
    if (clean.isEmpty) return;
    if (!forceRefresh && _catalogArtistName == clean && _catalogProfile != null) return;

    _catalogArtistName = clean;
    if (forceRefresh) {
      _spotifyService.invalidateArtistCache(clean);
    }

    setState(() {
      _isLoadingCatalog = true;
      _catalogFailed = false;
    });

    try {
      final profile = await _spotifyService.fetchArtistProfile(clean, forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _catalogProfile = profile;
          _isLoadingCatalog = false;
          _catalogFailed = profile.isEmpty;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _catalogProfile = null;
          _isLoadingCatalog = false;
          _catalogFailed = true;
        });
      }
    }
  }

  void _retry() {
    _loadData(forceRefresh: true);
  }

  void _playPopular({bool shuffle = false}) {
    HapticFeedback.heavyImpact();
    final player = context.read<AudioPlayerProvider>();
    final music = context.read<MusicProvider>();

    final catTop = _catalogProfile?.topTracks ?? [];

    if (catTop.isNotEmpty) {
      final matchedTracks = <Track>[];
      for (final ct in catTop) {
        final match = findLibraryMatch(ct, _libraryTracks);
        if (match != null) {
          matchedTracks.add(match);
        }
      }

      if (matchedTracks.isNotEmpty) {
        final toPlay = List<Track>.from(matchedTracks);
        if (shuffle) toPlay.shuffle();
        player.playTracks(tracks: toPlay, initialIndex: 0);
        return;
      }

      // Catalog-only: sync first track
      final first = shuffle
          ? (List<SpotifyTrackItem>.from(catTop)..shuffle()).first
          : catTop.first;
      music.convertAndSyncSpotifyTrack(first).then((synced) {
        if (synced != null && mounted) {
          player.playTracks(tracks: [synced], initialIndex: 0);
        }
      });
      return;
    }

    // Fallback to library tracks
    final libTracks = _artist?.topTracks.isNotEmpty == true
        ? _artist!.topTracks
        : _libraryTracks;

    if (libTracks.isNotEmpty) {
      final toPlay = List<Track>.from(libTracks);
      if (shuffle) toPlay.shuffle();
      player.playTracks(tracks: toPlay, initialIndex: 0);
    }
  }

  List<CatalogRelease> _filterReleases(List<CatalogRelease> all, String filter) {
    switch (filter) {
      case 'Albums':
        return all.where((r) => r.recordType.toLowerCase() == 'album').toList();
      case 'Singles and EPs':
        return all
            .where((r) => r.recordType.toLowerCase() == 'single' || r.recordType.toLowerCase() == 'ep')
            .toList();
      case 'Compilations':
        return all.where((r) => r.recordType.toLowerCase() == 'compile').toList();
      case 'Popular releases':
      default:
        return all.where((r) => r.recordType.toLowerCase() != 'compile').toList();
    }
  }

  void _openRelatedArtist(String name, String id) {
    if (_isNavigating) return;

    // Exclude current artist and guard against duplicate route
    if (id == widget.artistId ||
        (_artist != null && normalizeArtistName(name) == normalizeArtistName(_artist!.name))) {
      return;
    }

    _isNavigating = true;
    context.read<MusicProvider>().openArtistByName(context, name).whenComplete(() {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted) _isNavigating = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final player = context.watch<AudioPlayerProvider>();

    if (_isLoadingArtist && _artist == null) {
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
        bottomNavigationBar: player.hasTrack ? const MiniPlayerBar(isStandalone: true) : null,
        body: _buildPageLoadingSkeleton(),
      );
    }

    if (_artistFailed && _artist == null) {
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
        bottomNavigationBar: player.hasTrack ? const MiniPlayerBar(isStandalone: true) : null,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Unable to load artist information',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _retry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final artist = _artist!;
    final coverUrl = _catalogProfile?.pictureUrl ??
        artist.artistImageUrl ??
        music.getCoverArtUrl(artist.coverArtId, size: 600);

    final catalog = _catalogProfile;
    final catTop = catalog?.topTracks ?? const <SpotifyTrackItem>[];
    final catReleases = catalog?.releases ?? const <CatalogRelease>[];
    final hasCatalogTop = catTop.isNotEmpty;
    final hasCatalogReleases = catReleases.isNotEmpty;

    // Discography filter chips
    final hasCompilations = catReleases.any((r) => r.recordType.toLowerCase() == 'compile');
    final filterChips = [
      'Popular releases',
      'Albums',
      'Singles and EPs',
      if (hasCompilations) 'Compilations',
    ];

    final filteredReleases = _filterReleases(catReleases, _selectedDiscographyFilter);

    // Popular tracks to display
    final popularTracksCount = hasCatalogTop
        ? (_isPopularExpanded ? catTop.length.clamp(0, 10) : catTop.length.clamp(0, 5))
        : (_isPopularExpanded ? artist.topTracks.length.clamp(0, 10) : artist.topTracks.length.clamp(0, 5));

    // Related artists (Deezer related preferred; fallback to Subsonic similar)
    final deezerRelated = catalog?.relatedArtists ?? const <CatalogRelatedArtist>[];
    final hasDeezerRelated = deezerRelated.isNotEmpty;
    final subsonicRelated = artist.similarArtists
        .where((s) => s.id != widget.artistId && normalizeArtistName(s.name) != normalizeArtistName(artist.name))
        .toList();
    final hasRelated = hasDeezerRelated || subsonicRelated.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: player.hasTrack ? const MiniPlayerBar(isStandalone: true) : null,
      body: Stack(
        children: [
          RefreshIndicator(
            color: Colors.white,
            backgroundColor: AppColors.card,
            onRefresh: () async {
              _loadData(forceRefresh: true);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                // 1. Header: SliverAppBar collapsing on scroll
                SliverAppBar(
                  expandedHeight: 320,
                  pinned: true,
                  backgroundColor: AppColors.card,
                  automaticallyImplyLeading: true,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsetsDirectional.only(start: 72, bottom: 16, end: 16),
                    title: Text(
                      artist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
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
                                Colors.black.withValues(alpha: 0.2),
                                AppColors.background.withValues(alpha: 0.8),
                                AppColors.background,
                              ],
                              stops: const [0.0, 0.45, 0.85, 1.0],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. Play & Shuffle Action Row (White circular Play + Shuffle icon)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => _playPopular(shuffle: false),
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.black,
                              size: 36,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.shuffle_rounded, size: 28),
                          color: AppColors.textSecondary,
                          onPressed: () => _playPopular(shuffle: true),
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. "Popular" Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Text('Popular', style: AppTypography.titleLarge),
                  ),
                ),

                if (hasCatalogTop) ...[
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final catTrack = catTop[i];
                        final libMatch = findLibraryMatch(catTrack, _libraryTracks);

                        if (libMatch != null) {
                          return TrackRow(
                            track: libMatch,
                            index: i + 1,
                            showCover: true,
                            onTap: () {
                              final playList = <Track>[];
                              for (final ct in catTop) {
                                final m = findLibraryMatch(ct, _libraryTracks);
                                if (m != null) playList.add(m);
                              }
                              final idx = playList.indexOf(libMatch);
                              player.playTracks(
                                tracks: playList.isNotEmpty ? playList : [libMatch],
                                initialIndex: idx >= 0 ? idx : 0,
                              );
                            },
                          );
                        }

                        return CatalogTrackRow(
                          item: catTrack,
                          index: i + 1,
                          showCover: true,
                        );
                      },
                      childCount: popularTracksCount,
                    ),
                  ),
                  if (catTop.length > 5)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () => setState(() => _isPopularExpanded = !_isPopularExpanded),
                            child: Text(
                              _isPopularExpanded ? 'Show less' : 'See more',
                              style: AppTypography.labelMedium.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ] else if (artist.topTracks.isNotEmpty) ...[
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final track = artist.topTracks[i];
                        return TrackRow(
                          track: track,
                          index: i + 1,
                          showCover: true,
                          onTap: () {
                            player.playTracks(tracks: artist.topTracks, initialIndex: i);
                          },
                        );
                      },
                      childCount: popularTracksCount,
                    ),
                  ),
                  if (artist.topTracks.length > 5)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () => setState(() => _isPopularExpanded = !_isPopularExpanded),
                            child: Text(
                              _isPopularExpanded ? 'Show less' : 'See more',
                              style: AppTypography.labelMedium.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ] else if (_isLoadingCatalog)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _buildSkeletonTrackRow(showCover: true),
                      childCount: 5,
                    ),
                  ),

                // Subtle muted divider if catalog failed, never blocks page
                if (_catalogFailed && !_isLoadingCatalog)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Divider(color: AppColors.border, height: 1),
                    ),
                  ),

                // 4. "Discography" Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Discography', style: AppTypography.titleLarge),
                        if (hasCatalogReleases && filteredReleases.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CatalogDiscographyScreen(
                                    artistName: artist.name,
                                    initialFilter: _selectedDiscographyFilter,
                                    releases: catReleases,
                                    libraryTracks: _libraryTracks,
                                  ),
                                ),
                              );
                            },
                            child: Text(
                              'Show all',
                              style: AppTypography.labelMedium.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Filter chips (Popular releases | Albums | Singles and EPs | Compilations)
                if (hasCatalogReleases)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 44,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        scrollDirection: Axis.horizontal,
                        itemCount: filterChips.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (ctx, i) {
                          final filter = filterChips[i];
                          final isSelected = filter == _selectedDiscographyFilter;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedDiscographyFilter = filter),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : AppColors.surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? Colors.white : AppColors.border,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  filter,
                                  style: AppTypography.labelMedium.copyWith(
                                    color: isSelected ? Colors.black : AppColors.textPrimary,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                // Horizontal Album Cards
                if (hasCatalogReleases)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 220,
                      child: filteredReleases.isEmpty
                          ? Center(
                              child: Text(
                                'No releases found',
                                style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: filteredReleases.length.clamp(0, 10),
                              separatorBuilder: (_, __) => const SizedBox(width: 14),
                              itemBuilder: (ctx, i) {
                                final release = filteredReleases[i];
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CatalogAlbumScreen(
                                          albumId: release.id,
                                          albumTitle: release.title,
                                          artistName: artist.name,
                                          coverUrl: release.coverUrl,
                                          year: release.year,
                                          recordType: release.recordType,
                                          preloadedLibraryTracks: _libraryTracks,
                                        ),
                                      ),
                                    );
                                  },
                                  child: SizedBox(
                                    width: 136,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        AspectRatio(
                                          aspectRatio: 1.0,
                                          child: CachedCoverArt(
                                            imageUrl: release.coverUrl,
                                            borderRadius: 8,
                                            placeholderIcon: Icons.album_rounded,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          release.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.titleMedium.copyWith(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${release.year ?? ''} • ${release.typeLabel}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.bodySmall.copyWith(
                                            color: AppColors.textMuted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  )
                else if (artist.albums.isNotEmpty)
                  // Fallback to library albums
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 200,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  )
                else if (_isLoadingCatalog)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 200,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        scrollDirection: Axis.horizontal,
                        itemCount: 4,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (_, __) => _buildSkeletonCard(),
                      ),
                    ),
                  ),

                // 5. "Fans Also Like" Section
                if (hasRelated) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                      child: Text('Fans Also Like', style: AppTypography.titleLarge),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 125,
                      child: hasDeezerRelated
                          ? ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: deezerRelated.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 16),
                              itemBuilder: (ctx, i) {
                                final rel = deezerRelated[i];
                                return GestureDetector(
                                  onTap: () => _openRelatedArtist(rel.name, rel.id),
                                  child: SizedBox(
                                    width: 80,
                                    child: Column(
                                      children: [
                                        CachedCoverArt(
                                          imageUrl: rel.pictureUrl,
                                          width: 76,
                                          height: 76,
                                          borderRadius: 999,
                                          placeholderIcon: Icons.person_rounded,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          rel.name,
                                          maxLines: 1,
                                          textAlign: TextAlign.center,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.bodySmall.copyWith(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: subsonicRelated.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 16),
                              itemBuilder: (ctx, i) {
                                final sim = subsonicRelated[i];
                                return GestureDetector(
                                  onTap: () => _openRelatedArtist(sim.name, sim.id),
                                  child: SizedBox(
                                    width: 80,
                                    child: Column(
                                      children: [
                                        CachedCoverArt(
                                          imageUrl: sim.artistImageUrl ??
                                              music.getCoverArtUrl(sim.coverArtId, size: 150),
                                          width: 76,
                                          height: 76,
                                          borderRadius: 999,
                                          placeholderIcon: Icons.person_rounded,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          sim.name,
                                          maxLines: 1,
                                          textAlign: TextAlign.center,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.bodySmall.copyWith(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ],

                // 6. "About the Artist" Section
                if (artist.biography != null && artist.biography!.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
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
                            Text('About the Artist', style: AppTypography.titleMedium),
                            const SizedBox(height: 8),
                            Text(
                              _cleanBio(artist.biography!),
                              maxLines: _isBioExpanded ? 100 : 3,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () => setState(() => _isBioExpanded = !_isBioExpanded),
                              child: Text(
                                _isBioExpanded ? 'Show less' : 'Read more',
                                style: AppTypography.labelSmall.copyWith(
                                  color: Colors.white,
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

                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),
          const FloatingSyncBanner(bottomOffset: 16),
        ],
      ),
    );
  }

  Widget _buildPageLoadingSkeleton() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 280,
            width: double.infinity,
            color: AppColors.card,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.card,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              width: 100,
              height: 20,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          for (int i = 0; i < 5; i++) _buildSkeletonTrackRow(showCover: true),
        ],
      ),
    );
  }

  Widget _buildSkeletonTrackRow({bool showCover = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          if (showCover) ...[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 12),
          ],
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
                  width: 130,
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
            width: 32,
            height: 12,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonCard() {
    return SizedBox(
      width: 136,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 136,
            height: 136,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 100,
            height: 12,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 60,
            height: 10,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  String _cleanBio(String raw) {
    return raw.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), '').trim();
  }
}
