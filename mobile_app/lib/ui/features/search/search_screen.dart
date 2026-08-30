import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../state/audio_player_provider.dart';
import '../../../state/music_provider.dart';
import '../../core_widgets/album_card.dart';
import '../../core_widgets/track_row.dart';
import '../library/album_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final player = context.read<AudioPlayerProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Search Input Field
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => music.search(val),
                style: AppTypography.bodyLarge,
                decoration: InputDecoration(
                  hintText: 'What do you want to listen to?',
                  prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass, color: AppColors.textSecondary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(PhosphorIconsRegular.x, color: AppColors.textSecondary),
                          onPressed: () {
                            _searchController.clear();
                            music.search('');
                          },
                        )
                      : null,
                ),
              ),
            ),

            // Results View
            Expanded(
              child: music.isSearching
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _searchController.text.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                PhosphorIconsRegular.magnifyingGlass,
                                color: AppColors.textMuted,
                                size: 54,
                              ),
                              const SizedBox(height: 12),
                              Text('Play what you love', style: AppTypography.titleLarge),
                              const SizedBox(height: 4),
                              Text('Search for artists, songs, or albums', style: AppTypography.bodySmall),
                            ],
                          ),
                        )
                      : CustomScrollView(
                          physics: const BouncingScrollPhysics(),
                          slivers: [
                            // Songs Section
                            if (music.searchTracks.isNotEmpty) ...[
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                                  child: Text('Songs', style: AppTypography.titleLarge),
                                ),
                              ),
                              SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (ctx, i) {
                                    final track = music.searchTracks[i];
                                    return TrackRow(
                                      track: track,
                                      onTap: () => player.playTracks(
                                        tracks: music.searchTracks,
                                        initialIndex: i,
                                      ),
                                    );
                                  },
                                  childCount: music.searchTracks.length,
                                ),
                              ),
                            ],

                            // Albums Section
                            if (music.searchAlbums.isNotEmpty) ...[
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                                  child: Text('Albums', style: AppTypography.titleLarge),
                                ),
                              ),
                              SliverToBoxAdapter(
                                child: SizedBox(
                                  height: 190,
                                  child: ListView.separated(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    scrollDirection: Axis.horizontal,
                                    itemCount: music.searchAlbums.length,
                                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                                    itemBuilder: (ctx, i) {
                                      final album = music.searchAlbums[i];
                                      return AlbumCard(
                                        album: album,
                                        coverUrl: music.getCoverArtUrl(album.coverArtId, size: 250),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => AlbumDetailScreen(albumId: album.id),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                            const SliverToBoxAdapter(child: SizedBox(height: 100)),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
