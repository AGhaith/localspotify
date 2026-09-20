import '../models/album.dart';
import '../models/artist.dart';
import '../models/lyrics.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../models/user_session.dart';
import '../services/subsonic_api_service.dart';
import '../services/offline_storage_service.dart';
import '../services/lyrics_service.dart';
import '../services/spotify_service.dart';
import '../services/spotify_importer_service.dart';
import '../services/audio_stream_resolver_service.dart';

class MusicRepository {
  final SubsonicApiService _apiService;
  final OfflineStorageService _storageService;
  final LyricsService _lyricsService;
  final SpotifyService _spotifyService;
  final SpotifyImporterService _spotifyImporterService;
  final AudioStreamResolverService _streamResolver;

  MusicRepository({
    required SubsonicApiService apiService,
    required OfflineStorageService storageService,
    LyricsService? lyricsService,
    SpotifyService? spotifyService,
    SpotifyImporterService? spotifyImporterService,
    AudioStreamResolverService? streamResolver,
  })  : _apiService = apiService,
        _storageService = storageService,
        _lyricsService = lyricsService ??
            LyricsService(
              subsonicService: apiService,
              storageService: storageService,
            ),
        _spotifyService = spotifyService ?? SpotifyService(),
        _spotifyImporterService = spotifyImporterService ??
            SpotifyImporterService(
              apiService: apiService,
              spotifyService: spotifyService,
              storageService: storageService,
            ),
        _streamResolver = streamResolver ?? AudioStreamResolverService();

  String getCoverArtUrl(
    String? coverArtId, {
    int size = 500,
    String? playlistId,
    String? playlistName,
    String? albumName,
    int? songCount,
  }) {
    if (coverArtId != null && (coverArtId.startsWith('http://') || coverArtId.startsWith('https://'))) {
      return coverArtId;
    }
    if (playlistId != null) {
      final custom = _storageService.getPlaylistCover(playlistId);
      if (custom != null && custom.isNotEmpty) return custom;
    }
    if (playlistName != null) {
      final custom = _storageService.getPlaylistCover(playlistName);
      if (custom != null && custom.isNotEmpty) return custom;
    }
    if (albumName != null) {
      final custom = _storageService.getPlaylistCover(albumName);
      if (custom != null && custom.isNotEmpty) return custom;
    }
    if (coverArtId != null) {
      final custom = _storageService.getPlaylistCover(coverArtId);
      if (custom != null && custom.isNotEmpty) return custom;
    }
    // If it's a playlist with 0 songs, NEVER return Navidrome's default vinyl cover art!
    if (songCount == 0 && (coverArtId?.startsWith('pl-') ?? false)) {
      return '';
    }
    return _apiService.getCoverArtUrl(coverArtId, size: size);
  }

  Future<void> savePlaylistCover(String idOrName, String url) {
    return _storageService.savePlaylistCover(idOrName, url);
  }

  String? getPlaylistCover(String idOrName) {
    return _storageService.getPlaylistCover(idOrName);
  }

  Future<void> saveImportedPlaylistTracks(String idOrName, List<SpotifyTrackItem> tracks) {
    return _storageService.saveImportedPlaylistTracks(
      idOrName,
      tracks
          .map((t) => {
                'title': t.title,
                'artist': t.artist,
                'durationMs': t.durationMs,
                'uri': t.uri,
                'coverUrl': t.coverUrl,
                'album': t.album,
              })
          .toList(),
    );
  }

  List<SpotifyTrackItem> getImportedPlaylistTracks(String idOrName) {
    final list = _storageService.getImportedPlaylistTracks(idOrName);
    return list
        .map((m) => SpotifyTrackItem(
              title: m['title']?.toString() ?? '',
              artist: m['artist']?.toString() ?? '',
              durationMs: (m['durationMs'] as num?)?.toInt() ?? 0,
              uri: m['uri']?.toString() ?? '',
              coverUrl: m['coverUrl']?.toString(),
              album: m['album']?.toString(),
            ))
        .toList();
  }

  String getStreamUrl(String trackId) {
    final maxBitRate = _storageService.getMaxBitRate();
    return _apiService.getStreamUrl(trackId, maxBitRate: maxBitRate);
  }

