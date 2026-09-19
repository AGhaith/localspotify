import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/models/album.dart';
import '../data/models/artist.dart';
import '../data/models/lyrics.dart';
import '../data/models/playlist.dart';
import '../data/models/track.dart';
import '../data/repositories/music_repository.dart';
import '../data/services/spotify_service.dart';
import '../data/services/spotify_importer_service.dart';

class MusicProvider extends ChangeNotifier {
  final MusicRepository _musicRepository;

  // Feeds
  List<Album> _recentAlbums = [];
  List<Album> _frequentAlbums = [];
  List<Artist> _artists = [];
  List<Playlist> _playlists = [];
  List<Track> _starredTracks = [];
  List<Track> _offlineTracks = [];

  // Search
  List<Track> _searchTracks = [];
  List<Album> _searchAlbums = [];
  List<Artist> _searchArtists = [];
  List<Playlist> _searchPlaylists = [];
  List<String> _recentSearches = [];
  bool _isSearching = false;
  Timer? _searchDebounce;

  // Active Pill
  String _activeFilter = 'all'; // 'all', 'music', 'radio'

  // Loading States
  bool _isLoadingHome = false;
  bool _isLoadingLibrary = false;
  String? _homeError;

  // Batch download progress tracking
  String? _downloadingEntityId;
  double _downloadingProgress = 0.0;

  MusicProvider({required MusicRepository musicRepository})
      : _musicRepository = musicRepository {
    _recentSearches = _musicRepository.getRecentSearches();
  }

  // Getters
  List<Album> get recentAlbums => _recentAlbums;
  List<Album> get frequentAlbums => _frequentAlbums;
  List<Artist> get artists => _artists;
  List<Playlist> get playlists => _playlists;
  List<Track> get starredTracks => _starredTracks;
  List<Track> get offlineTracks => _offlineTracks;
  List<Track> get searchTracks => _searchTracks;
  List<Album> get searchAlbums => _searchAlbums;
  List<Artist> get searchArtists => _searchArtists;
  List<Playlist> get searchPlaylists => _searchPlaylists;
  List<String> get recentSearches => _recentSearches;
  bool get isSearching => _isSearching;
  String get activeFilter => _activeFilter;
  bool get isLoadingHome => _isLoadingHome;
  bool get isLoadingLibrary => _isLoadingLibrary;
  String? get homeError => _homeError;

  String? get downloadingEntityId => _downloadingEntityId;
  double get downloadingProgress => _downloadingProgress;

  String getCoverArtUrl(String? coverArtId, {int size = 500}) =>
      _musicRepository.getCoverArtUrl(coverArtId, size: size);

  void setFilter(String filter) {
    _activeFilter = filter;
    notifyListeners();
  }

  Future<void> loadHomeFeed({bool showLoadingSkeleton = false}) async {
    if (showLoadingSkeleton || _recentAlbums.isEmpty) {
      _isLoadingHome = true;
      _homeError = null;
      notifyListeners();
    }

    try {
      final recent = await _musicRepository.getRecentAlbums(size: 20);
      final frequent = await _musicRepository.getFrequentAlbums(size: 20);
      final starred = await _musicRepository.getStarredTracks();

      _recentAlbums = recent;
      _frequentAlbums = frequent;
      _starredTracks = starred;
      _offlineTracks = _musicRepository.getDownloadedTracks();
    } catch (e) {
      _homeError = e.toString();
    } finally {
      _isLoadingHome = false;
      notifyListeners();
    }
  }

  Future<void> loadLibrary({bool showLoadingSkeleton = false}) async {
    if (showLoadingSkeleton || (_playlists.isEmpty && _artists.isEmpty)) {
      _isLoadingLibrary = true;
      notifyListeners();
    }

    try {
      final playlists = await _musicRepository.getPlaylists();
      final artists = await _musicRepository.getArtists();
      final starred = await _musicRepository.getStarredTracks();

      _playlists = playlists;
      _artists = artists;
      _starredTracks = starred;
      _offlineTracks = _musicRepository.getDownloadedTracks();
    } catch (_) {
    } finally {
      _isLoadingLibrary = false;
      notifyListeners();
    }
  }

