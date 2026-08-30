import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../state/audio_player_provider.dart';
import '../../../state/music_provider.dart';
import '../../core_widgets/neo_button.dart';
import '../../core_widgets/track_row.dart';

class OfflineScreen extends StatelessWidget {
  const OfflineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final player = context.read<AudioPlayerProvider>();
    final offlineTracks = music.offlineTracks;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Downloaded Music', style: AppTypography.titleLarge),
        leading: const BackButton(),
      ),
      body: offlineTracks.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      PhosphorIconsRegular.arrowCircleDown,
                      color: AppColors.textMuted,
                      size: 56,
                    ),
                    const SizedBox(height: 16),
                    Text('No downloaded songs', style: AppTypography.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                      'Tap the three dots on any track to download it for offline listening.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
              ),
            )
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${offlineTracks.length} tracks available offline',
                          style: AppTypography.bodySmall,
                        ),
                        NeoButton(
                          text: 'Play All',
                          icon: PhosphorIconsFill.play,
                          onPressed: () {
                            HapticFeedback.heavyImpact();
                            player.playTracks(tracks: offlineTracks, initialIndex: 0);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final track = offlineTracks[i];
                        return TrackRow(
                          track: track,
                          index: i + 1,
                          onTap: () {
                            player.playTracks(tracks: offlineTracks, initialIndex: i);
                          },
                        );
                      },
                      childCount: offlineTracks.length,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
