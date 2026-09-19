import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';

class DownloadActionButton extends StatelessWidget {
  final bool isDownloaded;
  final bool isDownloading;
  final double progress;
  final VoidCallback onDownload;
  final VoidCallback? onRemove;
  final double size;

  const DownloadActionButton({
    super.key,
    required this.isDownloaded,
    required this.isDownloading,
    this.progress = 0.0,
    required this.onDownload,
    this.onRemove,
    this.size = 36.0,
  });

  @override
  Widget build(BuildContext context) {
    if (isDownloading) {
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size - 8,
              height: size - 8,
              child: CircularProgressIndicator(
                value: progress > 0 ? progress : null,
                strokeWidth: 2.2,
                color: AppColors.primary,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              ),
            ),
            const Icon(
              Icons.arrow_downward_rounded,
              color: AppColors.primary,
              size: 16,
            ),
          ],
        ),
      );
    }

    if (isDownloaded) {
      return GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onRemove?.call();
        },
        child: SizedBox(
          width: size,
          height: size,
          child: const Center(
            child: Icon(
              Icons.arrow_circle_down_rounded,
              color: AppColors.primary,
              size: 26,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onDownload();
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.5), width: 1.5),
        ),
        child: const Center(
          child: Icon(
            Icons.arrow_downward_rounded,
            color: AppColors.textSecondary,
            size: 17,
          ),
        ),
      ),
    );
  }
}