  // In-memory detail caches to eliminate redundant network requests and UI flickering
  final Map<String, Album> _albumCache = {};
  final Map<String, Artist> _artistCache = {};
  final Map<String, Playlist> _playlistCache = {};
  final Map<String, Lyrics> _lyricsCache = {};

  Future<Album> getAlbumDetails(String albumId, {bool forceRefresh = false}) async {
    if (!forceRefresh && _albumCache.containsKey(albumId)) {
      return _albumCache[albumId]!;
    }
    final album = await _musicRepository.getAlbum(albumId);
    _albumCache[albumId] = album;
    return album;
  }

  Future<Artist> getArtistDetails(String artistId, {bool forceRefresh = false}) async {
    if (!forceRefresh && _artistCache.containsKey(artistId)) {
      return _artistCache[artistId]!;
    }
    final artist = await _musicRepository.getArtist(artistId);
    _artistCache[artistId] = artist;
    return artist;
  }

  Future<Playlist> getPlaylistDetails(String playlistId, {bool forceRefresh = false}) async {
    if (!forceRefresh && _playlistCache.containsKey(playlistId)) {
      return _playlistCache[playlistId]!;
    }
    final playlist = await _musicRepository.getPlaylist(playlistId);
    _playlistCache[playlistId] = playlist;
    return playlist;
  }

