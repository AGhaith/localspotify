import 'dart:convert';
import 'dart:math' as math;
import 'package:dio/dio.dart';

typedef ArtistCatalogAlbum = (
  String albumTitle,
  String? year,
  String? coverUrl,
  List<SpotifyTrackItem> tracks,
);

typedef ArtistCatalog = ({
  List<SpotifyTrackItem> top,
  List<ArtistCatalogAlbum> albums,
});

extension ArtistCatalogAlbumExt on ArtistCatalogAlbum {
  String get albumTitle => $1;
  String? get year => $2;
  String? get coverUrl => $3;
  List<SpotifyTrackItem> get tracks => $4;
}

class CatalogRelease {
  final String id;
  final String title;
  final String? year;
  final String? releaseDate;
  final String? coverUrl;
  final String recordType;
  final String? artistName;

  const CatalogRelease({
    required this.id,
    required this.title,
    this.year,
    this.releaseDate,
    this.coverUrl,
    required this.recordType,
    this.artistName,
  });

  String get typeLabel {
    final rt = recordType.toLowerCase();
    if (rt == 'single') return 'Single';
    if (rt == 'ep') return 'EP';
    if (rt == 'compile') return 'Compilation';
    return 'Album';
  }
}

class CatalogRelatedArtist {
  final String id;
  final String name;
  final String? pictureUrl;

  const CatalogRelatedArtist({
    required this.id,
    required this.name,
    this.pictureUrl,
  });
}

class ArtistProfile {
  final String artistId;
  final String artistName;
  final String? pictureUrl;
  final List<SpotifyTrackItem> topTracks;
  final List<CatalogRelease> releases;
  final List<CatalogRelatedArtist> relatedArtists;

  const ArtistProfile({
    required this.artistId,
    required this.artistName,
    this.pictureUrl,
    required this.topTracks,
    required this.releases,
    this.relatedArtists = const [],
  });

  static const empty = ArtistProfile(
    artistId: '',
    artistName: '',
    topTracks: [],
    releases: [],
    relatedArtists: [],
  );

