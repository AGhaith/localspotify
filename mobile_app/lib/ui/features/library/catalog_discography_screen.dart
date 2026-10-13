import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/track.dart';
import '../../../data/services/spotify_service.dart';
import '../../../state/audio_player_provider.dart';
import '../../core_widgets/cached_cover_art.dart';
import '../../core_widgets/floating_sync_banner.dart';
import '../player/mini_player_bar.dart';
import 'catalog_album_screen.dart';

class CatalogDiscographyScreen extends StatefulWidget {
  final String artistName;
  final String initialFilter;
  final List<CatalogRelease> releases;
  final List<Track> libraryTracks;

  const CatalogDiscographyScreen({
    super.key,
    required this.artistName,
    required this.initialFilter,
    required this.releases,
    required this.libraryTracks,
  });

  @override
  State<CatalogDiscographyScreen> createState() => _CatalogDiscographyScreenState();
}

class _CatalogDiscographyScreenState extends State<CatalogDiscographyScreen> {
  late String _activeFilter;

  @override
  void initState() {
    super.initState();
    _activeFilter = widget.initialFilter;
  }

  List<CatalogRelease> _filterReleases(String filter) {
    switch (filter) {
      case 'Albums':
        return widget.releases.where((r) => r.recordType.toLowerCase() == 'album').toList();
      case 'Singles and EPs':
        return widget.releases
            .where((r) => r.recordType.toLowerCase() == 'single' || r.recordType.toLowerCase() == 'ep')
            .toList();
      case 'Compilations':
        return widget.releases.where((r) => r.recordType.toLowerCase() == 'compile').toList();
      case 'Popular releases':
      default:
        return widget.releases.where((r) => r.recordType.toLowerCase() != 'compile').toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<AudioPlayerProvider>();

    final hasCompilations = widget.releases.any((r) => r.recordType.toLowerCase() == 'compile');
    final availableFilters = [
      'Popular releases',
      'Albums',
      'Singles and EPs',
      if (hasCompilations) 'Compilations',
    ];

    final displayed = _filterReleases(_activeFilter);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          widget.artistName,
          style: AppTypography.titleLarge.copyWith(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      bottomNavigationBar: player.hasTrack ? const MiniPlayerBar(isStandalone: true) : null,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Filter Chips
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 56,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: 6),
                    scrollDirection: Axis.horizontal,
                    itemCount: availableFilters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (ctx, i) {
                      final filter = availableFilters[i];
                      final isSelected = filter == _activeFilter;
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _activeFilter = filter),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          constraints: const BoxConstraints(minHeight: 44),
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : AppColors.surface,
                            borderRadius: BorderRadius.circular(22),
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

              // Releases Grid
              if (displayed.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'No releases found',
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(AppSpacing.screenH),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: AppSpacing.rowGap,
                      mainAxisSpacing: AppSpacing.lg,
                      childAspectRatio: 0.72,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final release = displayed[i];
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CatalogAlbumScreen(
                                  albumId: release.id,
                                  albumTitle: release.title,
                                  artistName: widget.artistName,
                                  coverUrl: release.coverUrl,
                                  year: release.year,
                                  recordType: release.recordType,
                                  preloadedLibraryTracks: widget.libraryTracks,
                                ),
                              ),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AspectRatio(
                                aspectRatio: 1.0,
                                child: CachedCoverArt(
                                  imageUrl: release.coverUrl,
                                  borderRadius: AppRadius.card,
                                  placeholderIcon: Icons.album_rounded,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                release.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.titleMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
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
                        );
                      },
                      childCount: displayed.length,
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
          const FloatingSyncBanner(bottomOffset: 16),
        ],
      ),
    );
  }
}
