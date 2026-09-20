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
      '$cleanArtist - $cleanTitle',
    ];

    for (final q in queries) {
      try {
        final searchResults = await _yt.search.search(q).timeout(const Duration(seconds: 5));
        for (final video in searchResults.take(6)) {
          if (_isValidMatch(video, cleanTitle, cleanArtist, expectedDurationSec)) {
            final manifest = await _yt.videos.streams.getManifest(video.id).timeout(const Duration(seconds: 4));
            final audioStream = manifest.audioOnly.withHighestBitrate();
            final streamUrl = audioStream.url.toString();
            if (streamUrl.isNotEmpty) {
              _memoryCache[key] = streamUrl;
              return streamUrl;
            }
          }
        }
      } catch (_) {}
    }

    // 2. Fallback: Piped API music search
    try {
      final pipedInstances = [
        'https://pipedapi.kavin.rocks',
        'https://api.piped.private.coffee',
        'https://piped-api.lunar.icu',
      ];

      for (final instance in pipedInstances) {
        try {
          final resp = await _dio.get(
            '$instance/search',
            queryParameters: {
              'q': '$cleanArtist $cleanTitle',
              'filter': 'music_songs',
            },
            options: Options(
              receiveTimeout: const Duration(seconds: 4),
              sendTimeout: const Duration(seconds: 3),
            ),
          );

          final items = resp.data['items'] as List? ?? [];
          for (final item in items.take(4)) {
            final durationSec = (item['duration'] as num?)?.toInt() ?? 0;
            if (expectedDurationSec != null && expectedDurationSec > 0 && durationSec > 0) {
              if ((durationSec - expectedDurationSec).abs() > 15) continue;
            }

            final videoUrl = item['url']?.toString() ?? '';
            final videoId = videoUrl.replaceAll('/watch?v=', '').trim();
            if (videoId.isNotEmpty) {
              final streamResp = await _dio.get(
                '$instance/streams/$videoId',
                options: Options(
                  receiveTimeout: const Duration(seconds: 4),
                  sendTimeout: const Duration(seconds: 3),
                ),
              );
              final audioStreams = streamResp.data['audioStreams'] as List? ?? [];
              if (audioStreams.isNotEmpty) {
                // Pick highest quality stream
                audioStreams.sort((a, b) => ((b['bitrate'] as num?) ?? 0).compareTo((a['bitrate'] as num?) ?? 0));
                final url = audioStreams.first['url']?.toString();
                if (url != null && url.isNotEmpty) {
                  _memoryCache[key] = url;
                  return url;
                }
              }
            }
          }
        } catch (_) {}
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

    // Check duration match within ±14 seconds
    if (expectedDurationSec != null && expectedDurationSec > 20 && vDuration > 0) {
      final diff = (vDuration - expectedDurationSec).abs();
      if (diff > 14) {
        return false;
      }
    }

    final targetTitleLower = targetTitle.toLowerCase();
    final hasRemixTarget = targetTitleLower.contains('remix');
    final hasCoverTarget = targetTitleLower.contains('cover');
    final hasLiveTarget = targetTitleLower.contains('live');

    // Forbidden keywords if target doesn't ask for them
    if (!hasRemixTarget && (vTitle.contains('remix') || vTitle.contains('slowed') || vTitle.contains('speed up'))) {
      return false;
    }
    if (!hasCoverTarget && (vTitle.contains('cover') || vTitle.contains('karaoke') || vTitle.contains('tutorial') || vTitle.contains('parody'))) {
      return false;
    }
    if (!hasLiveTarget && (vTitle.contains('live at') || vTitle.contains('live in') || vTitle.contains('reaction'))) {
      return false;
    }
    if (vTitle.contains('1 hour') || vTitle.contains('10 hour') || vTitle.contains('loop')) {
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
