import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class CachedCoverArt extends StatelessWidget {
  final String? imageUrl;
  final String? localImagePath;
  final double? width;
  final double? height;
  final double borderRadius;
  final IconData placeholderIcon;

  const CachedCoverArt({
    super.key,
    required this.imageUrl,
    this.localImagePath,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.placeholderIcon = Icons.music_note_rounded,
  });

  @override
  Widget build(BuildContext context) {
    // 1. If local image path exists and file is valid, load from local disk (100% offline support)
    if (localImagePath != null && localImagePath!.isNotEmpty) {
      final file = File(localImagePath!);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Image.file(
            file,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildNetworkOrFallback(),
          ),
        );
      }
    }

    return _buildNetworkOrFallback();
  }

  Widget _buildNetworkOrFallback() {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildFallback();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: BoxFit.cover,
        maxWidthDiskCache: 600,
        maxHeightDiskCache: 600,
        memCacheWidth: width != null ? (width! * 2).toInt().clamp(64, 600) : 300,
        memCacheHeight: height != null ? (height! * 2).toInt().clamp(64, 600) : 300,
        placeholder: (context, url) => Container(
          width: width,
          height: height,
          color: AppColors.surface,
          child: const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) => _buildFallback(),
      ),
    );
  }

  Widget _buildFallback() {
    final computedSize = (width != null ? (width! * 0.4) : 24.0).clamp(16.0, 48.0);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Center(
        child: Icon(
          placeholderIcon,
          color: AppColors.textMuted,
          size: computedSize,
        ),
      ),
    );
  }
}
