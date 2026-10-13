import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/track.dart';
import '../../../state/audio_player_provider.dart';
import '../../../state/music_provider.dart';
import '../../core_widgets/cached_cover_art.dart';

/// A Spotify-grade queue sheet featuring:
/// 1. "Now Playing" section (highlighted current track row with equalizer indicator)
/// 2. "Next in queue" section (user-queued tracks)
/// 3. "Next from: `album/playlist`" section (upcoming playlist/album tracks)
/// - Reorderable rows with drag handle icon on the right
/// - Swipe-to-remove dismissible actions
/// - Consistent row height & spacing matching TrackRow
/// - Clear empty state
class QueueSheet extends StatelessWidget {
  const QueueSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<AudioPlayerProvider>();
    final music = context.watch<MusicProvider>();
    final queue = player.queue;
    final currentIndex = player.currentIndex;
    final currentTrack = player.currentTrack;

    final hasCurrentTrack = currentTrack != null;
    final isQueueEmpty = queue.isEmpty && !hasCurrentTrack;

    final upcomingCount = (hasCurrentTrack && currentIndex >= 0)
        ? max(0, queue.length - (currentIndex + 1))
        : 0;

    final userQueuedCount =
        player.userQueuedCount.clamp(0, upcomingCount);
    final fromSourceCount = upcomingCount - userQueuedCount;

