import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/theme/app_colors.dart';

class CachedCoverArt extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final double borderRadius;
  final IconData placeholderIcon;

  const CachedCoverArt({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.placeholderIcon = PhosphorIconsRegular.musicNote,
  });

  @override
  Widget build(BuildContext context) {
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
          size: (width != null ? width! * 0.4 : 24).clamp(16.0, 48.0),
        ),
      ),
    );
  }
}
