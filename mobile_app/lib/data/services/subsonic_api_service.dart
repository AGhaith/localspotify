import 'package:dio/dio.dart';
import '../models/user_session.dart';
import '../models/track.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../models/playlist.dart';
import '../models/lyrics.dart';
import '../../core/utils/md5_hasher.dart';

class SubsonicApiService {
  final Dio _dio;
  UserSession? _session;

  SubsonicApiService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 20),
                responseType: ResponseType.json,
              ),
            );

  void updateSession(UserSession session) {
    _session = session;
  }

  void clearSession() {
    _session = null;
  }

  UserSession? get session => _session;

  String _cleanUrl(String serverUrl) {
    var url = serverUrl.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  Map<String, dynamic> _buildParams([Map<String, dynamic>? extra]) {
    final params = <String, dynamic>{
      if (_session != null) ..._session!.authQueryParams,
    };
    if (extra != null) {
      params.addAll(extra);
    }
    return params;
  }

  String _getEndpointUrl(String endpoint) {
    if (_session == null) throw Exception('No active session');
    final baseUrl = _cleanUrl(_session!.serverUrl);
    return '$baseUrl/rest/$endpoint.view';
  }

  /// Ping server to test connectivity & authentication
  Future<bool> ping({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    try {
      final salt = Md5Hasher.generateSalt();
      final token = Md5Hasher.hashToken(password, salt);
      final testSession = UserSession(
        serverUrl: _cleanUrl(serverUrl),
        username: username,
        token: token,
        salt: salt,
      );

      final url = '${testSession.serverUrl}/rest/ping.view';
      final response = await _dio.get(
        url,
        queryParameters: testSession.authQueryParams,
      );

      final data = response.data;
      if (data is Map && data.containsKey('subsonic-response')) {
        final status = data['subsonic-response']['status'];
        return status == 'ok';
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Ping server with an existing UserSession to validate tokens
  Future<bool> pingSession(UserSession session) async {
    try {
      final clean = _cleanUrl(session.serverUrl);
      final response = await _dio.get(
        '$clean/rest/ping.view',
        queryParameters: session.authQueryParams,
      );
      final data = response.data;
      if (data is Map && data.containsKey('subsonic-response')) {
        return data['subsonic-response']['status'] == 'ok';
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Create a new user account on the music server
  Future<bool> createUser({
    required String serverUrl,
    required String username,
    required String password,
    required String email,
  }) async {
    final clean = _cleanUrl(serverUrl);

    // 1. Try Subsonic createUser.view first
    try {
      final salt = Md5Hasher.generateSalt();
      final token = Md5Hasher.hashToken(password, salt);
      final query = {
        'u': username,
        't': token,
        's': salt,
        'v': '1.16.1',
        'c': 'LocalSpotify',
        'f': 'json',
        'username': username,
        'password': password,
        'email': email,
      };

      final response = await _dio.get(
        '$clean/rest/createUser.view',
        queryParameters: query,
      );
      final data = response.data;
      if (data is Map && data.containsKey('subsonic-response')) {
        final sub = data['subsonic-response'];
        if (sub['status'] == 'ok') {
          return true;
        }
      }
    } catch (_) {}

    // 2. Try Navidrome Admin REST API
    try {
      final loginResp = await _dio.post(
        '$clean/auth/login',
        data: {'username': 'admin', 'password': 'admin'},
      );
      if (loginResp.statusCode == 200 && loginResp.data is Map) {
        final jwt = loginResp.data['token'];
        if (jwt != null) {
          final createResp = await _dio.post(
            '$clean/api/user',
            data: {
              'userName': username,
              'name': username,
              'email': email,
              'password': password,
              'isAdmin': false,
            },
            options: Options(headers: {'x-nd-authorization': 'Bearer $jwt'}),
          );
          if (createResp.statusCode == 200) {
            return true;
          }
        }
      }
    } catch (_) {}

    return false;
  }

  /// Get Album list by type: recent, newest, frequent, starred, etc.
  Future<List<Album>> getAlbumList({
    String type = 'recent',
    int size = 30,
    int offset = 0,
  }) async {
    final url = _getEndpointUrl('getAlbumList2');
    final response = await _dio.get(
      url,
      queryParameters: _buildParams({
        'type': type,
        'size': size,
        'offset': offset,
      }),
    );

    final subResp = response.data['subsonic-response'];
    if (subResp['status'] != 'ok') {
      throw Exception(subResp['error']?['message'] ?? 'Failed to get albums');
    }

    final albumListRaw = subResp['albumList2']?['album'];
    if (albumListRaw is List) {
      return albumListRaw
          .whereType<Map<String, dynamic>>()
          .map((e) => Album.fromSubsonicJson(e))
          .toList();
    }
    return [];
  }

  /// Get Album details with all songs
  Future<Album> getAlbum(String albumId) async {
    final url = _getEndpointUrl('getAlbum');
    final response = await _dio.get(
      url,
      queryParameters: _buildParams({'id': albumId}),
    );

    final subResp = response.data['subsonic-response'];
    if (subResp['status'] != 'ok') {
      throw Exception(subResp['error']?['message'] ?? 'Failed to get album');
    }

    final albumRaw = subResp['album'];
    if (albumRaw is Map<String, dynamic>) {
      return Album.fromSubsonicJson(albumRaw);
    }
    throw Exception('Album data not found');
  }

  /// Get all artists
  Future<List<Artist>> getArtists() async {
    final url = _getEndpointUrl('getArtists');
    final response = await _dio.get(
      url,
      queryParameters: _buildParams(),
    );

    final subResp = response.data['subsonic-response'];
    if (subResp['status'] != 'ok') {
      throw Exception(subResp['error']?['message'] ?? 'Failed to get artists');
    }

    final indexList = subResp['artists']?['index'];
    final List<Artist> artists = [];
    if (indexList is List) {
      for (final index in indexList) {
        final artistList = index['artist'];
        if (artistList is List) {
          artists.addAll(
            artistList
                .whereType<Map<String, dynamic>>()
                .map((e) => Artist.fromSubsonicJson(e)),
          );
        }
      }
    }
    return artists;
  }

  /// Get artist details with albums
  Future<Artist> getArtist(String artistId) async {
    final url = _getEndpointUrl('getArtist');
    final response = await _dio.get(
      url,
      queryParameters: _buildParams({'id': artistId}),
    );

    final subResp = response.data['subsonic-response'];
    if (subResp['status'] != 'ok') {
      throw Exception(subResp['error']?['message'] ?? 'Failed to get artist');
    }

    final artistRaw = subResp['artist'];
    if (artistRaw is Map<String, dynamic>) {
      return Artist.fromSubsonicJson(artistRaw);
    }
    throw Exception('Artist data not found');
  }

  /// Get user playlists
  Future<List<Playlist>> getPlaylists() async {
    final url = _getEndpointUrl('getPlaylists');
    final response = await _dio.get(
      url,
      queryParameters: _buildParams(),
    );

    final subResp = response.data['subsonic-response'];
    if (subResp['status'] != 'ok') {
      throw Exception(subResp['error']?['message'] ?? 'Failed to get playlists');
    }

    final playlistRaw = subResp['playlists']?['playlist'];
    if (playlistRaw is List) {
      return playlistRaw
          .whereType<Map<String, dynamic>>()
          .map((e) => Playlist.fromSubsonicJson(e))
          .toList();
    }
    return [];
  }

  /// Get playlist details with tracks
  Future<Playlist> getPlaylist(String playlistId) async {
    final url = _getEndpointUrl('getPlaylist');
    final response = await _dio.get(
      url,
      queryParameters: _buildParams({'id': playlistId}),
    );

    final subResp = response.data['subsonic-response'];
    if (subResp['status'] != 'ok') {
      throw Exception(subResp['error']?['message'] ?? 'Failed to get playlist');
    }

    final playlistRaw = subResp['playlist'];
    if (playlistRaw is Map<String, dynamic>) {
      return Playlist.fromSubsonicJson(playlistRaw);
    }
    throw Exception('Playlist data not found');
  }

  /// Get starred / liked tracks, albums, artists
  Future<List<Track>> getStarredTracks() async {
    final url = _getEndpointUrl('getStarred2');
    final response = await _dio.get(
      url,
      queryParameters: _buildParams(),
    );

    final subResp = response.data['subsonic-response'];
    if (subResp['status'] != 'ok') {
      throw Exception(subResp['error']?['message'] ?? 'Failed to get starred tracks');
    }

    final songListRaw = subResp['starred2']?['song'];
    if (songListRaw is List) {
      return songListRaw
          .whereType<Map<String, dynamic>>()
          .map((e) => Track.fromSubsonicJson(e).copyWith(isStarred: true))
          .toList();
    }
    return [];
  }

  /// Star (Like) an item: song, album, artist
  Future<void> starItem({String? songId, String? albumId, String? artistId}) async {
    final url = _getEndpointUrl('star');
    final response = await _dio.get(
      url,
      queryParameters: _buildParams({
        if (songId != null) 'id': songId,
        if (albumId != null) 'albumId': albumId,
        if (artistId != null) 'artistId': artistId,
      }),
    );
    final subResp = response.data['subsonic-response'];
    if (subResp != null && subResp['status'] != 'ok') {
      throw Exception(subResp['error']?['message'] ?? 'Failed to star item');
    }
  }

  /// Unstar (Unlike) an item
  Future<void> unstarItem({String? songId, String? albumId, String? artistId}) async {
    final url = _getEndpointUrl('unstar');
    final response = await _dio.get(
      url,
      queryParameters: _buildParams({
        if (songId != null) 'id': songId,
        if (albumId != null) 'albumId': albumId,
        if (artistId != null) 'artistId': artistId,
      }),
    );
    final subResp = response.data['subsonic-response'];
    if (subResp != null && subResp['status'] != 'ok') {
      throw Exception(subResp['error']?['message'] ?? 'Failed to unstar item');
    }
  }

  /// Global Search
  Future<Map<String, dynamic>> search(String query, {int count = 25}) async {
    if (query.trim().isEmpty) {
      return {'songs': <Track>[], 'albums': <Album>[], 'artists': <Artist>[]};
    }

    final url = _getEndpointUrl('search3');
    final response = await _dio.get(
      url,
      queryParameters: _buildParams({
        'query': query,
        'songCount': count,
        'albumCount': count,
        'artistCount': count,
      }),
    );

    final subResp = response.data['subsonic-response'];
    if (subResp['status'] != 'ok') {
      throw Exception(subResp['error']?['message'] ?? 'Search failed');
    }

    final searchResult = subResp['searchResult3'] ?? {};
    final songRaw = searchResult['song'];
    final albumRaw = searchResult['album'];
    final artistRaw = searchResult['artist'];

    final songs = (songRaw is List)
        ? songRaw.whereType<Map<String, dynamic>>().map((e) => Track.fromSubsonicJson(e)).toList()
        : <Track>[];

    final albums = (albumRaw is List)
        ? albumRaw.whereType<Map<String, dynamic>>().map((e) => Album.fromSubsonicJson(e)).toList()
        : <Album>[];

    final artists = (artistRaw is List)
        ? artistRaw.whereType<Map<String, dynamic>>().map((e) => Artist.fromSubsonicJson(e)).toList()
        : <Artist>[];

    return {
      'songs': songs,
      'albums': albums,
      'artists': artists,
    };
  }

  /// Scrobble track playback
  Future<void> scrobble(String trackId, {bool submission = true}) async {
    try {
      final url = _getEndpointUrl('scrobble');
      await _dio.get(
        url,
        queryParameters: _buildParams({
          'id': trackId,
          'submission': submission,
          'time': DateTime.now().millisecondsSinceEpoch,
        }),
      );
    } catch (_) {}
  }

  /// Get direct audio stream URL for a track
  String getStreamUrl(String trackId, {int? maxBitRate}) {
    if (_session == null) return '';
    final baseUrl = _cleanUrl(_session!.serverUrl);
    final params = Map<String, String>.from(_session!.authQueryParams);
    params['id'] = trackId;
    if (maxBitRate != null) {
      params['maxBitRate'] = maxBitRate.toString();
    }
    final queryStr = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    return '$baseUrl/rest/stream.view?$queryStr';
  }

  /// Get high-resolution cover art URL
  String getCoverArtUrl(String? coverArtId, {int size = 500}) {
    if (coverArtId == null || coverArtId.isEmpty || _session == null) return '';
    if (coverArtId.startsWith('http://') || coverArtId.startsWith('https://')) {
      return coverArtId;
    }
    final baseUrl = _cleanUrl(_session!.serverUrl);
    final params = Map<String, String>.from(_session!.authQueryParams);
    params['id'] = coverArtId;
    params['size'] = size.toString();
    final queryStr = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    return '$baseUrl/rest/getCoverArt.view?$queryStr';
  }

  /// Get rich artist info (Last.fm biography, large image, similar artists)
  Future<Map<String, dynamic>?> getArtistInfo2(String artistId) async {
    try {
      final url = _getEndpointUrl('getArtistInfo2');
      final response = await _dio.get(
        url,
        queryParameters: _buildParams({'id': artistId}),
      );
      final subResp = response.data['subsonic-response'];
      if (subResp['status'] == 'ok') {
        return subResp['artistInfo2'] as Map<String, dynamic>?;
      }
    } catch (_) {}
    return null;
  }

  /// Get Top Songs for an artist
  Future<List<Track>> getTopSongs(String artistName, {int count = 25}) async {
    try {
      final url = _getEndpointUrl('getTopSongs');
      final response = await _dio.get(
        url,
        queryParameters: _buildParams({'artist': artistName, 'count': count}),
      );
      final subResp = response.data['subsonic-response'];
      if (subResp['status'] == 'ok') {
        final rawSongs = subResp['topSongs']?['song'];
        if (rawSongs is List) {
          return rawSongs
              .whereType<Map<String, dynamic>>()
              .map((e) => Track.fromSubsonicJson(e))
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  /// Get Similar Songs (Instant Radio Mix) based on a seed song
  Future<List<Track>> getSimilarSongs2(String songId, {int count = 50}) async {
    try {
      final url = _getEndpointUrl('getSimilarSongs2');
      final response = await _dio.get(
        url,
        queryParameters: _buildParams({'id': songId, 'count': count}),
      );
      final subResp = response.data['subsonic-response'];
      if (subResp['status'] == 'ok') {
        final rawSongs = subResp['similarSongs2']?['song'];
        if (rawSongs is List) {
          return rawSongs
              .whereType<Map<String, dynamic>>()
              .map((e) => Track.fromSubsonicJson(e))
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  /// Get Random Songs (for Shuffle Station / Instant Mix)
  Future<List<Track>> getRandomSongs({int size = 50}) async {
    try {
      final url = _getEndpointUrl('getRandomSongs');
      final response = await _dio.get(
        url,
        queryParameters: _buildParams({'size': size}),
      );
      final subResp = response.data['subsonic-response'];
      if (subResp['status'] == 'ok') {
        final rawSongs = subResp['randomSongs']?['song'];
        if (rawSongs is List) {
          return rawSongs
              .whereType<Map<String, dynamic>>()
              .map((e) => Track.fromSubsonicJson(e))
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  /// Get Lyrics (synced or unsynced)
  Future<Lyrics?> getLyrics({String? songId, String? artist, String? title}) async {
    // 1. Try getLyricsBySongId (OpenSubsonic standard for synced LRC)
    if (songId != null) {
      try {
        final url = _getEndpointUrl('getLyricsBySongId');
        final response = await _dio.get(
          url,
          queryParameters: _buildParams({'id': songId}),
        );
        final subResp = response.data['subsonic-response'];
        if (subResp['status'] == 'ok') {
          final lyricsList = subResp['lyricsList']?['structuredLyrics'];
          if (lyricsList is List && lyricsList.isNotEmpty) {
            final first = lyricsList.first;
            final lineList = first['line'];
            if (lineList is List) {
              final lines = <LyricsLine>[];
              for (final l in lineList) {
                if (l is Map) {
                  final start = (l['start'] as num?)?.toInt() ?? 0;
                  final value = l['value']?.toString() ?? '';
                  lines.add(LyricsLine(timestamp: Duration(milliseconds: start), text: value));
                }
              }
              if (lines.isNotEmpty) {
                return Lyrics(
                  artist: artist,
                  title: title,
                  isSynced: true,
                  lines: lines,
                  rawText: lines.map((l) => l.text).join('\n'),
                );
              }
            }
          }
        }
      } catch (_) {}
    }

    // 2. Fallback to standard getLyrics
    if (artist != null && title != null) {
      try {
        final url = _getEndpointUrl('getLyrics');
        final response = await _dio.get(
          url,
          queryParameters: _buildParams({'artist': artist, 'title': title}),
        );
        final subResp = response.data['subsonic-response'];
        if (subResp['status'] == 'ok') {
          final content = subResp['lyrics']?['content']?.toString();
          if (content != null && content.isNotEmpty) {
            if (content.contains('[00:') || content.contains('[01:')) {
              return Lyrics.fromLrc(content, artist: artist, title: title);
            }
            return Lyrics.fromPlainText(content, artist: artist, title: title);
          }
        }
      } catch (_) {}
    }
    return null;
  }

  /// Create a new playlist
  Future<Playlist?> createPlaylist(String name, {List<String>? songIds}) async {
    try {
      final url = _getEndpointUrl('createPlaylist');
      final params = _buildParams({'name': name});
      if (songIds != null && songIds.isNotEmpty) {
        params['songId'] = songIds;
      }
      final response = await _dio.get(url, queryParameters: params);
      final subResp = response.data['subsonic-response'];
      if (subResp['status'] == 'ok') {
        final plRaw = subResp['playlist'];
        if (plRaw is Map<String, dynamic>) {
          return Playlist.fromSubsonicJson(plRaw);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Update an existing playlist
  Future<bool> updatePlaylist(
    String playlistId, {
    String? name,
    String? comment,
    bool? isPublic,
    List<String>? songIdsToAdd,
    List<int>? songIndicesToRemove,
  }) async {
    try {
      final url = _getEndpointUrl('updatePlaylist');
      final params = _buildParams({'playlistId': playlistId});
      if (name != null) params['name'] = name;
      if (comment != null) params['comment'] = comment;
      if (isPublic != null) params['public'] = isPublic;
      if (songIdsToAdd != null && songIdsToAdd.isNotEmpty) {
        params['songIdToAdd'] = songIdsToAdd;
      }
      if (songIndicesToRemove != null && songIndicesToRemove.isNotEmpty) {
        params['songIndexToRemove'] = songIndicesToRemove;
      }
      final response = await _dio.get(url, queryParameters: params);
      final subResp = response.data['subsonic-response'];
      return subResp['status'] == 'ok';
    } catch (_) {
      return false;
    }
  }

  /// Delete a playlist
  Future<bool> deletePlaylist(String playlistId) async {
    try {
      final url = _getEndpointUrl('deletePlaylist');
      final response = await _dio.get(
        url,
        queryParameters: _buildParams({'id': playlistId}),
      );
      final subResp = response.data['subsonic-response'];
      return subResp['status'] == 'ok';
    } catch (_) {
      return false;
    }
  }

  /// Trigger a library scan on the server
  Future<Map<String, dynamic>?> startScan() async {
    try {
      final url = _getEndpointUrl('startScan');
      final response = await _dio.get(url, queryParameters: _buildParams());
      final subResp = response.data['subsonic-response'];
      if (subResp['status'] == 'ok') {
        return subResp['scanStatus'];
      }
    } catch (_) {}
    return null;
  }

  /// Get status of library scan
  Future<Map<String, dynamic>?> getScanStatus() async {
    try {
      final url = _getEndpointUrl('getScanStatus');
      final response = await _dio.get(url, queryParameters: _buildParams());
      final subResp = response.data['subsonic-response'];
      if (subResp['status'] == 'ok') {
        return subResp['scanStatus'];
      }
    } catch (_) {}
    return null;
  }
}

