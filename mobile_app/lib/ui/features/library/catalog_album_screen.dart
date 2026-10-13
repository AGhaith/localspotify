import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/catalog_matcher.dart';
import '../../../data/models/track.dart';
import '../../../data/services/spotify_service.dart';
import '../../../state/audio_player_provider.dart';
import '../../../state/music_provider.dart';
import '../../core_widgets/cached_cover_art.dart';
import '../../core_widgets/catalog_track_row.dart';
import '../../core_widgets/floating_sync_banner.dart';
import '../../core_widgets/track_row.dart';
import '../player/mini_player_bar.dart';

class CatalogAlbumScreen extends StatefulWidget {
  final String albumId;
  final String albumTitle;
  final String artistName;
  final String? coverUrl;
  final String? year;
  final String? recordType;
  final List<Track>? preloadedLibraryTracks;

  const CatalogAlbumScreen({
    super.key,
    required this.albumId,
    required this.albumTitle,
    required this.artistName,
    this.coverUrl,
    this.year,
    this.recordType,
    this.preloadedLibraryTracks,
  });

  @override
  State<CatalogAlbumScreen> createState() => _CatalogAlbumScreenState();
}

class _CatalogAlbumScreenState extends State<CatalogAlbumScreen> {
  final SpotifyService _spotifyService = SpotifyService();
  List<SpotifyTrackItem>? _tracks;
  List<Track> _libraryTracks = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    if (widget.preloadedLibraryTracks != null) {
      _libraryTracks = widget.preloadedLibraryTracks!;
    }
    _loadTracks();
  }

  Future<void> _loadTracks({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // If library tracks weren't preloaded, fetch them in parallel
      if (_libraryTracks.isEmpty && widget.artistName.trim().isNotEmpty) {
        final music = context.read<MusicProvider>();
        final artistId = 'sub_name_${Uri.encodeComponent(widget.artistName.trim())}';
        music.getArtistDetails(artistId).then((artist) {
          return music.getArtistLibraryTracks(artist);
        }).then((libTracks) {
          if (mounted) {
            setState(() {
              _libraryTracks = libTracks;
            });
          }
        }).catchError((_) {});
      }

      final tracks = await _spotifyService.fetchAlbumTracks(
        widget.albumId,
        forceRefresh: forceRefresh,
      );

      if (mounted) {
        setState(() {
          _tracks = tracks;
          _isLoading = false;
          _hasError = tracks.isEmpty;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _tracks = null;
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  void _playAll({bool shuffle = false}) {
    HapticFeedback.heavyImpact();
    final tracks = _tracks;
    if (tracks == null || tracks.isEmpty) return;

    final player = context.read<AudioPlayerProvider>();
    final music = context.read<MusicProvider>();

    // Map catalog tracks to library tracks where available
    final matchedTracks = <Track>[];
    for (final ct in tracks) {
      final match = findLibraryMatch(ct, _libraryTracks);
      if (match != null) {
        matchedTracks.add(match);
      }
    }

    if (matchedTracks.isNotEmpty) {
      final toPlay = List<Track>.from(matchedTracks);
      if (shuffle) {
        toPlay.shuffle();
      }
      player.playTracks(tracks: toPlay, initialIndex: 0);
    } else {
      // First track needs sync/conversion
      final first = shuffle ? (List<SpotifyTrackItem>.from(tracks)..shuffle()).first : tracks.first;
      music.convertAndSyncSpotifyTrack(first).then((synced) {
        if (synced != null && mounted) {
          player.playTracks(tracks: [synced], initialIndex: 0);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<AudioPlayerProvider>();

    final typeLabel = widget.recordType != null && widget.recordType!.isNotEmpty
        ? (widget.recordType!.toLowerCase() == 'single'
            ? 'Single'
            : widget.recordType!.toLowerCase() == 'ep'
                ? 'EP'
                : 'Album')
        : 'Album';

    final trackCount = _tracks?.length;
    final metadataString = [
      if (widget.year != null && widget.year!.isNotEmpty) widget.year!,
      typeLabel,
      if (trackCount != null && trackCount > 0)
        '$trackCount ${trackCount == 1 ? "song" : "songs"}',
    ].join(' • ');

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: player.hasTrack ? const MiniPlayerBar(isStandalone: true) : null,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Hero AppBar
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                backgroundColor: AppColors.card,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: () => Navigator.maybePop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedCoverArt(
                        imageUrl: widget.coverUrl,
                        borderRadius: 0,
                        placeholderIcon: Icons.album_rounded,
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.3),
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

              // Album Info & Play Controls
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.albumTitle,
                        style: AppTypography.displayMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () {
                          context.read<MusicProvider>().openArtistByName(context, widget.artistName);
                        },
                        child: Text(
                          widget.artistName,
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (metadataString.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          metadataString,
                          style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => _playAll(shuffle: false),
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.black,
                                size: 32,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: const Icon(Icons.shuffle_rounded, size: 28),
                            color: AppColors.textSecondary,
                            onPressed: () => _playAll(shuffle: true),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Tracks List
              if (_isLoading)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _buildSkeletonRow(),
                    childCount: 8,
                  ),
                )
              else if (_hasError || _tracks == null || _tracks!.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Divider(color: AppColors.border, height: 1),
                        const SizedBox(height: 16),
                        Text(
                          'Unable to load release tracks',
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => _loadTracks(forceRefresh: true),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(color: AppColors.border),
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final catTrack = _tracks![i];
                      final libMatch = findLibraryMatch(catTrack, _libraryTracks);

                      if (libMatch != null) {
                        return TrackRow(
                          track: libMatch,
                          index: i + 1,
                          showCover: false,
                          onTap: () {
                            final playList = <Track>[];
                            for (final ct in _tracks!) {
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
                        showCover: false,
                      );
                    },
                    childCount: _tracks!.length,
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
          const FloatingSyncBanner(bottomOffset: 16),
        ],
      ),
    );
  }

  Widget _buildSkeletonRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          const SizedBox(width: 14),
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
                  width: 120,
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
}
