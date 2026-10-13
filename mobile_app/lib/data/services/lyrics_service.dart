import 'package:dio/dio.dart';
import '../models/lyrics.dart';
import '../models/track.dart';
import 'offline_storage_service.dart';
import 'subsonic_api_service.dart';

class LyricsService {
  final Dio _dio;
  final SubsonicApiService _subsonicService;
  final OfflineStorageService _storageService;

  static const String _lrclibBaseUrl = 'https://lrclib.net/api';
  static const Map<String, String> _headers = {
    'User-Agent': 'LocalSpotify/1.0 (https://github.com/AGhaith/localspotify)',
  };

  LyricsService({
    required SubsonicApiService subsonicService,
    required OfflineStorageService storageService,
    Dio? dio,
  })  : _subsonicService = subsonicService,
        _storageService = storageService,
        _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 4),
                receiveTimeout: const Duration(seconds: 4),
                headers: _headers,
              ),
            );

  /// Clean track title by removing extraneous tags like (feat. X), [Remastered], .mp3, etc.
  static String cleanTrackTitle(String title) {
    return title
        .replaceAll(RegExp(r'\.[a-zA-Z0-9]{3,4}$'), '') // strip extensions
        .replaceAll(RegExp(r'\s*[\(\[](?:feat|ft|featuring|with|prod)\b\.?[^\)\]]*[\)\]]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*[\(\[]official\b[^\)\]]*[\)\]]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*[\(\[](?:(?:\d{4}\s+)?remaster(?:ed)?|radio\s+edit|remix|bonus\s+track|deluxe\s+edition)\b[^\)\]]*[\)\]]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*[-–—]\s*(?:(?:\d{4}\s+)?remaster(?:ed)?|radio\s+edit|single\s+version|live)\b.*$', caseSensitive: false), '')
        .trim();
  }

  /// Clean artist name by extracting primary artist and removing feature tags
  static String cleanArtistName(String artist) {
    if (artist.isEmpty) return '';
    final primary = artist.split(RegExp(r'[,;/]|(?:\s+feat\.?\s+)|(?:\s+ft\.?\s+)|(?:\s+with\s+)', caseSensitive: false)).first.trim();
    return primary.replaceAll(RegExp(r'\s*[\(\[](?:feat|ft|with)\.?\s+[^\)\]]+[\)\]]', caseSensitive: false), '').trim();
  }

  /// Fetch lyrics for a track with a robust fallback chain:
  /// 1. Local offline cached lyrics
  /// 2. Server/Subsonic lyrics (getLyricsBySongId - local .lrc files) for real library tracks
  /// 3. Companion GET /api/lyrics (port 6969)
  /// 4. LRCLIB Direct GET then /search (with cleaned title and primary artist retry)
  Future<Lyrics?> getLyrics(Track track) async {
    final trackId = track.id;

    // 1. Check local offline storage cache
    final cached = _storageService.getCachedLyrics(trackId, artist: track.artist, title: track.title);
    if (cached != null) {
      return cached;
    }

    final rawArtist = track.artist;
    final rawTitle = track.title;
    final durationSec = track.duration;

    // (a) Server/Subsonic lyrics (getLyricsBySongId - local .lrc files) for real library tracks (non spotify_ ids)
    if (!trackId.startsWith('spotify_')) {
      try {
        final subsonicLyrics = await _subsonicService.getLyrics(
          songId: trackId,
          artist: rawArtist,
          title: rawTitle,
        );
        if (subsonicLyrics != null &&
            (subsonicLyrics.lines.isNotEmpty || subsonicLyrics.rawText.isNotEmpty)) {
          await _storageService.saveCachedLyrics(trackId, subsonicLyrics.rawText, subsonicLyrics.isSynced);
          return subsonicLyrics;
        }
      } catch (_) {}
    }

    // (b) Companion GET /api/lyrics (derive companion base from session server URL by replacing ':6767' with ':6969'; 20s receive timeout)
    final session = _subsonicService.session;
    if (session != null && session.serverUrl.isNotEmpty) {
      try {
        final companionServer = session.serverUrl.replaceAll(':6767', ':6969');
        final cleanBase = companionServer.endsWith('/')
            ? companionServer.substring(0, companionServer.length - 1)
            : companionServer;

        final companionParams = <String, dynamic>{
          'title': rawTitle,
          'artist': rawArtist,
        };
        if (track.album.isNotEmpty) {
          companionParams['album'] = track.album;
        }
        if (durationSec > 0) {
          companionParams['duration'] = durationSec;
        }

        final response = await _dio.get(
          '$cleanBase/api/lyrics',
          queryParameters: companionParams,
          options: Options(
            receiveTimeout: const Duration(seconds: 20),
          ),
        );

        final data = response.data;
        if (data is Map) {
          final isSynced = data['synced'] == true;
          final lrc = data['lrc']?.toString();
          if (lrc != null && lrc.trim().isNotEmpty) {
            if (isSynced) {
              final lyrics = Lyrics.fromLrc(lrc, artist: rawArtist, title: rawTitle);
              if (lyrics.lines.isNotEmpty) {
                await _storageService.saveCachedLyrics(trackId, lrc, true);
                return lyrics;
              }
            }
            final lyrics = Lyrics.fromPlainText(lrc, artist: rawArtist, title: rawTitle);
            await _storageService.saveCachedLyrics(trackId, lrc, false);
            return lyrics;
          }
        }
      } catch (_) {
        // Companion failed or 404, proceed to LRCLIB fallback
      }
    }

    // (c) Existing LRCLIB path as the final fallback
    final cleanArtist = cleanArtistName(rawArtist);
    final cleanTitle = cleanTrackTitle(rawTitle);

    // 1. Try LRCLIB Direct GET (Exact match)
    try {
      final params = <String, dynamic>{
        'artist_name': cleanArtist.isNotEmpty ? cleanArtist : rawArtist,
        'track_name': cleanTitle.isNotEmpty ? cleanTitle : rawTitle,
      };
      if (track.album.isNotEmpty) {
        params['album_name'] = track.album;
      }
      if (durationSec > 0) {
        params['duration'] = durationSec;
      }

      final response = await _dio.get(
        '$_lrclibBaseUrl/get',
        queryParameters: params,
      );

      final data = response.data;
      if (data is Map) {
        final synced = data['syncedLyrics']?.toString();
        if (synced != null && synced.trim().isNotEmpty) {
          final lyrics = Lyrics.fromLrc(synced, artist: rawArtist, title: rawTitle);
          if (lyrics.lines.isNotEmpty) {
            await _storageService.saveCachedLyrics(trackId, synced, true);
            return lyrics;
          }
        }

        final plain = data['plainLyrics']?.toString();
        if (plain != null && plain.trim().isNotEmpty) {
          final lyrics = Lyrics.fromPlainText(plain, artist: rawArtist, title: rawTitle);
          await _storageService.saveCachedLyrics(trackId, plain, false);
          return lyrics;
        }
      }
    } catch (_) {
      // Direct GET didn't find or 404'd, proceed to search
    }

    // 2. Try LRCLIB Search Endpoint (Fuzzy match)
    final searchTitle = cleanTitle.isNotEmpty ? cleanTitle : rawTitle;
    final initialQuery = rawArtist.isNotEmpty ? '$rawArtist $searchTitle' : searchTitle;
    var lrclibLyrics = await _searchLrclib(
      query: initialQuery,
      trackId: trackId,
      rawArtist: rawArtist,
      rawTitle: rawTitle,
    );
    if (lrclibLyrics != null) {
      return lrclibLyrics;
    }

    // Retry with primary artist only (first of comma-separated artists)
    final primaryArtist = rawArtist.split(',').first.trim();
    if (primaryArtist.isNotEmpty && primaryArtist != rawArtist) {
      final retryQuery = '$primaryArtist $searchTitle';
      lrclibLyrics = await _searchLrclib(
        query: retryQuery,
        trackId: trackId,
        rawArtist: rawArtist,
        rawTitle: rawTitle,
      );
      if (lrclibLyrics != null) {
        return lrclibLyrics;
      }
    }

    if (cleanArtist.isNotEmpty && cleanArtist != rawArtist && cleanArtist != primaryArtist) {
      final cleanRetryQuery = '$cleanArtist $searchTitle';
      lrclibLyrics = await _searchLrclib(
        query: cleanRetryQuery,
        trackId: trackId,
        rawArtist: rawArtist,
        rawTitle: rawTitle,
      );
      if (lrclibLyrics != null) {
        return lrclibLyrics;
      }
    }

    return null;
  }

  /// Helper to search LRCLIB and parse best match synced or plain lyrics
  Future<Lyrics?> _searchLrclib({
    required String query,
    required String trackId,
    required String rawArtist,
    required String rawTitle,
  }) async {
    try {
      final response = await _dio.get(
        '$_lrclibBaseUrl/search',
        queryParameters: {'q': query},
      );

      final results = response.data;
      if (results is List && results.isNotEmpty) {
        // Find best match with synced lyrics
        for (final item in results) {
          if (item is Map) {
            final synced = item['syncedLyrics']?.toString();
            if (synced != null && synced.trim().isNotEmpty) {
              final lyrics = Lyrics.fromLrc(synced, artist: rawArtist, title: rawTitle);
              if (lyrics.lines.isNotEmpty) {
                await _storageService.saveCachedLyrics(trackId, synced, true);
                return lyrics;
              }
            }
          }
        }

        // Otherwise fallback to first item with plain lyrics
        for (final item in results) {
          if (item is Map) {
            final plain = item['plainLyrics']?.toString();
            if (plain != null && plain.trim().isNotEmpty) {
              final lyrics = Lyrics.fromPlainText(plain, artist: rawArtist, title: rawTitle);
              await _storageService.saveCachedLyrics(trackId, plain, false);
              return lyrics;
            }
          }
        }
      }
    } catch (_) {
      // LRCLIB search failed or offline
    }
    return null;
  }
}
