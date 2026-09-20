import 'dart:convert';
import 'package:dio/dio.dart';

class SpotifyTrackItem {
  final String title;
  final String artist;
  final int durationMs;
  final String uri;
  final String? previewUrl;
  final String? coverUrl;
  final String? album;

  const SpotifyTrackItem({
    required this.title,
    required this.artist,
    required this.durationMs,
    required this.uri,
    this.previewUrl,
    this.coverUrl,
    this.album,
  });

  String get id => uri.isNotEmpty ? uri : '${artist}_$title';

  /// Returns list of individual artists separated by comma, slash, semicolon, &, or feat/ft
  List<String> get individualArtists {
    if (artist.trim().isEmpty) return [];
    final pattern = RegExp(r'\s*(?:,|/|;|&|\bfeat\.?|\bft\.?|\bwith\b)\s*', caseSensitive: false);
    final parts = artist
        .split(pattern)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && !s.toLowerCase().startsWith('feat') && !s.toLowerCase().startsWith('ft'))
        .toList();
    return parts.isNotEmpty ? parts : [artist];
  }

  /// Primary or lead artist
  String get primaryArtist => individualArtists.isNotEmpty ? individualArtists.first : artist;

  String get durationFormatted {
    final minutes = durationMs ~/ 60000;
    final seconds = ((durationMs % 60000) ~/ 1000).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class SpotifyPlaylistInfo {
  final String id;
  final String name;
  final String description;
  final String? coverUrl;
  final List<SpotifyTrackItem> tracks;

  const SpotifyPlaylistInfo({
    required this.id,
    required this.name,
    required this.description,
    this.coverUrl,
    required this.tracks,
  });

  int get trackCount => tracks.length;
}

class SpotifyService {
  final Dio _dio;

  SpotifyService({Dio? dio}) : _dio = dio ?? Dio();

  /// Parse Spotify playlist ID from URL, URI, or raw ID
  static String? parsePlaylistId(String input) {
    final clean = input.trim();
    if (clean.isEmpty) return null;

    // Match https://open.spotify.com/playlist/{id}
    final urlRegex = RegExp(r'open\.spotify\.com\/playlist\/([a-zA-Z0-9]+)');
    final matchUrl = urlRegex.firstMatch(clean);
    if (matchUrl != null) return matchUrl.group(1);

    // Match spotify:playlist:{id}
    final uriRegex = RegExp(r'spotify:playlist:([a-zA-Z0-9]+)');
    final matchUri = uriRegex.firstMatch(clean);
    if (matchUri != null) return matchUri.group(1);

    // Raw alphanumeric ID (15 to 30 chars)
    if (RegExp(r'^[a-zA-Z0-9]{15,30}$').hasMatch(clean)) {
      return clean;
    }
    return null;
  }

  /// Fetch playlist metadata and tracklist from Spotify public embed API
  Future<SpotifyPlaylistInfo> fetchPlaylist(String urlOrId) async {
    final playlistId = parsePlaylistId(urlOrId);
    if (playlistId == null) {
      throw Exception('Invalid Spotify playlist link or ID. Please check the URL.');
    }

    try {
      final embedUrl = 'https://open.spotify.com/embed/playlist/$playlistId';
      final response = await _dio.get(
        embedUrl,
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.9',
          },
          receiveTimeout: const Duration(seconds: 12),
          sendTimeout: const Duration(seconds: 8),
        ),
      );

      final html = response.data.toString();
      const marker = '<script id="__NEXT_DATA__" type="application/json">';
      final startIndex = html.indexOf(marker);

      if (startIndex != -1) {
        final endIndex = html.indexOf('</script>', startIndex);
        if (endIndex != -1) {
          final jsonStr = html.substring(startIndex + marker.length, endIndex);
          final data = jsonDecode(jsonStr);
          final entity = data['props']?['pageProps']?['state']?['data']?['entity'];

          if (entity != null) {
            final name = entity['title']?.toString() ?? 'Imported Playlist';
            final desc = entity['subtitle']?.toString() ?? 'Spotify Playlist';
            String? coverUrl;

            // Extract cover image
            final images = entity['visualIdentity']?['image'];
            if (images is List && images.isNotEmpty) {
              final lastImg = images.last;
              if (lastImg is Map && lastImg['url'] != null) {
                coverUrl = lastImg['url'].toString();
              }
            }

            final trackListRaw = entity['trackList'];
            final tracks = <SpotifyTrackItem>[];
            if (trackListRaw is List) {
              for (final t in trackListRaw) {
                if (t is Map) {
                  final title = t['title']?.toString() ?? 'Unknown Title';
                  final artist = t['subtitle']?.toString() ?? 'Unknown Artist';
                  final duration = (t['duration'] as num?)?.toInt() ?? 180000;
                  final uri = t['uri']?.toString() ?? '';
                  final preview = t['audioPreview']?['url']?.toString();

                  tracks.add(
                    SpotifyTrackItem(
                      title: title,
                      artist: artist,
                      durationMs: duration,
                      uri: uri,
                      previewUrl: preview,
                      coverUrl: coverUrl,
                      album: name,
                    ),
                  );
                }
              }
            }

            return SpotifyPlaylistInfo(
              id: playlistId,
              name: name,
              description: desc,
              coverUrl: coverUrl,
              tracks: tracks,
            );
          }
        }
      }

      // Fallback: oEmbed endpoint
      return await _fetchViaOEmbed(playlistId);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Spotify playlist not found. Ensure the playlist is public.');
      }
      throw Exception('Could not connect to Spotify. Check your internet connection.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to load playlist: $e');
    }
  }

  Future<SpotifyPlaylistInfo> _fetchViaOEmbed(String playlistId) async {
    final oembedUrl = 'https://open.spotify.com/oembed?url=https://open.spotify.com/playlist/$playlistId';
    final response = await _dio.get(oembedUrl);
    final data = response.data;

    if (data is Map) {
      final name = data['title']?.toString() ?? 'Spotify Playlist';
      final coverUrl = data['thumbnail_url']?.toString();
      return SpotifyPlaylistInfo(
        id: playlistId,
        name: name,
        description: 'Imported from Spotify',
        coverUrl: coverUrl,
        tracks: const [],
      );
    }
    throw Exception('Unable to fetch Spotify playlist details.');
  }

  /// Search global music catalog with Egyptian storefront optimization and Deezer Arabic integration
  Future<List<SpotifyTrackItem>> searchTracks(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return [];

    final results = <SpotifyTrackItem>[];
    final seenKeys = <String>{};

    void addTrack(SpotifyTrackItem item) {
      final key = '${item.title.toLowerCase().trim()}:::${item.artist.toLowerCase().trim()}';
      if (seenKeys.add(key)) {
        results.add(item);
      }
    }

    try {
      // Launch parallel requests:
      // 1. Apple iTunes with Egypt storefront (country=EG)
      final itunesEgyptFuture = _dio.get(
        'https://itunes.apple.com/search',
        queryParameters: {
          'term': clean,
          'country': 'EG',
          'media': 'music',
          'entity': 'song',
          'limit': 25,
        },
        options: Options(receiveTimeout: const Duration(seconds: 5), sendTimeout: const Duration(seconds: 4)),
      ).catchError((_) => Response(requestOptions: RequestOptions(path: '')));

      // 2. Deezer API (comprehensive Arabic & Egyptian rap/pop catalogue)
      final deezerFuture = _dio.get(
        'https://api.deezer.com/search',
        queryParameters: {
          'q': clean,
          'limit': 25,
        },
        options: Options(receiveTimeout: const Duration(seconds: 5), sendTimeout: const Duration(seconds: 4)),
      ).catchError((_) => Response(requestOptions: RequestOptions(path: '')));

      // 3. Apple iTunes Global (fallback)
      final itunesGlobalFuture = _dio.get(
        'https://itunes.apple.com/search',
        queryParameters: {
          'term': clean,
          'media': 'music',
          'entity': 'song',
          'limit': 15,
        },
        options: Options(receiveTimeout: const Duration(seconds: 5), sendTimeout: const Duration(seconds: 4)),
      ).catchError((_) => Response(requestOptions: RequestOptions(path: '')));

      final responses = await Future.wait([itunesEgyptFuture, deezerFuture, itunesGlobalFuture]);

      // Parse iTunes Egypt results first
      final itunesEgResp = responses[0];
      if (itunesEgResp.data != null) {
        try {
          final data = itunesEgResp.data is String ? jsonDecode(itunesEgResp.data) : itunesEgResp.data;
          final items = (data['results'] as List?) ?? [];
          for (final r in items) {
            final rawArtwork = r['artworkUrl100']?.toString();
            final highResArtwork = rawArtwork?.replaceAll('100x100bb', '600x600bb');
            final duration = (r['trackTimeMillis'] as num?)?.toInt() ?? 180000;
            addTrack(
              SpotifyTrackItem(
                title: r['trackName']?.toString() ?? 'Unknown Track',
                artist: r['artistName']?.toString() ?? 'Unknown Artist',
                durationMs: duration,
                uri: r['trackViewUrl']?.toString() ?? '',
                previewUrl: r['previewUrl']?.toString(),
                coverUrl: highResArtwork,
                album: r['collectionName']?.toString(),
              ),
            );
          }
        } catch (_) {}
      }

      // Parse Deezer results
      final deezerResp = responses[1];
      if (deezerResp.data != null) {
        try {
          final data = deezerResp.data is String ? jsonDecode(deezerResp.data) : deezerResp.data;
          final items = (data['data'] as List?) ?? [];
          for (final d in items) {
            final title = d['title']?.toString() ?? 'Unknown Track';
            final artist = d['artist']?['name']?.toString() ?? 'Unknown Artist';
            final durationSec = (d['duration'] as num?)?.toInt() ?? 180;
            final preview = d['preview']?.toString();
            final cover = d['album']?['cover_big']?.toString() ?? d['album']?['cover_medium']?.toString();
            final album = d['album']?['title']?.toString();
            final link = d['link']?.toString() ?? '';

            addTrack(
              SpotifyTrackItem(
                title: title,
                artist: artist,
                durationMs: durationSec * 1000,
                uri: link,
                previewUrl: preview,
                coverUrl: cover,
                album: album,
              ),
            );
          }
        } catch (_) {}
      }

      // Parse Global iTunes fallback
      final itunesGlobalResp = responses[2];
      if (itunesGlobalResp.data != null) {
        try {
          final data = itunesGlobalResp.data is String ? jsonDecode(itunesGlobalResp.data) : itunesGlobalResp.data;
          final items = (data['results'] as List?) ?? [];
          for (final r in items) {
            final rawArtwork = r['artworkUrl100']?.toString();
            final highResArtwork = rawArtwork?.replaceAll('100x100bb', '600x600bb');
            final duration = (r['trackTimeMillis'] as num?)?.toInt() ?? 180000;
            addTrack(
              SpotifyTrackItem(
                title: r['trackName']?.toString() ?? 'Unknown Track',
                artist: r['artistName']?.toString() ?? 'Unknown Artist',
                durationMs: duration,
                uri: r['trackViewUrl']?.toString() ?? '',
                previewUrl: r['previewUrl']?.toString(),
                coverUrl: highResArtwork,
                album: r['collectionName']?.toString(),
              ),
            );
          }
        } catch (_) {}
      }

      return results;
    } catch (_) {
      return results;
    }
  }

  /// Resolves an audio stream/preview URL for a given title and artist
  Future<String?> resolvePreviewUrl(String title, String artist) async {
    try {
      final response = await _dio.get(
        'https://itunes.apple.com/search',
        queryParameters: {
          'term': '$title $artist',
          'media': 'music',
          'entity': 'song',
          'limit': 5,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 6),
          sendTimeout: const Duration(seconds: 4),
        ),
      );
      final data = response.data;
      final Map<String, dynamic> jsonMap = data is String ? jsonDecode(data) : data;
      final results = jsonMap['results'] as List? ?? [];
      for (final r in results) {
        final preview = r['previewUrl']?.toString();
        if (preview != null && preview.isNotEmpty) {
          return preview;
        }
      }
    } catch (_) {}

    // Fallback: search just title
    try {
      final response = await _dio.get(
        'https://itunes.apple.com/search',
        queryParameters: {
          'term': title,
          'media': 'music',
          'entity': 'song',
          'limit': 5,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 6),
          sendTimeout: const Duration(seconds: 4),
        ),
      );
      final data = response.data;
      final Map<String, dynamic> jsonMap = data is String ? jsonDecode(data) : data;
      final results = jsonMap['results'] as List? ?? [];
      for (final r in results) {
        final preview = r['previewUrl']?.toString();
        if (preview != null && preview.isNotEmpty) {
          return preview;
        }
      }
    } catch (_) {}

    return null;
  }
}