  Future<List<Album>> getRecentAlbums({int size = 20}) {
    return _apiService.getAlbumList(type: 'recent', size: size);
  }

  Future<List<Album>> getFrequentAlbums({int size = 20}) {
    return _apiService.getAlbumList(type: 'frequent', size: size);
  }

  Future<List<Album>> getNewestAlbums({int size = 20}) {
    return _apiService.getAlbumList(type: 'newest', size: size);
  }

  Future<Album> getAlbum(String albumId) {
    return _apiService.getAlbum(albumId);
  }

  Future<List<Artist>> getArtists() {
    return _apiService.getArtists();
  }

  Future<Artist> getArtist(String artistId) async {
    final baseArtist = await _apiService.getArtist(artistId);
    final info = await _apiService.getArtistInfo2(artistId);
    final topSongs = await _apiService.getTopSongs(baseArtist.name, count: 20);

    var enriched = baseArtist;
    if (info != null) {
      enriched = Artist.fromArtistInfoJson(baseArtist: enriched, infoJson: info);
    }
    if (topSongs.isNotEmpty) {
      enriched = enriched.copyWith(topTracks: topSongs);
    }
    return enriched;
  }

  Future<List<Track>> getTopSongs(String artistName, {int count = 25}) {
    return _apiService.getTopSongs(artistName, count: count);
  }

  Future<List<Track>> getSimilarSongs(String songId, {int count = 50}) {
    return _apiService.getSimilarSongs2(songId, count: count);
  }

  Future<List<Track>> getRandomSongs({int size = 50}) {
    return _apiService.getRandomSongs(size: size);
  }

  Future<Lyrics?> getLyrics(Track track) {
    return _lyricsService.getLyrics(track);
  }

  Future<List<Playlist>> getPlaylists() {
    return _apiService.getPlaylists();
  }

  Future<Playlist> getPlaylist(String playlistId) async {
    final pl = await _apiService.getPlaylist(playlistId);
    final imported = getImportedPlaylistTracks(playlistId).isNotEmpty
        ? getImportedPlaylistTracks(playlistId)
        : getImportedPlaylistTracks(pl.name);
    final customCover = getPlaylistCover(playlistId) ?? getPlaylistCover(pl.name);

    final enrichedTracks = pl.tracks.map((t) {
      String title = t.title;
      String artist = t.artist;
      String album = t.album;
      String? coverArtId = t.coverArtId;

      // If artist is unknown or generic and title contains ' - ', extract artist & title
      if ((artist.isEmpty || artist.toLowerCase().contains('unknown')) && title.contains(' - ')) {
        final parts = title.split(' - ');
        if (parts.length >= 2) {
          artist = parts[0].trim();
          title = parts.sublist(1).join(' - ').trim();
        }
      }

      SpotifyTrackItem? match;
      final cleanTitle = title.toLowerCase().trim();
      final fullRaw = t.title.toLowerCase().trim();
      for (final imp in imported) {
        final impTitle = imp.title.toLowerCase().trim();
        if (impTitle == cleanTitle ||
            cleanTitle.contains(impTitle) ||
            impTitle.contains(cleanTitle) ||
            fullRaw.contains(impTitle)) {
          match = imp;
          break;
        }
      }

      if (match != null) {
        title = match.title;
        if (artist == 'Unknown Artist' || artist.isEmpty || artist.toLowerCase().contains('unknown')) {
          artist = match.artist;
        }
        if (album == 'Unknown Album' || album.isEmpty || album.toLowerCase().contains('unknown')) {
          album = match.album ?? pl.name;
        }
        if (coverArtId == null || coverArtId.isEmpty || coverArtId.startsWith('pl-')) {
          coverArtId = match.coverUrl ?? customCover;
        }
      } else {
        if (album == 'Unknown Album' || album.isEmpty || album.toLowerCase().contains('unknown')) {
          album = pl.name;
        }
        if (coverArtId == null || coverArtId.isEmpty || coverArtId.startsWith('pl-')) {
          coverArtId = customCover;
        }
      }

      return t.copyWith(
        title: title,
        artist: artist,
        album: album,
        coverArtId: coverArtId,
      );
    }).toList();

    return pl.copyWith(
      tracks: enrichedTracks,
      coverArtId: (pl.coverArtId != null && pl.coverArtId!.isNotEmpty && !pl.coverArtId!.startsWith('pl-'))
          ? pl.coverArtId
          : customCover,
    );
  }