  // ================= Search =================
  void searchDebounced(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      search(query);
    });
  }

  Future<void> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      _searchTracks = [];
      _searchAlbums = [];
      _searchArtists = [];
      _searchPlaylists = [];
      _isSearching = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    try {
      final res = await _musicRepository.search(trimmed);
      _searchTracks = res['songs'] as List<Track>? ?? [];
      _searchAlbums = res['albums'] as List<Album>? ?? [];
      _searchArtists = res['artists'] as List<Artist>? ?? [];

      // Filter matching local playlists
      _searchPlaylists = _playlists
          .where((p) => p.name.toLowerCase().contains(trimmed.toLowerCase()))
          .toList();

      // Record to recent searches
      await _musicRepository.addRecentSearch(trimmed);
      _recentSearches = _musicRepository.getRecentSearches();
    } catch (_) {
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  Future<void> clearRecentSearches() async {
    await _musicRepository.clearRecentSearches();
    _recentSearches = [];
    notifyListeners();
  }

  // ================= Star / Like =================
  Future<void> toggleStar(Track track) async {
    final isStarredNow = !track.isStarred;
    if (isStarredNow) {
      _starredTracks.insert(0, track.copyWith(isStarred: true));
    } else {
      _starredTracks.removeWhere((t) => t.id == track.id);
    }
    notifyListeners();

    try {
      await _musicRepository.toggleStarTrack(track);
    } catch (_) {
      // Revert if failed
      if (isStarredNow) {
        _starredTracks.removeWhere((t) => t.id == track.id);
      } else {
        _starredTracks.insert(0, track);
      }
      notifyListeners();
    }
  }

  // ================= Playlists Management =================
  Future<Playlist?> createPlaylist(String name, {List<String>? songIds}) async {
    final pl = await _musicRepository.createPlaylist(name, songIds: songIds);
    if (pl != null) {
      _playlists.insert(0, pl);
      notifyListeners();
    }
    return pl;
  }

  Future<bool> addTrackToPlaylist(String playlistId, String trackId) async {
    final ok = await _musicRepository.updatePlaylist(
      playlistId,
      songIdsToAdd: [trackId],
    );
    if (ok) {
      await loadLibrary();
    }
    return ok;
  }

  Future<bool> removeTrackFromPlaylist(String playlistId, int trackIndex) async {
    final ok = await _musicRepository.updatePlaylist(
      playlistId,
      songIndicesToRemove: [trackIndex],
    );
    if (ok) {
      await loadLibrary();
    }
    return ok;
  }

  Future<bool> deletePlaylist(String playlistId) async {
    final ok = await _musicRepository.deletePlaylist(playlistId);
    if (ok) {
      _playlists.removeWhere((p) => p.id == playlistId);
      notifyListeners();
    }
    return ok;
  }

  // ================= Spotify Playlist Import =================
  Future<SpotifyPlaylistInfo> fetchSpotifyPlaylist(String urlOrId) {
    return _musicRepository.fetchSpotifyPlaylist(urlOrId);
  }

  Future<Playlist?> importSpotifyPlaylist({
    required String spotifyUrl,
    required void Function(ImportProgressStatus) onProgress,
  }) async {
    final pl = await _musicRepository.importSpotifyPlaylist(
      spotifyUrl: spotifyUrl,
      onProgress: onProgress,
    );
    if (pl != null) {
      await loadLibrary();
    }
    return pl;
  }

  // ================= Instant Radio / Mix =================
  Future<List<Track>> getRadioStation(Track seedTrack) {
    return _musicRepository.getSimilarSongs(seedTrack.id, count: 40);
  }

  Future<List<Track>> getRandomMix({int size = 40}) {
    return _musicRepository.getRandomSongs(size: size);
  }

  // ================= Lyrics =================
  Future<Lyrics?> getLyrics(Track track) async {
    if (_lyricsCache.containsKey(track.id)) {
      return _lyricsCache[track.id];
    }
    final lyrics = await _musicRepository.getLyrics(track);
    if (lyrics != null) {
      _lyricsCache[track.id] = lyrics;
    }
    return lyrics;
  }

  // ================= Offline Downloads =================
  Future<void> downloadTrack(Track track) async {
    try {
      final offlineTrack = await _musicRepository.downloadTrack(track);
      _offlineTracks.removeWhere((t) => t.id == track.id);
      _offlineTracks.insert(0, offlineTrack);
      notifyListeners();
    } catch (e) {
      print('[MusicProvider] Failed to download track: $e');
    }
  }

  Future<void> deleteOfflineTrack(String trackId) async {
    await _musicRepository.deleteDownloadedTrack(trackId);
    _offlineTracks.removeWhere((t) => t.id == trackId);
    notifyListeners();
  }

  bool isDownloaded(String trackId) {
    return _musicRepository.isTrackDownloaded(trackId);
  }

  Future<void> downloadAlbum(
    Album album, {
    void Function(int completed, int total)? onProgress,
  }) async {
    _downloadingEntityId = album.id;
    _downloadingProgress = 0.0;
    notifyListeners();

    try {
      final total = album.tracks.length;
      for (int i = 0; i < total; i++) {
        final track = album.tracks[i];
        if (!isDownloaded(track.id)) {
          await downloadTrack(track);
        }
        _downloadingProgress = (i + 1) / total;
        onProgress?.call(i + 1, total);
        notifyListeners();
      }
    } finally {
      _downloadingEntityId = null;
      _downloadingProgress = 0.0;
      notifyListeners();
    }
  }

  Future<void> downloadPlaylist(
    Playlist playlist, {
    void Function(int completed, int total)? onProgress,
  }) async {
    _downloadingEntityId = playlist.id;
    _downloadingProgress = 0.0;
    notifyListeners();

    try {
      final total = playlist.tracks.length;
      for (int i = 0; i < total; i++) {
        final track = playlist.tracks[i];
        if (!isDownloaded(track.id)) {
          await downloadTrack(track);
        }
        _downloadingProgress = (i + 1) / total;
        onProgress?.call(i + 1, total);
        notifyListeners();
      }
    } finally {
      _downloadingEntityId = null;
      _downloadingProgress = 0.0;
      notifyListeners();
    }
  }

  Future<int> getOfflineStorageBytes() {
    return _musicRepository.getTotalDownloadedBytes();
  }

  Future<void> clearAllDownloads() async {
    await _musicRepository.clearAllDownloads();
    _offlineTracks.clear();
    notifyListeners();
  }

  // Streaming Bitrate
  Future<void> saveMaxBitRate(int? bitrate) => _musicRepository.saveMaxBitRate(bitrate);
  int? getMaxBitRate() => _musicRepository.getMaxBitRate();

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}
