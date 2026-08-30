import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_session.dart';
import '../models/track.dart';

class OfflineStorageService {
  static const String _keySession = 'localspotify_user_session';
  static const String _keyDownloadedTracks = 'localspotify_downloaded_tracks';

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

  // ================= Offline Downloads =================
  Future<Directory> get _musicDirectory async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/music');
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
    void Function(int received, int total)? onProgress,
  }) async {
    final dir = await _musicDirectory;
    final extension = track.suffix != null && track.suffix!.isNotEmpty
        ? track.suffix
        : 'm4a';
    final filePath = '${dir.path}/${track.id}.$extension';

    await _dio.download(
      downloadUrl,
      filePath,
      onReceiveProgress: onProgress,
    );

    final offlineTrack = track.copyWith(
      isOffline: true,
      localAudioPath: filePath,
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
      existing.removeAt(index);
      final jsonList = existing.map((t) => jsonEncode(t.toJson())).toList();
      await _prefs.setStringList(_keyDownloadedTracks, jsonList);
    }
  }
}
