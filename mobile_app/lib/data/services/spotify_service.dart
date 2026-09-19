import 'dart:convert';
import 'package:dio/dio.dart';

class SpotifyTrackItem {
  final String title;
  final String artist;
  final int durationMs;
  final String uri;
  final String? previewUrl;

  const SpotifyTrackItem({
    required this.title,
    required this.artist,
    required this.durationMs,
    required this.uri,
    this.previewUrl,
  });

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
}
