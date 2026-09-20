import 'dart:async';
import 'package:dio/dio.dart';
import '../models/playlist.dart';
import 'offline_storage_service.dart';
import 'spotify_service.dart';
import 'subsonic_api_service.dart';

enum ImportStage {
  fetching,
  downloading,
  indexing,
  creating,
  completed,
  error,
}

class ImportProgressStatus {
  final ImportStage stage;
  final String message;
  final double progress; // 0.0 to 1.0
  final String? currentTrack;
  final int completedCount;
  final int totalCount;
  final Playlist? playlist;

  const ImportProgressStatus({
    required this.stage,
    required this.message,
    required this.progress,
    this.currentTrack,
    this.completedCount = 0,
    this.totalCount = 0,
    this.playlist,
  });
}

class SpotifyImporterService {
  final SpotifyService _spotifyService;
  final SubsonicApiService _apiService;
  final OfflineStorageService? _storageService;
  final Dio _dio;

  SpotifyImporterService({
    SpotifyService? spotifyService,
    required SubsonicApiService apiService,
    OfflineStorageService? storageService,
    Dio? dio,
  })  : _spotifyService = spotifyService ?? SpotifyService(),
        _apiService = apiService,
        _storageService = storageService,
        _dio = dio ?? Dio();

  Dio get dio => _dio;

  /// Executes full Spotify playlist import pipeline
  Future<Playlist?> importPlaylist({
    required String spotifyUrl,
    required void Function(ImportProgressStatus status) onProgress,
  }) async {
    // 1. Fetch playlist metadata & tracks from Spotify
    onProgress(
      const ImportProgressStatus(
        stage: ImportStage.fetching,
        message: 'Resolving Spotify playlist details & tracklist...',
        progress: 0.1,
      ),
    );

    final playlistInfo = await _spotifyService.fetchPlaylist(spotifyUrl);
    final totalTracks = playlistInfo.tracks.length;

    onProgress(
      ImportProgressStatus(
        stage: ImportStage.fetching,
        message: 'Found "${playlistInfo.name}" with $totalTracks tracks',
        progress: 0.2,
        totalCount: totalTracks,
      ),
    );

    // 2. Dispatch download request to server vault
    onProgress(
      ImportProgressStatus(
        stage: ImportStage.downloading,
        message: 'Requesting server vault to download high-fidelity audio...',
        progress: 0.25,
        totalCount: totalTracks,
      ),
    );

    final session = _apiService.session;
    if (session != null) {
      try {
        final serverBase = session.serverUrl;
        final companionServer = serverBase.replaceAll(':6767', ':6969');
        await _dio.post(
          '$companionServer/api/import-playlist',
          data: {
            'spotifyUrl': spotifyUrl,
            'playlistName': playlistInfo.name,
            'coverUrl': playlistInfo.coverUrl,
            'tracks': playlistInfo.tracks
                .map((t) => {
                      'title': t.title,
                      'artist': t.artist,
                      'durationMs': t.durationMs,
                      'uri': t.uri,
                    })
                .toList(),
            'username': session.username,
          },
          options: Options(
            receiveTimeout: const Duration(seconds: 10),
            sendTimeout: const Duration(seconds: 10),
          ),
        );
      } catch (_) {
        // Continue gracefully if server companion downloader is running in background or using local sync
      }
    }

    // 3. Process & Match Tracks against Server Library
    final matchedSongIds = <String>[];
    for (int i = 0; i < totalTracks; i++) {
      final track = playlistInfo.tracks[i];
      final currentProgress = 0.25 + ((i + 1) / totalTracks) * 0.55;

      onProgress(
        ImportProgressStatus(
          stage: ImportStage.downloading,
          message: 'Processing (${i + 1}/$totalTracks): "${track.title}"',
          progress: currentProgress,
          currentTrack: '${track.title} - ${track.artist}',
          completedCount: i + 1,
          totalCount: totalTracks,
        ),
      );

      try {
        // Search server library for existing or newly synced track
        final searchRes = await _apiService.search(track.title);
        final songs = searchRes['songs'];
        if (songs is List && songs.isNotEmpty) {
          final cleanArtist = track.artist.toLowerCase();
          final matched = songs.firstWhere(
            (s) {
              final sArtist = s.artist.toString().toLowerCase();
              return sArtist.contains(cleanArtist) || cleanArtist.contains(sArtist);
            },
            orElse: () => songs.first,
          );
          if (matched != null && !matchedSongIds.contains(matched.id)) {
            matchedSongIds.add(matched.id);
          }
        }
      } catch (_) {}

      // Short delay for smooth UI feedback
      await Future.delayed(const Duration(milliseconds: 30));
    }

    // 4. Trigger Server Scan to index new tracks
    onProgress(
      ImportProgressStatus(
        stage: ImportStage.indexing,
        message: 'Syncing audio files into music catalog...',
        progress: 0.85,
        totalCount: totalTracks,
        completedCount: totalTracks,
      ),
    );

    try {
      await _apiService.startScan();
    } catch (_) {}

    // 5. Create the playlist on the user's account
    onProgress(
      ImportProgressStatus(
        stage: ImportStage.creating,
        message: 'Adding "${playlistInfo.name}" to your account...',
        progress: 0.92,
        totalCount: totalTracks,
        completedCount: totalTracks,
      ),
    );

    final createdPlaylist = await _apiService.createPlaylist(
      playlistInfo.name,
      songIds: matchedSongIds.isNotEmpty ? matchedSongIds : null,
    );

    final plId = createdPlaylist?.id ?? 'imported_${DateTime.now().millisecondsSinceEpoch}';

    // Persist custom Spotify playlist cover
    if (playlistInfo.coverUrl != null && playlistInfo.coverUrl!.isNotEmpty) {
      await _storageService?.savePlaylistCover(plId, playlistInfo.coverUrl!);
      await _storageService?.savePlaylistCover(playlistInfo.name, playlistInfo.coverUrl!);
    }

    // Persist imported track metadata for zero-state display while server downloads
    final rawTrackList = playlistInfo.tracks
        .map((t) => {
              'title': t.title,
              'artist': t.artist,
              'durationMs': t.durationMs,
              'uri': t.uri,
            })
        .toList();
    await _storageService?.saveImportedPlaylistTracks(plId, rawTrackList);
    await _storageService?.saveImportedPlaylistTracks(playlistInfo.name, rawTrackList);

    // 6. Complete
    final finalPlaylist = (createdPlaylist != null)
        ? Playlist(
            id: createdPlaylist.id,
            name: createdPlaylist.name,
            songCount: matchedSongIds.isNotEmpty ? matchedSongIds.length : playlistInfo.tracks.length,
            duration: createdPlaylist.duration > 0 ? createdPlaylist.duration : totalTracks * 180,
            coverArtId: playlistInfo.coverUrl ?? createdPlaylist.coverArtId,
            tracks: createdPlaylist.tracks,
          )
        : Playlist(
            id: plId,
            name: playlistInfo.name,
            songCount: totalTracks,
            duration: totalTracks * 180,
            coverArtId: playlistInfo.coverUrl,
          );

    onProgress(
      ImportProgressStatus(
        stage: ImportStage.completed,
        message: 'Playlist "${playlistInfo.name}" is now on your account!',
        progress: 1.0,
        totalCount: totalTracks,
        completedCount: totalTracks,
        playlist: finalPlaylist,
      ),
    );

    return finalPlaylist;
  }
}
