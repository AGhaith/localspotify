import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/track.dart';
import '../../../state/audio_player_provider.dart';
import '../../../state/music_provider.dart';
import '../../core_widgets/neo_button.dart';
import '../../core_widgets/track_row.dart';

class LikedSongsScreen extends StatefulWidget {
  const LikedSongsScreen({super.key});

  @override
  State<LikedSongsScreen> createState() => _LikedSongsScreenState();
}

class _LikedSongsScreenState extends State<LikedSongsScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final player = context.read<AudioPlayerProvider>();

    final tracks = _searchQuery.isEmpty
        ? music.starredTracks
        : music.starredTracks
            .where((t) =>
                t.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                t.artist.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Collapsible Header with Gradient
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: AppColors.card,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Liked Songs',
                style: AppTypography.titleLarge.copyWith(color: Colors.white),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF450AF5),
                      Color(0xFF1E085A),
                      AppColors.background,
                    ],
                  ),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Actions & Search Filter Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${tracks.length} songs',
                          style: AppTypography.bodySmall,
                        ),
                      ),
                      if (tracks.isNotEmpty)
                        NeoButton(
                          text: 'Play All',
                          icon: Icons.play_arrow_rounded,
                          onPressed: () {
                            HapticFeedback.heavyImpact();
                            player.playTracks(tracks: tracks, initialIndex: 0);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // In-list search field
                  TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: AppTypography.bodyLarge,
                    decoration: InputDecoration(
                      hintText: 'Search in liked songs...',
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                              onPressed: () => setState(() => _searchQuery = ''),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Tracklist
          if (tracks.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  _searchQuery.isEmpty ? 'No liked songs yet' : 'No matching songs found',
                  style: AppTypography.bodyMedium,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final track = tracks[i];
                    return TrackRow(
                      track: track,
                      index: i + 1,
                      onTap: () {
                        player.playTracks(tracks: tracks, initialIndex: i);
                      },
                    );
                  },
                  childCount: tracks.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
