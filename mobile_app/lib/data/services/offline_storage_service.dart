import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_session.dart';
import '../models/track.dart';
import '../models/lyrics.dart';

class OfflineStorageService {
  static const String _keySession = 'localspotify_user_session';
  static const String _keyDownloadedTracks = 'localspotify_downloaded_tracks';
  static const String _keyMaxBitRate = 'localspotify_max_bitrate';
  static const String _keyRecentSearches = 'localspotify_recent_searches';
  static const String _keyPlaylistCovers = 'localspotify_playlist_covers';
  static const String _keyImportedPlaylistTracks = 'localspotify_imported_playlist_tracks';

  final SharedPreferences _prefs;
  final Dio _dio;

  OfflineStorageService({
    required SharedPreferences prefs,
    Dio? dio,
  })  : _prefs = prefs,
        _dio = dio ?? Dio();

  static Future<OfflineStorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return OfflineStorageService(prefs: prefs);
  }

  // ================= Auth Session =================
  Future<void> saveSession(UserSession session) async {
    await _prefs.setString(_keySession, jsonEncode(session.toJson()));
  }

  UserSession? getSavedSession() {
    final raw = _prefs.getString(_keySession);
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return UserSession.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSession() async {
    await _prefs.remove(_keySession);
  }

  // ================= Bitrate & Settings =================
  Future<void> saveMaxBitRate(int? bitrate) async {
    if (bitrate == null) {
      await _prefs.remove(_keyMaxBitRate);
    } else {
      await _prefs.setInt(_keyMaxBitRate, bitrate);
    }
  }

  int? getMaxBitRate() {
    return _prefs.getInt(_keyMaxBitRate);
  }

  // ================= Recent Searches =================
  List<String> getRecentSearches() {
    return _prefs.getStringList(_keyRecentSearches) ?? [];
  }

  Future<void> addRecentSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final list = getRecentSearches();
    list.removeWhere((item) => item.toLowerCase() == trimmed.toLowerCase());
    list.insert(0, trimmed);
    if (list.length > 15) {
      list.removeRange(15, list.length);
    }
    await _prefs.setStringList(_keyRecentSearches, list);
  }

  Future<void> removeRecentSearch(String query) async {
    final list = getRecentSearches();
    list.removeWhere((item) => item.toLowerCase() == query.trim().toLowerCase());
    await _prefs.setStringList(_keyRecentSearches, list);
  }

  Future<void> clearRecentSearches() async {
    await _prefs.remove(_keyRecentSearches);
  }

  // ================= Custom Playlist Covers & Imported Tracks =================
  Future<void> savePlaylistCover(String idOrName, String url) async {
    final raw = _prefs.getString(_keyPlaylistCovers);
    final Map<String, dynamic> map = raw != null ? (jsonDecode(raw) as Map<String, dynamic>) : {};
    map[idOrName.toLowerCase().trim()] = url;
    await _prefs.setString(_keyPlaylistCovers, jsonEncode(map));
  }

  String? getPlaylistCover(String idOrName) {
    final raw = _prefs.getString(_keyPlaylistCovers);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map[idOrName.toLowerCase().trim()] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveImportedPlaylistTracks(String idOrName, List<Map<String, dynamic>> tracks) async {
    final raw = _prefs.getString(_keyImportedPlaylistTracks);
    final Map<String, dynamic> map = raw != null ? (jsonDecode(raw) as Map<String, dynamic>) : {};
    map[idOrName.toLowerCase().trim()] = tracks;
    await _prefs.setString(_keyImportedPlaylistTracks, jsonEncode(map));
  }

  List<Map<String, dynamic>> getImportedPlaylistTracks(String idOrName) {
    final raw = _prefs.getString(_keyImportedPlaylistTracks);
    if (raw == null) return [];
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final list = map[idOrName.toLowerCase().trim()];
      if (list is List) {
        return list.whereType<Map<String, dynamic>>().toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ================= Offline Downloads =================
  Future<Directory> get _musicDirectory async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/music');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> get _coversDirectory async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/music/covers');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  List<Track> getDownloadedTracks() {
    final raw = _prefs.getStringList(_keyDownloadedTracks) ?? [];
    return raw.map((item) {
      try {
        final json = jsonDecode(item) as Map<String, dynamic>;
        return Track.fromJson(json);
      } catch (_) {
        return null;
      }
    }).whereType<Track>().toList();
  }

  bool isTrackDownloaded(String trackId) {
    return getDownloadedTracks().any((t) => t.id == trackId);
  }

  Future<Track> downloadTrack({
    required Track track,
    required String downloadUrl,
    String? coverArtUrl,
    void Function(int received, int total)? onProgress,
  }) async {
    final dir = await _musicDirectory;
    final extension = track.suffix != null && track.suffix!.isNotEmpty
        ? track.suffix
        : 'm4a';
    final filePath = '${dir.path}/${track.id}.$extension';

    // 1. Download audio file
    await _dio.download(
      downloadUrl,
      filePath,
      onReceiveProgress: onProgress,
    );

    // 2. Download offline cover art if available
    String? localCoverPath;
    if (coverArtUrl != null && coverArtUrl.isNotEmpty) {
      try {
        final coversDir = await _coversDirectory;
        final safeCoverId = track.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
        final coverFilePath = '${coversDir.path}/cover_$safeCoverId.jpg';
        final coverFile = File(coverFilePath);
        if (!await coverFile.exists()) {
          await _dio.download(coverArtUrl, coverFilePath);
        }
        localCoverPath = coverFilePath;
      } catch (_) {}
    }

    final offlineTrack = track.copyWith(
      isOffline: true,
      localAudioPath: filePath,
      localCoverArtPath: localCoverPath,
    );

    // Save to list
    final existing = getDownloadedTracks();
    existing.removeWhere((t) => t.id == track.id);
    existing.insert(0, offlineTrack);

    final jsonList = existing.map((t) => jsonEncode(t.toJson())).toList();
    await _prefs.setStringList(_keyDownloadedTracks, jsonList);

    return offlineTrack;
  }

  Future<void> deleteDownloadedTrack(String trackId) async {
    final existing = getDownloadedTracks();
    final index = existing.indexWhere((t) => t.id == trackId);
    if (index != -1) {
      final track = existing[index];
      if (track.localAudioPath != null) {
        final file = File(track.localAudioPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
      if (track.localCoverArtPath != null) {
        final coverFile = File(track.localCoverArtPath!);
        if (await coverFile.exists()) {
          await coverFile.delete();
        }
      }
      existing.removeAt(index);
      final jsonList = existing.map((t) => jsonEncode(t.toJson())).toList();
      await _prefs.setStringList(_keyDownloadedTracks, jsonList);
    }
  }

  Future<int> getTotalDownloadedBytes() async {
    try {
      final dir = await _musicDirectory;
      int totalSize = 0;
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
      }
      return totalSize;
    } catch (_) {
      return 0;
    }
  }

  Future<void> clearAllDownloads() async {
    try {
      final dir = await _musicDirectory;
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
    await _prefs.remove(_keyDownloadedTracks);
  }

  // ================= Lyrics Storage & Cache =================
  Future<void> saveCachedLyrics(String trackId, String rawLrc, bool isSynced) async {
    await _prefs.setString('localspotify_lyrics_$trackId', rawLrc);
    await _prefs.setBool('localspotify_lyrics_synced_$trackId', isSynced);
  }

  Lyrics? getCachedLyrics(String trackId, {String? artist, String? title}) {
    final raw = _prefs.getString('localspotify_lyrics_$trackId');
    if (raw == null || raw.trim().isEmpty) return null;
    final isSynced = _prefs.getBool('localspotify_lyrics_synced_$trackId') ?? false;
    if (isSynced) {
      return Lyrics.fromLrc(raw, artist: artist, title: title);
    }
    return Lyrics.fromPlainText(raw, artist: artist, title: title);
  }
}