  Future<Playlist?> createPlaylist(String name, {List<String>? songIds}) {
    return _apiService.createPlaylist(name, songIds: songIds);
  }

  Future<bool> updatePlaylist(
    String playlistId, {
    String? name,
    String? comment,
    bool? isPublic,
    List<String>? songIdsToAdd,
    List<int>? songIndicesToRemove,
  }) {
    return _apiService.updatePlaylist(
      playlistId,
      name: name,
      comment: comment,
      isPublic: isPublic,
      songIdsToAdd: songIdsToAdd,
      songIndicesToRemove: songIndicesToRemove,
    );
  }

  Future<bool> deletePlaylist(String playlistId) {
    return _apiService.deletePlaylist(playlistId);
  }

  Future<Playlist> syncPlaylistTracksWithVault(String playlistId) async {
    final playlist = await getPlaylist(playlistId);
    final imported = getImportedPlaylistTracks(playlistId).isNotEmpty
        ? getImportedPlaylistTracks(playlistId)
        : getImportedPlaylistTracks(playlist.name);

    if (imported.isEmpty) return playlist;

    final existingTitles = playlist.tracks.map((t) => t.title.toLowerCase().trim()).toSet();
    final songIdsToAdd = <String>[];

    for (final imp in imported) {
      if (imp.title.isEmpty || existingTitles.contains(imp.title.toLowerCase().trim())) continue;

      try {
        final searchRes = await search(imp.title);
        final songs = searchRes['songs'];
        if (songs is List<Track> && songs.isNotEmpty) {
          final cleanArtist = imp.artist.toLowerCase();
          final matched = songs.firstWhere(
            (s) {
              final sArtist = s.artist.toLowerCase();
              return sArtist.contains(cleanArtist) || cleanArtist.contains(sArtist);
            },
            orElse: () => songs.first,
          );
          if (!playlist.tracks.any((t) => t.id == matched.id) && !songIdsToAdd.contains(matched.id)) {
            songIdsToAdd.add(matched.id);
          }
        }
      } catch (_) {}
    }

    if (songIdsToAdd.isNotEmpty) {
      await updatePlaylist(playlistId, songIdsToAdd: songIdsToAdd);
      return getPlaylist(playlistId);
    }

    return playlist;
  }

  Future<List<Track>> getStarredTracks() {
    return _apiService.getStarredTracks();
  }

  Future<void> starTrack(String trackId) {
    return _apiService.starItem(songId: trackId);
  }

  Future<void> unstarTrack(String trackId) {
    return _apiService.unstarItem(songId: trackId);
  }

  Future<void> toggleStarTrack(Track track) async {
    if (track.isStarred) {
      await unstarTrack(track.id);
    } else {
      await starTrack(track.id);
    }
  }

  Future<Map<String, dynamic>> search(String query) {
    return _apiService.search(query);
  }

  Future<void> scrobble(String trackId) {
    return _apiService.scrobble(trackId);
  }

  // ================= Offline & Storage Handling =================
  List<Track> getDownloadedTracks() {
    return _storageService.getDownloadedTracks();
  }

  bool isTrackDownloaded(String trackId) {
    return _storageService.isTrackDownloaded(trackId);
  }

  Future<Track> downloadTrack(Track track, {void Function(int, int)? onProgress}) async {
    String streamUrl = (track.localAudioPath != null && track.localAudioPath!.isNotEmpty)
        ? track.localAudioPath!
        : _apiService.getStreamUrl(track.id);

    // If it's a Spotify track or an iTunes 30s preview URL, resolve the FULL studio song stream first
    if (track.id.startsWith('spotify_') || streamUrl.contains('audio-ssl.itunes.apple.com') || streamUrl.contains('preview')) {
      final resolvedFullStream = await _streamResolver.resolveFullAudioStream(
        title: track.title,
        artist: track.artist,
        expectedDurationSec: track.duration,
      );
      if (resolvedFullStream != null && resolvedFullStream.isNotEmpty) {
        streamUrl = resolvedFullStream;
      }
    }

    final coverArtUrl = getCoverArtUrl(track.coverArtId, size: 500);
    // Pre-cache lyrics for offline playback
    try {
      await _lyricsService.getLyrics(track);
    } catch (_) {}
    return _storageService.downloadTrack(
      track: track,
      downloadUrl: streamUrl,
      coverArtUrl: coverArtUrl,
      onProgress: onProgress,
    );
  }

