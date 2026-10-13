import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../state/audio_player_provider.dart';
import '../../state/music_provider.dart';

class FloatingSyncBanner extends StatelessWidget {
  final double bottomOffset;

  const FloatingSyncBanner({
    super.key,
    this.bottomOffset = 16,
  });

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final player = context.watch<AudioPlayerProvider>();

    final item = music.activeSyncingItem;
    if (item == null) return const SizedBox.shrink();

    final syncState = music.getSpotifySyncState(item.id);
    final progress = music.getSpotifySyncProgress(item.id);
    final message = music.getSpotifySyncMessage(item.id) ?? 'Syncing...';

    return Positioned(
      left: 16,
      right: 16,
      bottom: bottomOffset,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: const Color(0xFF1E222A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: syncState == SpotifySyncState.error
                ? Colors.redAccent.withValues(alpha: 0.6)
                : AppColors.primary.withValues(alpha: 0.5),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: item.coverUrl != null && item.coverUrl!.isNotEmpty
                          ? Image.network(
                              item.coverUrl!,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 40,
                                height: 40,
                                color: AppColors.card,
                                child: const Icon(Icons.music_note_rounded, color: AppColors.primary, size: 20),
                              ),
                            )
                          : Container(
                              width: 40,
                              height: 40,
                              color: AppColors.card,
                              child: const Icon(Icons.music_note_rounded, color: AppColors.primary, size: 20),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.titleMedium.copyWith(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            message,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySmall.copyWith(
                              color: syncState == SpotifySyncState.error ? Colors.redAccent : AppColors.primary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (syncState == SpotifySyncState.syncing)
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          value: progress > 0 ? progress : null,
                          strokeWidth: 2.2,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                          backgroundColor: progress > 0 ? AppColors.primary.withValues(alpha: 0.2) : null,
                        ),
                      )
                    else if (syncState == SpotifySyncState.error)
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: Colors.redAccent, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () async {
                          if (music.getSpotifySyncState(item.id) == SpotifySyncState.syncing) return;
                          HapticFeedback.mediumImpact();
                          final track = await music.convertAndSyncSpotifyTrack(item);
                          if (track != null) {
                            player.playTrack(track);
                          }
                        },
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => music.dismissActiveSyncBanner(),
                      ),
                  ],
                ),
              ),
              if (syncState == SpotifySyncState.syncing)
                LinearProgressIndicator(
                  value: progress > 0 ? progress : null,
                  minHeight: 2.5,
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