    final sourceTitle = (player.queueSource != null &&
            player.queueSource!.isNotEmpty)
        ? player.queueSource!
        : (currentTrack?.album.isNotEmpty == true
            ? currentTrack!.album
            : 'Library');

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: AppColors.card,
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
                  width: 40,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),

            // Top Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenH,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Queue', style: AppTypography.titleLarge),
                  if (userQueuedCount > 0)
                    TextButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        player.clearUserQueue();
                      },
                      child: Text(
                        'Clear',
                        style: AppTypography.labelMedium
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    )
                  else if (queue.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        player.clearQueue();
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Clear',
                        style: AppTypography.labelMedium
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                ],
              ),
            ),

            const Divider(color: AppColors.border, height: 1),

            // Queue Content / Empty State
            Expanded(
              child: isQueueEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.queue_music_rounded,
                            color: AppColors.textMuted,
                            size: 52,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Your queue is empty',
                            style: AppTypography.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Play a song or swipe right on a track to queue it',
                            style: AppTypography.bodySmall
                                .copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    )
                  : CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        // ================= 1. NOW PLAYING SECTION =================
                        if (currentTrack != null) ...[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.screenH,
                                AppSpacing.lg,
                                AppSpacing.screenH,
                                AppSpacing.sm,
                              ),
                              child: Text(
                                'NOW PLAYING',
                                style: AppTypography.labelSmall.copyWith(
                                  color: Colors.white70,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.screenH,
                                vertical: AppSpacing.xs,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surface.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  CachedCoverArt(
                                    imageUrl: music.getCoverArtUrl(
                                      currentTrack.coverArtId,
                                      albumName: currentTrack.album,
                                      size: 150,
                                    ),
                                    localImagePath: currentTrack.localCoverArtPath,
                                    width: 48,
                                    height: 48,
                                    borderRadius: AppRadius.coverSmall,
                                  ),
                                  const SizedBox(width: AppSpacing.rowGap),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          currentTrack.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.titleMedium
                                              .copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14.5,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          currentTrack.artist,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.bodySmall
                                              .copyWith(
                                            color: AppColors.textMuted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4),
                                    child: Icon(
                                      Icons.graphic_eq_rounded,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],

                        // ================= 2. NEXT IN QUEUE (USER-QUEUED) =================
                        if (userQueuedCount > 0) ...[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.screenH,
                                AppSpacing.xl,
                                AppSpacing.screenH,
                                AppSpacing.sm,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'NEXT IN QUEUE',
                                    style: AppTypography.labelSmall.copyWith(
                                      color: Colors.white70,
                                      letterSpacing: 1.2,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      player.clearUserQueue();
                                    },
                                    child: Text(
                                      'Clear',
                                      style: AppTypography.labelSmall.copyWith(
                                        color: AppColors.error,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SliverReorderableList(
                            itemCount: userQueuedCount,
                            onReorderItem: (oldRel, newRel) {
                              HapticFeedback.selectionClick();
                              final base = currentIndex + 1;
                              player.reorderQueue(
                                  base + oldRel, base + newRel);
                            },
                            itemBuilder: (ctx, i) {
                              final absIndex = currentIndex + 1 + i;
                              final track = queue[absIndex];

                              return _QueueTrackRow(
                                key: ValueKey('user_queue_${track.id}_$absIndex'),
                                track: track,
                                index: i,
                                absoluteIndex: absIndex,
                                music: music,
                                onPlay: () {
                                  HapticFeedback.lightImpact();
                                  player.skipToQueueItem(absIndex);
                                },
                                onRemove: () {
                                  HapticFeedback.lightImpact();
                                  player.removeFromQueue(absIndex);
                                },
                              );
                            },
                          ),
                        ],

                        // ================= 3. NEXT FROM: <SOURCE> =================
                        if (fromSourceCount > 0) ...[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.screenH,
                                AppSpacing.xl,
                                AppSpacing.screenH,
                                AppSpacing.sm,
                              ),
                              child: Text(
                                'NEXT FROM: ${sourceTitle.toUpperCase()}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.labelSmall.copyWith(
                                  color: Colors.white70,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                          SliverReorderableList(
                            itemCount: fromSourceCount,
                            onReorderItem: (oldRel, newRel) {
                              HapticFeedback.selectionClick();
                              final base =
                                  currentIndex + 1 + userQueuedCount;
                              player.reorderQueue(
                                  base + oldRel, base + newRel);
                            },
                            itemBuilder: (ctx, j) {
                              final absIndex =
                                  currentIndex + 1 + userQueuedCount + j;
                              final track = queue[absIndex];

                              return _QueueTrackRow(
                                key: ValueKey('source_queue_${track.id}_$absIndex'),
                                track: track,
                                index: j,
                                absoluteIndex: absIndex,
                                music: music,
                                onPlay: () {
                                  HapticFeedback.lightImpact();
                                  player.skipToQueueItem(absIndex);
                                },
                                onRemove: () {
                                  HapticFeedback.lightImpact();
                                  player.removeFromQueue(absIndex);
                                },
                              );
                            },
                          ),
                        ],

                        if (upcomingCount == 0 && hasCurrentTrack)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.screenH,
                                vertical: AppSpacing.xxl,
                              ),
                              child: Center(
                                child: Text(
                                  'End of queue',
                                  style: AppTypography.bodySmall
                                      .copyWith(color: AppColors.textMuted),
                                ),
                              ),
                            ),
                          ),

                        const SliverToBoxAdapter(
                          child: SizedBox(height: 48),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A Spotify-styled reorderable queue row:
/// - Consistent height & padding matching TrackRow (EdgeInsets.symmetric(horizontal: 16, vertical: 8))
/// - Cover art (48x48)
/// - Title & Artist
/// - Drag handle icon on the right
/// - Swipe-to-remove dismissible affordance
class _QueueTrackRow extends StatelessWidget {
  final Track track;
  final int index;
  final int absoluteIndex;
  final MusicProvider music;
  final VoidCallback onPlay;
  final VoidCallback onRemove;

  const _QueueTrackRow({
    super.key,
    required this.track,
    required this.index,
    required this.absoluteIndex,
    required this.music,
    required this.onPlay,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('dismiss_${track.id}_$absoluteIndex'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.screenH),
        color: AppColors.error,
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPlay,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenH,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                // Cover Art
                CachedCoverArt(
                  imageUrl: music.getCoverArtUrl(
                    track.coverArtId,
                    albumName: track.album,
                    size: 150,
                  ),
                  localImagePath: track.localCoverArtPath,
                  width: 48,
                  height: 48,
                  borderRadius: AppRadius.coverSmall,
                ),
                const SizedBox(width: AppSpacing.rowGap),

                // Track Info (Title & Artist)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        track.artist,
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

                // Reorder drag handle on the right
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: AppSpacing.sm,
                    ),
                    child: Icon(
                      Icons.drag_handle_rounded,
                      color: AppColors.textMuted,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