  Future<void> deleteDownloadedTrack(String trackId) {
    return _storageService.deleteDownloadedTrack(trackId);
  }

  Future<int> getTotalDownloadedBytes() {
    return _storageService.getTotalDownloadedBytes();
  }

  Future<void> clearAllDownloads() {
    return _storageService.clearAllDownloads();
  }

  // Bitrate & Search Settings
  Future<void> saveMaxBitRate(int? bitrate) => _storageService.saveMaxBitRate(bitrate);
  int? getMaxBitRate() => _storageService.getMaxBitRate();

  List<String> getRecentSearches() => _storageService.getRecentSearches();
  Future<void> addRecentSearch(String query) => _storageService.addRecentSearch(query);
  Future<void> clearRecentSearches() => _storageService.clearRecentSearches();

  // ================= Spotify Playlist Import =================
  Future<SpotifyPlaylistInfo> fetchSpotifyPlaylist(String urlOrId) {
    return _spotifyService.fetchPlaylist(urlOrId);
  }

  Future<Playlist?> importSpotifyPlaylist({
    required String spotifyUrl,
    required void Function(ImportProgressStatus) onProgress,
  }) {
    return _spotifyImporterService.importPlaylist(
      spotifyUrl: spotifyUrl,
      onProgress: onProgress,
    );
  }

  UserSession? get session => _apiService.session;

  // ================= Spotify Search & Catalog Sync =================
  Future<List<SpotifyTrackItem>> searchSpotifyTracks(String query) {
    return _spotifyService.searchTracks(query);
  }

  Future<Track> createTrackFromSpotifyItem(SpotifyTrackItem item) async {
    // Generate a consistent pseudo-ID for this track
    final pseudoId = 'spotify_${item.title.hashCode.abs()}_${item.artist.hashCode.abs()}';
    
    // Dispatch background sync request to server companion
    final session = _apiService.session;
    String? companionStreamUrl;
    if (session != null) {
      try {
        final companionServer = session.serverUrl.replaceAll(':6767', ':6969');
        companionStreamUrl = '$companionServer/api/stream?title=${Uri.encodeComponent(item.title)}&artist=${Uri.encodeComponent(item.artist)}';
        _spotifyImporterService.dio.post(
          '$companionServer/api/import-track',
          data: {
            'title': item.title,
            'artist': item.artist,
            'album': item.album ?? item.title,
            'durationMs': item.durationMs,
            'coverUrl': item.coverUrl,
            'uri': item.uri,
            'username': session.username,
          },
        ).then((_) {}).catchError((_) => null);
      } catch (_) {}
    }

    // 1. Resolve full-length studio audio stream
    String? audioUrl = await _streamResolver.resolveFullAudioStream(
      title: item.title,
      artist: item.artist,
      expectedDurationSec: item.durationMs ~/ 1000,
    );

    // 2. Fallback to direct preview or companion stream if full resolution is unavailable
    if (audioUrl == null || audioUrl.isEmpty) {
      audioUrl = item.previewUrl;
    }
    if (audioUrl == null || audioUrl.isEmpty) {
      audioUrl = await _spotifyService.resolvePreviewUrl(item.title, item.artist);
    }
    if ((audioUrl == null || audioUrl.isEmpty) && companionStreamUrl != null) {
      audioUrl = companionStreamUrl;
    }

    return Track(
      id: pseudoId,
      title: item.title,
      artist: item.artist,
      album: item.album ?? 'Spotify Release',
      albumId: 'sp_${item.album.hashCode.abs()}',
      duration: item.durationMs ~/ 1000,
      coverArtId: item.coverUrl,
      localAudioPath: audioUrl,
    );
  }

  Future<Map<String, dynamic>?> startServerScan() => _apiService.startScan();
  Future<Map<String, dynamic>?> getServerScanStatus() => _apiService.getScanStatus();
}

