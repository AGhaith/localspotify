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

  final Map<String, ArtistCatalog> _artistCatalogCache = {};

  /// Fetch public Deezer music catalog for an artist: top 10 songs and albums with full tracklists.
  Future<ArtistCatalog> fetchArtistCatalog(String artistName) async {
    final cleanName = artistName.trim();
    if (cleanName.isEmpty) {
      return (top: const <SpotifyTrackItem>[], albums: const <ArtistCatalogAlbum>[]);
    }

    final cacheKey = cleanName.toLowerCase();
    if (_artistCatalogCache.containsKey(cacheKey)) {
      return _artistCatalogCache[cacheKey]!;
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
        const emptyResult = (top: <SpotifyTrackItem>[], albums: <ArtistCatalogAlbum>[]);
        _artistCatalogCache[cacheKey] = emptyResult;
        return emptyResult;
      }

      // Pick the Deezer artist whose name best matches (case-insensitive exact first, then highest nb_fan)
      final lowerTarget = cleanName.toLowerCase();
      final exactMatches = artistList
          .where((a) => (a['name']?.toString().trim().toLowerCase() ?? '') == lowerTarget)
          .toList();

      Map bestArtist;
      if (exactMatches.isNotEmpty) {
        exactMatches.sort((a, b) {
          final fansA = (a['nb_fan'] as num?)?.toInt() ?? 0;
          final fansB = (b['nb_fan'] as num?)?.toInt() ?? 0;
          return fansB.compareTo(fansA);
        });
        bestArtist = exactMatches.first;
      } else {
        artistList.sort((a, b) {
          final fansA = (a['nb_fan'] as num?)?.toInt() ?? 0;
          final fansB = (b['nb_fan'] as num?)?.toInt() ?? 0;
          return fansB.compareTo(fansA);
        });
        bestArtist = artistList.first;
      }

      final artistId = bestArtist['id'];
      if (artistId == null) {
        const emptyResult = (top: <SpotifyTrackItem>[], albums: <ArtistCatalogAlbum>[]);
        _artistCatalogCache[cacheKey] = emptyResult;
        return emptyResult;
      }

      // 2. Concurrently fetch top 10 songs and artist albums
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
        queryParameters: {'limit': 100},
        options: Options(
          receiveTimeout: const Duration(seconds: 6),
          sendTimeout: const Duration(seconds: 4),
        ),
      ).catchError((_) => Response(requestOptions: RequestOptions(path: '')));

      final responses = await Future.wait([topFuture, albumsFuture]);

      // Parse top 10 songs
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

            final artist = t['artist']?['name']?.toString() ?? bestArtist['name']?.toString() ?? cleanName;
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

      // Parse albums
      final albumsResp = responses[1];
      final rawAlbums = <Map>[];
      if (albumsResp.data != null) {
        try {
          final data = albumsResp.data is String ? jsonDecode(albumsResp.data) : albumsResp.data;
          final items = (data['data'] as List?)?.whereType<Map>().toList() ?? [];
          rawAlbums.addAll(items);
        } catch (_) {}
      }

      // Prioritize albums: original studio albums first, deprioritize compilations, deluxe, live
      final prioritizedAlbums = List<Map>.from(rawAlbums);
      prioritizedAlbums.sort((a, b) {
        final penA = _albumPenalty(a);
        final penB = _albumPenalty(b);
        if (penA != penB) return penA.compareTo(penB);
        final dateA = a['release_date']?.toString() ?? '';
        final dateB = b['release_date']?.toString() ?? '';
        return dateA.compareTo(dateB);
      });

      // Concurrently fetch album tracklists with max concurrency 6
      final albumTracklists = List<List<Map>?>.filled(prioritizedAlbums.length, null);
      var nextAlbumIdx = 0;

      Future<void> worker() async {
        while (true) {
          final i = nextAlbumIdx++;
          if (i >= prioritizedAlbums.length) break;

          final alb = prioritizedAlbums[i];
          final albId = alb['id'];
          if (albId == null) {
            albumTracklists[i] = const [];
            continue;
          }

          try {
            final resp = await _dio.get(
              'https://api.deezer.com/album/$albId/tracks',
              queryParameters: {'limit': 200},
              options: Options(
                receiveTimeout: const Duration(seconds: 6),
                sendTimeout: const Duration(seconds: 4),
              ),
            );
            final d = resp.data is String ? jsonDecode(resp.data) : resp.data;
            final trkList = (d['data'] as List?)?.whereType<Map>().toList() ?? [];
            albumTracklists[i] = trkList;
          } catch (_) {
            albumTracklists[i] = const [];
          }
        }
      }

      final workerCount = math.min(6, prioritizedAlbums.length);
      if (workerCount > 0) {
        await Future.wait(List.generate(workerCount, (_) => worker()));
      }

      // Dedupe tracks across albums (keep original album version over compilations/"Deluxe"/live)
      final seenTracks = <String>{};
      final parsedAlbums = <({
        String albumTitle,
        String? year,
        String? coverUrl,
        String releaseDate,
        List<SpotifyTrackItem> tracks,
      })>[];

      for (var i = 0; i < prioritizedAlbums.length; i++) {
        final alb = prioritizedAlbums[i];
        final trkList = albumTracklists[i] ?? [];
        if (trkList.isEmpty) continue;

        final albTitle = alb['title']?.toString() ?? 'Unknown Album';
        final releaseDate = alb['release_date']?.toString() ?? '';
        String? year;
        if (releaseDate.isNotEmpty) {
          final yMatch = RegExp(r'^\d{4}').firstMatch(releaseDate);
          if (yMatch != null) year = yMatch.group(0);
        }
        final cover = alb['cover_xl']?.toString() ??
            alb['cover_big']?.toString() ??
            alb['cover_medium']?.toString();

        final albumTracks = <SpotifyTrackItem>[];
        for (final t in trkList) {
          final title = t['title']?.toString() ?? 'Unknown Track';
          final normTitle = _normalizeTrackTitle(title);
          if (normTitle.isEmpty) continue;

          // Dedupe tracks by normalized title (keep original album version)
          if (!seenTracks.add(normTitle)) continue;

          final artist = t['artist']?['name']?.toString() ?? bestArtist['name']?.toString() ?? cleanName;
          final durationSec = (t['duration'] as num?)?.toInt() ?? 180;
          final preview = t['preview']?.toString();
          final link = t['link']?.toString() ?? '';

          albumTracks.add(
            SpotifyTrackItem(
              title: title,
              artist: artist,
              durationMs: durationSec * 1000,
              uri: link,
              previewUrl: preview,
              coverUrl: cover,
              album: albTitle,
            ),
          );
        }

        if (albumTracks.isNotEmpty) {
          parsedAlbums.add((
            albumTitle: albTitle,
            year: year,
            coverUrl: cover,
            releaseDate: releaseDate,
            tracks: albumTracks,
          ));
        }
      }

      // Sort albums reverse-chronologically for display
      parsedAlbums.sort((a, b) => b.releaseDate.compareTo(a.releaseDate));

      final finalAlbums = parsedAlbums
          .map<ArtistCatalogAlbum>((a) => (a.albumTitle, a.year, a.coverUrl, a.tracks))
          .toList();

      final result = (top: topTracks, albums: finalAlbums);
      _artistCatalogCache[cacheKey] = result;
      return result;
    } catch (_) {
      const empty = (top: <SpotifyTrackItem>[], albums: <ArtistCatalogAlbum>[]);
      return empty;
    }
  }

  int _albumPenalty(Map alb) {
    final title = (alb['title']?.toString() ?? '').toLowerCase();
    final recType = (alb['record_type']?.toString() ?? '').toLowerCase();
    int penalty = 0;

    // Compilations / Best of / Greatest Hits
    if (recType == 'compile' ||
        title.contains('compilation') ||
        title.contains('greatest hits') ||
        title.contains('best of') ||
        title.contains('anthology') ||
        title.contains('the collection')) {
      penalty += 1000;
    }

    // Live albums
    if (recType == 'live' || title.contains('live') || title.contains('tour') || title.contains('concert')) {
      penalty += 500;
    }

    // Deluxe / Expanded / Anniversary / Remastered / Special editions
    if (title.contains('deluxe') ||
        title.contains('expanded') ||
        title.contains('anniversary') ||
        title.contains('special edition') ||
        title.contains('remaster') ||
        title.contains('edition') ||
        title.contains('bonus track')) {
      penalty += 200;
    }

    if (recType == 'single') {
      penalty += 50;
    } else if (recType == 'ep') {
      penalty += 30;
    }

    return penalty;
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

