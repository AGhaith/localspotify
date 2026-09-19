import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../state/audio_player_provider.dart';
import '../../../state/music_provider.dart';
import '../../core_widgets/cached_cover_art.dart';

class QueueSheet extends StatelessWidget {
  const QueueSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<AudioPlayerProvider>();
    final music = context.watch<MusicProvider>();
    final queue = player.queue;
    final currentIndex = player.currentIndex;
    final currentTrack = player.currentTrack;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF0C0D14),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Drag Handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 6),
              child: Center(
                child: Container(
                  width: 42,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),

            // Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Play Queue', style: AppTypography.titleLarge),
                  if (queue.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        player.clearQueue();
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Clear Queue',
                        style: AppTypography.labelMedium.copyWith(color: AppColors.error),
                      ),
                    ),
                ],
              ),
            ),

            const Divider(color: AppColors.border, height: 1),

            Expanded(
              child: queue.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.queue_music_rounded, color: AppColors.textMuted, size: 48),
                          const SizedBox(height: 12),
                          Text('Queue is empty', style: AppTypography.titleMedium),
                          const SizedBox(height: 4),
                          Text('Play a song or album to start listening', style: AppTypography.bodySmall),
                        ],
                      ),
                    )
                  : CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        // Now Playing Section
                        if (currentTrack != null) ...[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              child: Text(
                                'NOW PLAYING',
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.primary,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.surface.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.primary, width: 1.5),
                              ),
                              child: Row(
                                children: [
                                  CachedCoverArt(
                                    imageUrl: music.getCoverArtUrl(currentTrack.coverArtId, size: 120),
                                    localImagePath: currentTrack.localCoverArtPath,
                                    width: 46,
                                    height: 46,
                                    borderRadius: 6,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          currentTrack.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.titleMedium.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          currentTrack.artist,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.graphic_eq_rounded, color: AppColors.primary, size: 22),
                                ],
                              ),
                            ),
                          ),
                        ],

                        // Up Next Section Header
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'UP NEXT (${queue.length} TRACKS)',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.textMuted,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                Text(
                                  'Hold & drag to reorder',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.textMuted,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Reorderable Queue List
                        SliverReorderableList(
                          itemCount: queue.length,
                          onReorderItem: (oldIndex, newIndex) {
                            HapticFeedback.selectionClick();
                            player.reorderQueue(oldIndex, newIndex);
                          },
                          itemBuilder: (ctx, i) {
                            final track = queue[i];
                            final isCurrent = i == currentIndex;

                            return ReorderableDelayedDragStartListener(
                              key: ValueKey('queue_${track.id}_$i'),
                              index: i,
                              child: Container(
                                color: isCurrent
                                    ? AppColors.primary.withValues(alpha: 0.1)
                                    : Colors.transparent,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Row(
                                  children: [
                                    ReorderableDragStartListener(
                                      index: i,
                                      child: const Padding(
                                        padding: EdgeInsets.only(right: 12),
                                        child: Icon(Icons.drag_handle_rounded, color: AppColors.textMuted, size: 20),
                                      ),
                                    ),
                                    CachedCoverArt(
                                      imageUrl: music.getCoverArtUrl(track.coverArtId, size: 100),
                                      localImagePath: track.localCoverArtPath,
                                      width: 40,
                                      height: 40,
                                      borderRadius: 6,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          HapticFeedback.lightImpact();
                                          player.skipToQueueItem(i);
                                        },
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              track.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTypography.titleMedium.copyWith(
                                                color: isCurrent ? AppColors.primary : AppColors.textPrimary,
                                                fontSize: 14,
                                                fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              track.artist,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTypography.bodySmall.copyWith(fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 18),
                                      onPressed: () {
                                        HapticFeedback.lightImpact();
                                        player.removeFromQueue(i);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 40)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
