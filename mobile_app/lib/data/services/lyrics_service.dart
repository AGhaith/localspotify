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
        .replaceAll(RegExp(r'\s*[\(\[](?:feat|ft|with|prod)\.?\s+[^\)\]]+[\)\]]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*[\(\[](?:official\s+(?:audio|video|music\s+video)|remastered(?:\s+\d+)?|remix|bonus\s+track|deluxe\s+edition)[\)\]]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*-\s*(?:remastered(?:\s+\d+)?|single\s+version|live)[\w\s]*', caseSensitive: false), '')
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
  /// 2. LRCLIB Direct GET (high-accuracy synced LRC)
  /// 3. LRCLIB Search endpoint (fuzzy fallback)
  /// 4. Server getLyricsBySongId & getLyrics (server local files)
  Future<Lyrics?> getLyrics(Track track) async {
    final trackId = track.id;

    // 1. Check local offline storage cache
    final cached = _storageService.getCachedLyrics(trackId, artist: track.artist, title: track.title);
    if (cached != null) {
      return cached;
    }

    final rawArtist = track.artist;
    final rawTitle = track.title;
    final cleanArtist = cleanArtistName(rawArtist);
    final cleanTitle = cleanTrackTitle(rawTitle);
    final durationSec = track.duration;

    // 2. Try LRCLIB Direct GET (Exact match)
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

    // 3. Try LRCLIB Search Endpoint (Fuzzy match)
    try {
      final query = cleanArtist.isNotEmpty ? '$cleanArtist $cleanTitle' : '$rawArtist $rawTitle';
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

    // 4. Try server endpoints
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

    return null;
  }
}
