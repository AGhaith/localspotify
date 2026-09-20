import 'dart:async';
import 'package:dio/dio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class AudioStreamResolverService {
  final YoutubeExplode _yt;
  final Dio _dio;
  final Map<String, String> _memoryCache = {};

  AudioStreamResolverService({YoutubeExplode? yt, Dio? dio})
      : _yt = yt ?? YoutubeExplode(),
        _dio = dio ?? Dio();

  String _buildCacheKey(String title, String artist) {
    return '${artist.trim().toLowerCase()}:::${title.trim().toLowerCase()}';
  }

  /// Resolves full-length studio audio stream URL with strict duration & title verification
  Future<String?> resolveFullAudioStream({
    required String title,
    required String artist,
    int? expectedDurationSec,
  }) async {
    final key = _buildCacheKey(title, artist);
    if (_memoryCache.containsKey(key)) {
      return _memoryCache[key];
    }

    final cleanTitle = _cleanName(title);
    final cleanArtist = _cleanName(artist);

    // 1. Try YouTube Explode search with multiple high-confidence queries
    final queries = [
      '$cleanArtist - $cleanTitle Official Audio',
      '$cleanArtist $cleanTitle Topic',
      '$cleanArtist $cleanTitle',
    ];

    for (final q in queries) {
      try {
        final searchResults = await _yt.search.search(q).timeout(const Duration(milliseconds: 3500));
        for (final video in searchResults.take(6)) {
          if (_isValidMatch(video, cleanTitle, cleanArtist, expectedDurationSec)) {
            try {
              final manifest = await _yt.videos.streams.getManifest(video.id).timeout(const Duration(milliseconds: 3000));
              final audioStream = manifest.audioOnly.withHighestBitrate();
              final streamUrl = audioStream.url.toString();
              if (streamUrl.isNotEmpty) {
                _memoryCache[key] = streamUrl;
                return streamUrl;
              }
            } catch (_) {}
          }
        }
      } catch (_) {}
    }

    // 2. Fallback: Fast Invidious / Piped API audio search
    final publicInstances = [
      'https://yewtu.be/api/v1',
      'https://invidious.projectsegfau.lt/api/v1',
      'https://invidious.drgns.space/api/v1',
      'https://vid.priv.au/api/v1',
      'https://invidious.privacydev.net/api/v1',
    ];

    for (final instance in publicInstances) {
      try {
        final resp = await _dio.get(
          '$instance/search',
          queryParameters: {
            'q': '$cleanArtist $cleanTitle',
            'type': 'video',
          },
          options: Options(
            receiveTimeout: const Duration(milliseconds: 2500),
            sendTimeout: const Duration(milliseconds: 2000),
          ),
        );

        final items = resp.data is List ? resp.data as List : (resp.data['items'] as List? ?? []);
        for (final item in items.take(4)) {
          final durationSec = (item['lengthSeconds'] as num?)?.toInt() ?? (item['duration'] as num?)?.toInt() ?? 0;
          if (expectedDurationSec != null && expectedDurationSec > 20 && durationSec > 0) {
            if ((durationSec - expectedDurationSec).abs() > 35) continue;
          }

          final videoId = (item['videoId'] ?? item['url']?.toString().replaceAll('/watch?v=', ''))?.toString().trim() ?? '';
          if (videoId.isNotEmpty) {
            try {
              final manifest = await _yt.videos.streams.getManifest(videoId).timeout(const Duration(milliseconds: 3000));
              final audioStream = manifest.audioOnly.withHighestBitrate();
              final streamUrl = audioStream.url.toString();
              if (streamUrl.isNotEmpty) {
                _memoryCache[key] = streamUrl;
                return streamUrl;
              }
            } catch (_) {}
          }
        }
      } catch (_) {}
    }

    // 3. Last-ditch YouTube Explode unconstrained search
    try {
      final searchResults = await _yt.search.search('$cleanArtist $cleanTitle').timeout(const Duration(milliseconds: 3000));
      if (searchResults.isNotEmpty) {
        final first = searchResults.first;
        final manifest = await _yt.videos.streams.getManifest(first.id).timeout(const Duration(milliseconds: 3000));
        final audioStream = manifest.audioOnly.withHighestBitrate();
        final url = audioStream.url.toString();
        if (url.isNotEmpty) {
          _memoryCache[key] = url;
          return url;
        }
      }
    } catch (_) {}

    return null;
  }

  bool _isValidMatch(
    Video video,
    String targetTitle,
    String targetArtist,
    int? expectedDurationSec,
  ) {
    final vTitle = video.title.toLowerCase();
    final vDuration = video.duration?.inSeconds ?? 0;

    // Check duration match within ±32 seconds (music video intro/outro buffer)
    if (expectedDurationSec != null && expectedDurationSec > 20 && vDuration > 0) {
      final diff = (vDuration - expectedDurationSec).abs();
      if (diff > 32) {
        return false;
      }
    }

    final targetTitleLower = targetTitle.toLowerCase();
    final hasRemixTarget = targetTitleLower.contains('remix');
    final hasCoverTarget = targetTitleLower.contains('cover');
    final hasLiveTarget = targetTitleLower.contains('live');

    // Forbidden keywords if target doesn't ask for them
    if (!hasRemixTarget && (vTitle.contains('slowed') || vTitle.contains('speed up') || vTitle.contains('bass boosted') || vTitle.contains('nightcore'))) {
      return false;
    }
    if (!hasCoverTarget && (vTitle.contains('karaoke') || vTitle.contains('tutorial') || vTitle.contains('parody') || vTitle.contains('how to play'))) {
      return false;
    }
    if (!hasLiveTarget && (vTitle.contains('live at') || vTitle.contains('live in') || vTitle.contains('reaction'))) {
      return false;
    }
    if (vTitle.contains('1 hour') || vTitle.contains('10 hour') || vTitle.contains('loop') || vTitle.contains('full album')) {
      return false;
    }

    return true;
  }

  String _cleanName(String text) {
    return text
        .replaceAll(RegExp(r'\.[a-zA-Z0-9]{3,4}$'), '')
        .replaceAll(RegExp(r'\s*[\(\[](?:feat|ft|with|prod)\.?\s+[^\)\]]+[\)\]]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*[\(\[](?:official\s+(?:audio|video|music\s+video)|remastered(?:\s+\d+)?|bonus\s+track|deluxe\s+edition)[\)\]]', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\/\\:*?"<>|]', caseSensitive: false), ' ')
        .trim();
  }

  void close() {
    _yt.close();
  }
}
