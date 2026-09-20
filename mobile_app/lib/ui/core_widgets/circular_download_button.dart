import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/track.dart';
import '../../state/music_provider.dart';
import 'pressable_scale.dart';

/// A sleek Spotify-grade circular download button that displays a smooth circular
/// progress ring during downloading and transforms into a green checkmark when complete.
class CircularDownloadButton extends StatelessWidget {
  final Track track;
  final double size;
  final EdgeInsets padding;

  const CircularDownloadButton({
    super.key,
    required this.track,
    this.size = 24.0,
    this.padding = const EdgeInsets.all(8.0),
  });

  @override
  Widget build(BuildContext context) {
    final music = context.watch<MusicProvider>();
    final isDownloaded = music.isDownloaded(track.id);
    final isDownloading = music.downloadingEntityId == track.id;
    final progress = music.downloadingProgress;

    return PressableScale(
      onTap: () async {
        HapticFeedback.lightImpact();
        if (isDownloaded) {
          await music.deleteOfflineTrack(track.id);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Removed "${track.title}" from offline downloads'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppColors.surface,
              ),
            );
          }
        } else if (!isDownloading) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Downloading "${track.title}" for offline playback...'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.surface,
            ),
          );
          await music.downloadTrack(track);
        }
      },
      scaleFactor: 0.88,
      child: Padding(
        padding: padding,
        child: SizedBox(
          width: size,
          height: size,
          child: isDownloading
              ? Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress > 0.0 ? progress : null,
                      strokeWidth: 2.4,
                      color: AppColors.primary,
                      backgroundColor: AppColors.borderStrong,
                    ),
                    Icon(
                      Icons.arrow_downward_rounded,
                      size: size * 0.55,
                      color: AppColors.primary,
                    ),
                  ],
                )
              : Icon(
                  isDownloaded
                      ? Icons.check_circle_rounded
                      : Icons.arrow_circle_down_outlined,
                  size: size,
                  color: isDownloaded ? AppColors.primary : AppColors.textSecondary,
                ),
        ),
      ),
    );
  }
}
