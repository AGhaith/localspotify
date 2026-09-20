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

  /// Resolves full-length studio audio stream URL with ultra-fast parallel search & ranking
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

    // 1. Fast Concurrent YouTube Search with ranking & parallel manifest fetch
    try {
      final primaryQuery = '$cleanArtist $cleanTitle Official Audio';
      final secondaryQuery = '$cleanArtist $cleanTitle';

      // Launch both searches in parallel with a short deadline
      final results = await Future.wait([
        _safeSearch(primaryQuery),
        _safeSearch(secondaryQuery),
      ]);
      final allVideos = <Video>[];
      final seenIds = <String>{};

      for (final resultList in results) {
        for (final v in resultList) {
          if (seenIds.add(v.id.value)) {
            allVideos.add(v);
          }
        }
      }

      if (allVideos.isNotEmpty) {
        // Rank candidate videos in memory instantly (0 network cost)
        final scoredVideos = <MapEntry<Video, int>>[];
        for (final video in allVideos) {
          if (_isValidMatch(video, cleanTitle, cleanArtist, expectedDurationSec)) {
            final score = _calculateMatchScore(video, cleanTitle, cleanArtist, expectedDurationSec);
            scoredVideos.add(MapEntry(video, score));
          }
        }

        // Sort highest score first
        scoredVideos.sort((a, b) => b.value.compareTo(a.value));

        if (scoredVideos.isNotEmpty) {
          // Take top 2 candidates and fetch manifests concurrently
          final topCandidates = scoredVideos.take(2).map((e) => e.key).toList();
          final streamUrl = await _fetchFirstWorkingStream(topCandidates);
          if (streamUrl != null && streamUrl.isNotEmpty) {
            _memoryCache[key] = streamUrl;
            return streamUrl;
          }
        }
      }
    } catch (_) {}

    // 2. Fallback: Fast Parallel Invidious / Piped API audio search
    final publicInstances = [
      'https://yewtu.be/api/v1',
      'https://invidious.projectsegfau.lt/api/v1',
      'https://invidious.drgns.space/api/v1',
      'https://vid.priv.au/api/v1',
    ];

    try {
      final invidiousUrl = await _raceInvidiousInstances(
        instances: publicInstances,
        cleanArtist: cleanArtist,
        cleanTitle: cleanTitle,
        expectedDurationSec: expectedDurationSec,
      );
      if (invidiousUrl != null && invidiousUrl.isNotEmpty) {
        _memoryCache[key] = invidiousUrl;
        return invidiousUrl;
      }
    } catch (_) {}

    return null;
  }

  Future<String?> _fetchFirstWorkingStream(List<Video> videos) async {
    final completer = Completer<String?>();
    int pending = videos.length;

    if (videos.isEmpty) return null;

    for (final video in videos) {
      _yt.videos.streams.getManifest(video.id).timeout(const Duration(milliseconds: 2500)).then((manifest) {
        final audioStream = manifest.audioOnly.withHighestBitrate();
        final url = audioStream.url.toString();
        if (url.isNotEmpty && !completer.isCompleted) {
          completer.complete(url);
        }
      }).catchError((_) {
        // ignore failure
      }).whenComplete(() {
        pending--;
        if (pending == 0 && !completer.isCompleted) {
          completer.complete(null);
        }
      });
    }

    return completer.future.timeout(const Duration(milliseconds: 2800), onTimeout: () => null);
  }

  Future<String?> _raceInvidiousInstances({
    required List<String> instances,
    required String cleanArtist,
    required String cleanTitle,
    int? expectedDurationSec,
  }) async {
    final completer = Completer<String?>();
    int pending = instances.length;

    for (final instance in instances) {
      _dio.get(
        '$instance/search',
        queryParameters: {
          'q': '$cleanArtist $cleanTitle',
          'type': 'video',
        },
        options: Options(
          receiveTimeout: const Duration(milliseconds: 2200),
          sendTimeout: const Duration(milliseconds: 1800),
        ),
      ).then((resp) async {
        if (completer.isCompleted) return;
        final items = resp.data is List ? resp.data as List : (resp.data['items'] as List? ?? []);
        for (final item in items.take(2)) {
          final durationSec = (item['lengthSeconds'] as num?)?.toInt() ?? (item['duration'] as num?)?.toInt() ?? 0;
          if (expectedDurationSec != null && expectedDurationSec > 20 && durationSec > 0) {
            if ((durationSec - expectedDurationSec).abs() > 30) continue;
          }

          final videoId = (item['videoId'] ?? item['url']?.toString().replaceAll('/watch?v=', ''))?.toString().trim() ?? '';
          if (videoId.isNotEmpty) {
            final manifest = await _yt.videos.streams.getManifest(videoId).timeout(const Duration(milliseconds: 2000));
            final audioStream = manifest.audioOnly.withHighestBitrate();
            final streamUrl = audioStream.url.toString();
            if (streamUrl.isNotEmpty && !completer.isCompleted) {
              completer.complete(streamUrl);
              return;
            }
          }
        }
      }).catchError((_) {
        // ignore
      }).whenComplete(() {
        pending--;
        if (pending == 0 && !completer.isCompleted) {
          completer.complete(null);
        }
      });
    }

    return completer.future.timeout(const Duration(milliseconds: 2500), onTimeout: () => null);
  }

  int _calculateMatchScore(Video video, String targetTitle, String targetArtist, int? expectedDurationSec) {
    int score = 0;
    final vTitle = video.title.toLowerCase();
    final vAuthor = video.author.toLowerCase();
    final targetTitleLower = targetTitle.toLowerCase();
    final targetArtistLower = targetArtist.toLowerCase();

    // Channel authorship bonuses
    if (vAuthor.contains('- topic') || vAuthor.contains('topic')) score += 80;
    if (vAuthor.contains(targetArtistLower)) score += 50;

    // Title match bonuses
    if (vTitle.contains('official audio')) score += 50;
    if (vTitle.contains('official track') || vTitle.contains('audio')) score += 30;
    if (vTitle.contains(targetTitleLower)) score += 40;

    // Duration accuracy bonuses
    if (expectedDurationSec != null && expectedDurationSec > 0) {
      final vDur = video.duration?.inSeconds ?? 0;
      final diff = (vDur - expectedDurationSec).abs();
      if (diff <= 5) {
        score += 60;
      } else if (diff <= 12) {
        score += 30;
      } else if (diff > 25) {
        score -= 40;
      }
    }

    return score;
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

  Future<List<Video>> _safeSearch(String query) async {
    try {
      final searchResults = await _yt.search.search(query).timeout(const Duration(milliseconds: 2200));
      return searchResults.take(6).toList();
    } catch (_) {
      return <Video>[];
    }
  }

  void close() {
    _yt.close();
  }
}
