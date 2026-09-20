import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/album.dart';
import 'cached_cover_art.dart';
import 'pressable_scale.dart';

class AlbumCard extends StatelessWidget {
  final Album album;
  final String coverUrl;
  final VoidCallback onTap;
  final VoidCallback? onPlayTap;

  const AlbumCard({
    super.key,
    required this.album,
    required this.coverUrl,
    required this.onTap,
    this.onPlayTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      scaleFactor: 0.96,
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              offset: const Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                AspectRatio(
                  aspectRatio: 1.0,
                  child: CachedCoverArt(
                    imageUrl: coverUrl,
                    borderRadius: 8,
                  ),
                ),
                if (onPlayTap != null)
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: PressableScale(
                      onTap: () {
                        HapticFeedback.heavyImpact();
                        onPlayTap!();
                      },
                      scaleFactor: 0.88,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.play_arrow_rounded,
                            color: AppColors.textDark,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              album.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.titleMedium.copyWith(fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              album.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