  bool get isEmpty => artistId.isEmpty && topTracks.isEmpty && releases.isEmpty;
  bool get isNotEmpty => !isEmpty;
}

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

  static final Map<String, ArtistProfile> _artistProfileCache = {};
  static final Map<String, List<SpotifyTrackItem>> _albumTracksCache = {};
  static final Map<String, ArtistCatalog> _artistCatalogCache = {};

  /// Invalidate cached catalog/profile for an artist (used by retry / pull-to-refresh)
  void invalidateArtistCache(String artistName) {
    final clean = artistName.trim().toLowerCase();
    _artistProfileCache.remove(clean);
    _artistCatalogCache.remove(clean);
  }

  /// Invalidate cached tracks for an album
  void invalidateAlbumCache(String albumId) {
    _albumTracksCache.remove(albumId.trim());
  }

  /// Calculates name similarity score between 0.0 and 1.0 using normalized string comparison
  /// and Levenshtein edit distance.
  static double calculateNameSimilarity(String target, String candidate) {
    final t = _normalizeCatalogArtistName(target);
    final c = _normalizeCatalogArtistName(candidate);
    if (t == c) return 1.0;
    if (t.isEmpty || c.isEmpty) return 0.0;

    // Handle optional "the " prefix
    final tNoThe = t.startsWith('the ') ? t.substring(4).trim() : t;
    final cNoThe = c.startsWith('the ') ? c.substring(4).trim() : c;
    if (tNoThe == cNoThe && tNoThe.isNotEmpty) return 0.98;

    final dist = _levenshtein(t, c);
    final maxLen = math.max(t.length, c.length);
    return maxLen == 0 ? 1.0 : (1.0 - (dist / maxLen));
  }

  static String _normalizeCatalogArtistName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    if (RegExp(r'[\u0600-\u06ff]').hasMatch(trimmed)) {
      return trimmed
          .replaceAll(RegExp(r'''[!"#\$%&'()*+,\-./:;<=>?@\[\\\]^_`{|}~\u2000-\u206f]'''), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }
    const accents = 'àáâãäåāçćčďèéêëēěìíîïīñńòóôõöøōřśšùúûüūýÿžźż';
    const plain = 'aaaaaaacccdeeeeeeiiiiinnooooooorssuuuuuyyzzz';
    final lower = trimmed.toLowerCase().replaceAll(RegExp(r'[\u0300-\u036f]'), '');
    final folded = lower.split('').map((letter) {
      final index = accents.indexOf(letter);
      return index < 0 ? letter : plain[index];
    }).join();
    return folded
        .replaceAll(RegExp(r'''[!"#\$%&'()*+,\-./:;<=>?@\[\\\]^_`{|}~\u2000-\u206f]'''), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static int _levenshtein(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<int> v0 = List<int>.generate(s2.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(s2.length + 1, 0);

    for (int i = 0; i < s1.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < s2.length; j++) {
        int cost = (s1[i] == s2[j]) ? 0 : 1;
        v1[j + 1] = math.min(v1[j] + 1, math.min(v0[j + 1] + 1, v0[j] + cost));
      }
      for (int j = 0; j <= s2.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v0[s2.length];
  }

  /// Fetches Deezer artist profile: matching Deezer artist, top 10 songs, bounded releases list
  /// (WITHOUT tracklists for immediate response), and related artists.
  Future<ArtistProfile> fetchArtistProfile(String artistName, {bool forceRefresh = false}) async {
    final cleanName = artistName.trim();
    if (cleanName.isEmpty) {
      return ArtistProfile.empty;
    }

    final cacheKey = cleanName.toLowerCase();
    if (forceRefresh) {
      _artistProfileCache.remove(cacheKey);
      _artistCatalogCache.remove(cacheKey);
    }
    if (!forceRefresh && _artistProfileCache.containsKey(cacheKey)) {
      return _artistProfileCache[cacheKey]!;
    }

    try {
      // 1. Search Deezer for the artist
      final searchResp = await _dio.get(
        'https://api.deezer.com/search/artist',
        queryParameters: {
          'q': cleanName,
          'limit': 15,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 6),
          sendTimeout: const Duration(seconds: 4),
        ),
      );

      final searchData = searchResp.data is String ? jsonDecode(searchResp.data) : searchResp.data;
      final artistList = (searchData['data'] as List?)?.whereType<Map>().toList() ?? [];
      if (artistList.isEmpty) {
        _artistProfileCache[cacheKey] = ArtistProfile.empty;
        return ArtistProfile.empty;
      }

      // Filter Deezer search results using a name similarity threshold (fix item 4)
      final candidates = <({Map artist, double similarity, int fans})>[];
      for (final a in artistList) {
        final candName = a['name']?.toString() ?? '';
        final sim = calculateNameSimilarity(cleanName, candName);
        if (sim >= 0.85) {
          final fans = (a['nb_fan'] as num?)?.toInt() ?? 0;
          candidates.add((artist: a, similarity: sim, fans: fans));
        }
      }

      if (candidates.isEmpty) {
        _artistProfileCache[cacheKey] = ArtistProfile.empty;
        return ArtistProfile.empty;
      }

      // Prioritize exact match, then highest similarity, then fan count
      candidates.sort((a, b) {
        final exactA = a.similarity >= 0.98;
        final exactB = b.similarity >= 0.98;
        if (exactA != exactB) return exactA ? -1 : 1;
        if (exactA && exactB) return b.fans.compareTo(a.fans);
        final simComp = b.similarity.compareTo(a.similarity);
        if (simComp != 0) return simComp;
        return b.fans.compareTo(a.fans);
      });

      final bestArtist = candidates.first.artist;
      final artistId = bestArtist['id']?.toString();
      if (artistId == null || artistId.isEmpty) {
        _artistProfileCache[cacheKey] = ArtistProfile.empty;
        return ArtistProfile.empty;
      }

      final artistPicture = bestArtist['picture_xl']?.toString() ??
          bestArtist['picture_big']?.toString() ??
          bestArtist['picture_medium']?.toString();
      final matchedArtistName = bestArtist['name']?.toString() ?? cleanName;

      // 2. Concurrently fetch top 10 songs, bounded releases (limit 50), and related artists
      final topFuture = _dio.get(
        'https://api.deezer.com/artist/$artistId/top',
        queryParameters: {'limit': 10},
        options: Options(
          receiveTimeout: const Duration(seconds: 6),
          sendTimeout: const Duration(seconds: 4),
        ),
      ).catchError((_) => Response(requestOptions: RequestOptions(path: '')));

      final albumsFuture = _dio.get(
        'https://api.deezer.com/artist/$artistId/albums',
        queryParameters: {'limit': 50},
        options: Options(
          receiveTimeout: const Duration(seconds: 6),
          sendTimeout: const Duration(seconds: 4),
        ),
      ).catchError((_) => Response(requestOptions: RequestOptions(path: '')));

      final relatedFuture = _dio.get(
        'https://api.deezer.com/artist/$artistId/related',
        queryParameters: {'limit': 20},
        options: Options(
          receiveTimeout: const Duration(seconds: 6),
          sendTimeout: const Duration(seconds: 4),
        ),
      ).catchError((_) => Response(requestOptions: RequestOptions(path: '')));

      final responses = await Future.wait([topFuture, albumsFuture, relatedFuture]);

      // Parse top 10 tracks
      final topTracks = <SpotifyTrackItem>[];
      final topResp = responses[0];
      if (topResp.data != null) {
        try {
          final data = topResp.data is String ? jsonDecode(topResp.data) : topResp.data;
          final items = (data['data'] as List?)?.whereType<Map>().toList() ?? [];
          final seenTop = <String>{};
          for (final t in items) {
            final title = t['title']?.toString() ?? 'Unknown Track';
            final norm = _normalizeTrackTitle(title);
            if (norm.isEmpty || !seenTop.add(norm)) continue;

            final artist = t['artist']?['name']?.toString() ?? matchedArtistName;
            final durationSec = (t['duration'] as num?)?.toInt() ?? 180;
            final preview = t['preview']?.toString();
            final cover = t['album']?['cover_xl']?.toString() ??
                t['album']?['cover_big']?.toString() ??
                t['album']?['cover_medium']?.toString();
            final album = t['album']?['title']?.toString();
            final link = t['link']?.toString() ?? '';

            topTracks.add(
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

      // Parse bounded releases without fetching tracklists up front (fix item 13)
      final rawReleases = <CatalogRelease>[];
      final albumsResp = responses[1];
      if (albumsResp.data != null) {
        try {
          final data = albumsResp.data is String ? jsonDecode(albumsResp.data) : albumsResp.data;
          final items = (data['data'] as List?)?.whereType<Map>().toList() ?? [];
          for (final alb in items) {
            final albId = alb['id']?.toString() ?? '';
            if (albId.isEmpty) continue;
            final albTitle = alb['title']?.toString() ?? 'Unknown Release';
            final releaseDate = alb['release_date']?.toString() ?? '';
            String? year;
            if (releaseDate.isNotEmpty) {
              final yMatch = RegExp(r'^\d{4}').firstMatch(releaseDate);
              if (yMatch != null) year = yMatch.group(0);
            }
            final cover = alb['cover_xl']?.toString() ??
                alb['cover_big']?.toString() ??
                alb['cover_medium']?.toString();
            final recordType = alb['record_type']?.toString().toLowerCase() ?? 'album';

            rawReleases.add(
              CatalogRelease(
                id: albId,
                title: albTitle,
                year: year,
                releaseDate: releaseDate,
                coverUrl: cover,
                recordType: recordType,
                artistName: matchedArtistName,
              ),
            );
          }
        } catch (_) {}
      }

      // Sort releases reverse-chronologically by release date
      rawReleases.sort((a, b) {
        final dateA = a.releaseDate ?? '';
        final dateB = b.releaseDate ?? '';
        return dateB.compareTo(dateA);
      });

      // Parse related artists (fix item 15)
      final relatedArtists = <CatalogRelatedArtist>[];
      final relatedResp = responses[2];
      if (relatedResp.data != null) {
        try {
          final data = relatedResp.data is String ? jsonDecode(relatedResp.data) : relatedResp.data;
          final items = (data['data'] as List?)?.whereType<Map>().toList() ?? [];
          for (final rel in items) {
            final rId = rel['id']?.toString() ?? '';
            final rName = rel['name']?.toString() ?? '';
            if (rId.isEmpty || rName.isEmpty) continue;
            if (rId == artistId || calculateNameSimilarity(cleanName, rName) >= 0.95) {
              continue; // Exclude current artist
            }

            final pic = rel['picture_xl']?.toString() ??
                rel['picture_big']?.toString() ??
                rel['picture_medium']?.toString() ??
                rel['picture']?.toString();

            relatedArtists.add(
              CatalogRelatedArtist(
                id: rId,
                name: rName,
                pictureUrl: pic,
              ),
            );
          }
        } catch (_) {}
      }

      final profile = ArtistProfile(
        artistId: artistId,
        artistName: matchedArtistName,
        pictureUrl: artistPicture,
        topTracks: topTracks,
        releases: rawReleases,
        relatedArtists: relatedArtists,
      );

      _artistProfileCache[cacheKey] = profile;
      return profile;
    } catch (_) {
      return ArtistProfile.empty;
    }
  }

  /// Fetches tracklist for a specific album on demand from Deezer /album/{id}.
  /// Deduplicates tracks within the release strictly by track ID (fix item 5).
  Future<List<SpotifyTrackItem>> fetchAlbumTracks(String albumId, {bool forceRefresh = false}) async {
    final cleanId = albumId.trim();
    if (cleanId.isEmpty) return const [];

    if (forceRefresh) {
      _albumTracksCache.remove(cleanId);
    }
    if (!forceRefresh && _albumTracksCache.containsKey(cleanId)) {
      return _albumTracksCache[cleanId]!;
    }

    try {
      final resp = await _dio.get(
        'https://api.deezer.com/album/$cleanId',
        options: Options(
          receiveTimeout: const Duration(seconds: 6),
          sendTimeout: const Duration(seconds: 4),
        ),
      );

      final data = resp.data is String ? jsonDecode(resp.data) : resp.data;
      final albumTitle = data['title']?.toString() ?? 'Unknown Album';
      final albumArtist = data['artist']?['name']?.toString() ?? '';
      final cover = data['cover_xl']?.toString() ??
          data['cover_big']?.toString() ??
          data['cover_medium']?.toString();

      var trackList = (data['tracks']?['data'] as List?)?.whereType<Map>().toList() ?? [];

      if (trackList.isEmpty) {
        final tracksResp = await _dio.get(
          'https://api.deezer.com/album/$cleanId/tracks',
          queryParameters: {'limit': 200},
          options: Options(
            receiveTimeout: const Duration(seconds: 6),
            sendTimeout: const Duration(seconds: 4),
          ),
        );
        final td = tracksResp.data is String ? jsonDecode(tracksResp.data) : tracksResp.data;
        trackList = (td['data'] as List?)?.whereType<Map>().toList() ?? [];
      }

      final seenTrackIds = <String>{};
      final tracks = <SpotifyTrackItem>[];

      for (final t in trackList) {
        final trackId = t['id']?.toString() ?? '';
        // Deduplicate within this release strictly by track ID (fix item 5)
        if (trackId.isNotEmpty && !seenTrackIds.add(trackId)) {
          continue;
        }

        final title = t['title']?.toString() ?? 'Unknown Track';
        final artist = t['artist']?['name']?.toString() ?? albumArtist;
        final durationSec = (t['duration'] as num?)?.toInt() ?? 180;
        final preview = t['preview']?.toString();
        final link = t['link']?.toString() ?? '';

        tracks.add(
          SpotifyTrackItem(
            title: title,
            artist: artist,
            durationMs: durationSec * 1000,
            uri: link.isNotEmpty ? link : trackId,
            previewUrl: preview,
            coverUrl: cover,
            album: albumTitle,
          ),
        );
      }

      _albumTracksCache[cleanId] = tracks;
      return tracks;
    } catch (_) {
      return const [];
    }
  }

  /// Backward-compatible catalog method. Calls fetchArtistProfile and formats into ArtistCatalog.
  Future<ArtistCatalog> fetchArtistCatalog(String artistName, {bool forceRefresh = false}) async {
    final cleanName = artistName.trim();
    if (cleanName.isEmpty) {
      return (top: const <SpotifyTrackItem>[], albums: const <ArtistCatalogAlbum>[]);
    }

    final cacheKey = cleanName.toLowerCase();
    if (forceRefresh) {
      _artistCatalogCache.remove(cacheKey);
    }
    if (!forceRefresh && _artistCatalogCache.containsKey(cacheKey)) {
      return _artistCatalogCache[cacheKey]!;
    }

    final profile = await fetchArtistProfile(cleanName, forceRefresh: forceRefresh);
    final catalog = (
      top: profile.topTracks,
      albums: profile.releases
          .map<ArtistCatalogAlbum>((r) => (
                r.title,
                r.year,
                r.coverUrl,
                const <SpotifyTrackItem>[],
              ))
          .toList(),
    );

    _artistCatalogCache[cacheKey] = catalog;
    return catalog;
  }

  String _normalizeTrackTitle(String title) {
    var s = title.toLowerCase();
    s = s.replaceAll(
      RegExp(
        r'\s*[\(\[](?:feat\.?|ft\.?|with|live|remaster(?:ed)?|deluxe|version|radio edit|bonus|instrumental|edit|mix)[^\)\]]*[\)\]]',
        caseSensitive: false,
      ),
      '',
    );
    s = s.replaceAll(RegExp(r'[^\w\s\u0600-\u06FF]'), ' ');
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

