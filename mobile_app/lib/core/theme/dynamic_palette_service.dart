import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'app_colors.dart';

class DynamicPaletteService {
  static final DynamicPaletteService _instance = DynamicPaletteService._internal();
  factory DynamicPaletteService() => _instance;
  DynamicPaletteService._internal();

  final Map<String, PaletteColors> _cache = {};

  Future<PaletteColors> extractColors({
    required String key,
    String? imageUrl,
    String? localImagePath,
  }) async {
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    try {
      ImageProvider? imageProvider;
      if (localImagePath != null && localImagePath.isNotEmpty && File(localImagePath).existsSync()) {
        imageProvider = FileImage(File(localImagePath));
      } else if (imageUrl != null && imageUrl.isNotEmpty) {
        imageProvider = CachedNetworkImageProvider(imageUrl);
      }

      if (imageProvider == null) {
        return _defaultColors;
      }

      final palette = await PaletteGenerator.fromImageProvider(
        imageProvider,
        size: const Size(64, 64), // Small size for fast generation <50ms
        maximumColorCount: 16,
      );

      final dominant = palette.dominantColor?.color ?? AppColors.primary;
      final darkMuted = palette.darkMutedColor?.color ?? palette.mutedColor?.color ?? const Color(0xFF1B1828);
      final darkVibrant = palette.darkVibrantColor?.color ?? palette.vibrantColor?.color ?? dominant;

      // Darken and tone colors for premium Spotify ambient glow
      final bgTop = HSLColor.fromColor(darkVibrant)
          .withLightness((HSLColor.fromColor(darkVibrant).lightness * 0.45).clamp(0.08, 0.22))
          .withSaturation((HSLColor.fromColor(darkVibrant).saturation * 0.85).clamp(0.3, 0.9))
          .toColor();

      final bgMid = HSLColor.fromColor(darkMuted)
          .withLightness((HSLColor.fromColor(darkMuted).lightness * 0.35).clamp(0.05, 0.14))
          .toColor();

      final result = PaletteColors(
        primaryAccent: dominant,
        ambientTop: bgTop,
        ambientMid: bgMid,
        ambientBottom: const Color(0xFF07070B),
      );

      _cache[key] = result;
      return result;
    } catch (_) {
      return _defaultColors;
    }
  }

  static const _defaultColors = PaletteColors(
    primaryAccent: AppColors.primary,
    ambientTop: Color(0xFF222226),
    ambientMid: Color(0xFF141418),
    ambientBottom: Color(0xFF0A0A0E),
  );
}

class PaletteColors {
  final Color primaryAccent;
  final Color ambientTop;
  final Color ambientMid;
  final Color ambientBottom;

  const PaletteColors({
    required this.primaryAccent,
    required this.ambientTop,
    required this.ambientMid,
    required this.ambientBottom,
  });

  LinearGradient toAmbientGradient() {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        ambientTop,
        ambientMid,
        ambientBottom,
      ],
      stops: const [0.0, 0.55, 1.0],
    );
  }

  LinearGradient toLyricsCardGradient() {
    final topColor = Color.alphaBlend(
      primaryAccent.withValues(alpha: 0.38),
      ambientTop,
    );
    final bottomColor = Color.alphaBlend(
      ambientMid.withValues(alpha: 0.85),
      const Color(0xFF0E0E12),
    );

    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        topColor,
        bottomColor,
      ],
      stops: const [0.0, 1.0],
    );
  }

  Color get lyricsBorderColor => primaryAccent.withValues(alpha: 0.35);
}
