import 'dart:async';
import 'package:flutter/material.dart';
import '../data/models/album.dart';
import '../data/models/artist.dart';
import '../data/models/lyrics.dart';
import '../data/models/playlist.dart';
import '../data/models/track.dart';
import '../data/repositories/music_repository.dart';
import '../data/services/spotify_service.dart';
import '../data/services/spotify_importer_service.dart';
import '../data/services/download_notification_service.dart';
import '../ui/features/library/artist_detail_screen.dart';

enum SpotifySyncState { idle, syncing, playing, error }

class MusicProvider extends ChangeNotifier {
  final MusicRepository _musicRepository;

  // Feeds
  List<Album> _newestAlbums = [];
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
  List<SpotifyTrackItem> _spotifySearchTracks = [];
  List<String> _recentSearches = [];
  bool _isSearching = false;
  bool _isSearchingSpotify = false;
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
  List<Album> get newestAlbums => _newestAlbums;
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
  List<SpotifyTrackItem> get spotifySearchTracks => _spotifySearchTracks;
  List<String> get recentSearches => _recentSearches;
  bool get isSearching => _isSearching;
  bool get isSearchingSpotify => _isSearchingSpotify;
  String get activeFilter => _activeFilter;
  bool get isLoadingHome => _isLoadingHome;
  bool get isLoadingLibrary => _isLoadingLibrary;
  String? get homeError => _homeError;

  String? get downloadingEntityId => _downloadingEntityId;
  double get downloadingProgress => _downloadingProgress;

  String getCoverArtUrl(
    String? coverArtId, {
    int size = 500,
    String? playlistId,
    String? playlistName,
    String? albumName,
    int? songCount,
  }) =>
      _musicRepository.getCoverArtUrl(
        coverArtId,
        size: size,
        playlistId: playlistId,
        playlistName: playlistName,
        albumName: albumName,
        songCount: songCount,
      );

  Future<void> savePlaylistCover(String idOrName, String url) async {
    await _musicRepository.savePlaylistCover(idOrName, url);
    notifyListeners();
  }

  String? getCustomPlaylistCover(String idOrName) {
    return _musicRepository.getPlaylistCover(idOrName);
  }

  Future<void> saveImportedPlaylistTracks(String idOrName, List<SpotifyTrackItem> tracks) async {
    await _musicRepository.saveImportedPlaylistTracks(idOrName, tracks);
    notifyListeners();
  }

  List<SpotifyTrackItem> getImportedPlaylistTracks(String idOrName) {
    return _musicRepository.getImportedPlaylistTracks(idOrName);
  }

  void setFilter(String filter) {
    _activeFilter = filter;
    notifyListeners();
  }

  Future<void> loadHomeFeed({bool showLoadingSkeleton = false}) async {
    if (showLoadingSkeleton || (_newestAlbums.isEmpty && _recentAlbums.isEmpty)) {
      _isLoadingHome = true;
      _homeError = null;
      notifyListeners();
    }

    try {
      final newest = await _musicRepository.getNewestAlbums(size: 30);
      final recent = await _musicRepository.getRecentAlbums(size: 20);
      final frequent = await _musicRepository.getFrequentAlbums(size: 20);
      final starred = await _musicRepository.getStarredTracks();
      final artists = await _musicRepository.getArtists();

      _newestAlbums = newest;
      // Fallback: If user has no recent played albums yet, fallback to newest so Home is never empty!
      _recentAlbums = recent.isNotEmpty ? recent : newest;
      _frequentAlbums = frequent.isNotEmpty ? frequent : newest;
      _starredTracks = starred;
      _artists = _sanitizeArtists(artists);
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
      _artists = _sanitizeArtists(artists);
      _starredTracks = starred;
      _offlineTracks = _musicRepository.getDownloadedTracks();
    } catch (_) {
    } finally {
      _isLoadingLibrary = false;
      notifyListeners();
    }
  }

  /// Decomposes compound artist entries (e.g. "dizzytooskinny, marwan pablo") into individual artists
  List<Artist> _sanitizeArtists(List<Artist> rawArtists) {
    final Map<String, Artist> cleanMap = {};
    final separator = RegExp(r'\s*(?:,|/|;|&|\bfeat\.?|\bft\.?|\bwith\b)\s*', caseSensitive: false);

    for (final artist in rawArtists) {
      final name = artist.name.trim();
      if (separator.hasMatch(name)) {
        // Compound artist entry
        final subNames = name
            .split(separator)
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty && !s.toLowerCase().startsWith('feat') && !s.toLowerCase().startsWith('ft'))
            .toList();

        for (final sub in subNames) {
          final key = sub.toLowerCase();
          if (!cleanMap.containsKey(key)) {
            cleanMap[key] = Artist(
              id: 'sub_${artist.id}_${sub.hashCode.abs()}',
              name: sub,
              coverArtId: artist.coverArtId,
              artistImageUrl: artist.artistImageUrl,
              albumCount: 1,
            );
          }
        }
      } else {
        final key = name.toLowerCase();
        if (!cleanMap.containsKey(key)) {
          cleanMap[key] = artist;
        }
      }
    }

    return cleanMap.values.toList();
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
    try {
      if (!artistId.startsWith('sub_')) {
        final artist = await _musicRepository.getArtist(artistId);
        _artistCache[artistId] = artist;
        return artist;
      }
    } catch (_) {}

    // Fallback for decomposed sub-artists: query tracks and albums matching artist name
    final found = _artists.where((a) => a.id == artistId).firstOrNull;
    String artistName = found?.name ?? '';
    if (artistName.isEmpty) {
      if (artistId.startsWith('sub_name_')) {
        artistName = Uri.decodeComponent(artistId.substring('sub_name_'.length));
      } else {
        artistName = artistId;
      }
    }
    try {
      final searchRes = await _musicRepository.search(artistName);
      final tracks = (searchRes['tracks'] as List<Track>?) ?? [];
      final albums = (searchRes['albums'] as List<Album>?) ?? [];
      final artist = Artist(
        id: artistId,
        name: artistName,
        coverArtId: tracks.isNotEmpty ? tracks.first.coverArtId : null,
        albumCount: albums.length,
        albums: albums,
        topTracks: tracks,
      );
      _artistCache[artistId] = artist;
      return artist;
    } catch (_) {
      final fallback = Artist(id: artistId, name: artistName);
      _artistCache[artistId] = fallback;
      return fallback;
    }
  }

  Future<void> openArtistByName(BuildContext context, String artistName) async {
    final clean = artistName.trim();
    if (clean.isEmpty) return;

    // 1. Check if directly in _artists list
    for (final a in _artists) {
      if (a.name.toLowerCase() == clean.toLowerCase()) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ArtistDetailScreen(artistId: a.id)),
        );
        return;
      }
    }

    // 2. Search Subsonic for this artist entity
    try {
      final searchRes = await _musicRepository.search(clean);
      final searchArtists = (searchRes['artists'] as List<Artist>?) ?? [];
      if (searchArtists.isNotEmpty) {
        final matched = searchArtists.firstWhere(
          (a) => a.name.toLowerCase() == clean.toLowerCase(),
          orElse: () => searchArtists.first,
        );
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ArtistDetailScreen(artistId: matched.id)),
        );
        return;
      }
    } catch (_) {}

    // 3. Fallback: navigate using sub_name_ ID with artist name
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ArtistDetailScreen(artistId: 'sub_name_${Uri.encodeComponent(clean)}')),
    );
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
  int _activeSearchId = 0;
  int _activeSpotifySearchId = 0;

  void searchDebounced(String query) {
    _searchDebounce?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      search('');
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      search(query);
    });
  }

  Future<void> search(String query) async {
    final currentId = ++_activeSearchId;
    final trimmed = query.trim();
    _spotifySearchTracks = []; // Clear previous Spotify results immediately!

    if (trimmed.isEmpty) {
      _searchTracks = [];
      _searchAlbums = [];
      _searchArtists = [];
      _searchPlaylists = [];
      _isSearching = false;
      _isSearchingSpotify = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    // Trigger fresh Spotify catalog search in parallel for this query
    searchSpotify(trimmed);

    try {
      final res = await _musicRepository.search(trimmed);
      if (_activeSearchId != currentId) return;

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
      if (_activeSearchId == currentId) {
        _isSearching = false;
        notifyListeners();
      }
    }
  }

  Future<void> searchSpotify(String query) async {
    final currentId = ++_activeSpotifySearchId;
    final trimmed = query.trim();
    _spotifySearchTracks = []; // Always clear before new query

    if (trimmed.isEmpty) {
      _isSearchingSpotify = false;
      notifyListeners();
      return;
    }

    _isSearchingSpotify = true;
    notifyListeners();

    try {
      final results = await _musicRepository.searchSpotifyTracks(trimmed);
      if (_activeSpotifySearchId != currentId) return; // Discard stale responses
      _spotifySearchTracks = results;
    } catch (_) {
      if (_activeSpotifySearchId == currentId) {
        _spotifySearchTracks = [];
      }
    } finally {
      if (_activeSpotifySearchId == currentId) {
        _isSearchingSpotify = false;
        notifyListeners();
      }
    }
  }

  final Map<String, SpotifySyncState> _spotifyTrackSyncStates = {};
  final Map<String, double> _spotifyTrackSyncProgress = {};
  final Map<String, String> _spotifyTrackSyncMessages = {};
  SpotifyTrackItem? _activeSyncingItem;

  SpotifySyncState getSpotifySyncState(String trackId) => _spotifyTrackSyncStates[trackId] ?? SpotifySyncState.idle;
  double getSpotifySyncProgress(String trackId) => _spotifyTrackSyncProgress[trackId] ?? 0.0;
  String? getSpotifySyncMessage(String trackId) => _spotifyTrackSyncMessages[trackId];
  SpotifyTrackItem? get activeSyncingItem => _activeSyncingItem;

  Future<Track?> convertAndSyncSpotifyTrack(SpotifyTrackItem spotifyItem) async {
    final trackId = spotifyItem.id;
    _spotifyTrackSyncStates[trackId] = SpotifySyncState.syncing;
    _spotifyTrackSyncProgress[trackId] = 0.40;
    _spotifyTrackSyncMessages[trackId] = 'Syncing "${spotifyItem.title}"...';
    _activeSyncingItem = spotifyItem;
    notifyListeners();

    try {
      _spotifyTrackSyncProgress[trackId] = 0.75;
      _spotifyTrackSyncMessages[trackId] = 'Connecting stream...';
      notifyListeners();

      final track = await _musicRepository.createTrackFromSpotifyItem(spotifyItem);

      _spotifyTrackSyncProgress[trackId] = 1.0;
      _spotifyTrackSyncStates[trackId] = SpotifySyncState.playing;
      _spotifyTrackSyncMessages[trackId] = 'Playing • Syncing in background';
      notifyListeners();

      // Clear active banner after brief feedback
      Future.delayed(const Duration(seconds: 3), () {
        if (_activeSyncingItem?.id == trackId) {
          _activeSyncingItem = null;
          notifyListeners();
        }
      });

      return track;
    } catch (e) {
      _spotifyTrackSyncStates[trackId] = SpotifySyncState.error;
      _spotifyTrackSyncMessages[trackId] = 'Failed to load audio. Tap to retry.';
      notifyListeners();
      return null;
    }
  }

  void dismissActiveSyncBanner() {
    _activeSyncingItem = null;
    notifyListeners();
  }

  Future<void> removeRecentSearch(String query) async {
    await _musicRepository.removeRecentSearch(query);
    _recentSearches = _musicRepository.getRecentSearches();
    notifyListeners();
  }

  Future<void> clearRecentSearches() async {
    await _musicRepository.clearRecentSearches();
    _recentSearches = [];
    _spotifySearchTracks = [];
    notifyListeners();
  }

  // ================= Star / Like =================
  final Set<String> _starringInFlight = {};

  bool isTrackStarred(String trackId) => _starredTracks.any((t) => t.id == trackId);

  Future<void> toggleStar(Track track) async {
    if (_starringInFlight.contains(track.id)) return;
    _starringInFlight.add(track.id);

    final currentlyStarred = isTrackStarred(track.id);
    final targetStarred = !currentlyStarred;

    // Remove duplicates and apply optimistic update
    _starredTracks.removeWhere((t) => t.id == track.id);
    if (targetStarred) {
      _starredTracks.insert(0, track.copyWith(isStarred: true));
    }
    notifyListeners();

    try {
      if (targetStarred) {
        await _musicRepository.starTrack(track.id);
      } else {
        await _musicRepository.unstarTrack(track.id);
      }
    } catch (_) {
      // Revert if failed
      _starredTracks.removeWhere((t) => t.id == track.id);
      if (currentlyStarred) {
        _starredTracks.insert(0, track.copyWith(isStarred: true));
      }
      notifyListeners();
    } finally {
      _starringInFlight.remove(track.id);
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

  Future<Playlist> syncPlaylistWithVault(String playlistId) async {
    final updated = await _musicRepository.syncPlaylistTracksWithVault(playlistId);
    _playlistCache[playlistId] = updated;
    notifyListeners();
    return updated;
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
    _downloadingEntityId = track.id;
    _downloadingProgress = 0.05;
    notifyListeners();

    // Initial notification
    await DownloadNotificationService.updateProgress(
      id: track.id,
      title: track.title,
      artist: track.artist,
      progress: 5,
      isIndeterminate: true,
    );

    try {
      final offlineTrack = await _musicRepository.downloadTrack(
        track,
        onProgress: (received, total) {
          if (total > 0) {
            final p = (received / total).clamp(0.05, 1.0);
            _downloadingProgress = p;
            notifyListeners();
            final percent = (p * 100).toInt();
            DownloadNotificationService.updateProgress(
              id: track.id,
              title: track.title,
              artist: track.artist,
              progress: percent,
              isIndeterminate: false,
            );
          }
        },
      );
      _offlineTracks.removeWhere((t) => t.id == track.id);
      _offlineTracks.insert(0, offlineTrack);

      await DownloadNotificationService.complete(
        id: track.id,
        title: track.title,
        artist: track.artist,
      );
    } catch (e) {
      print('[MusicProvider] Failed to download track: $e');
      await DownloadNotificationService.cancel(track.id);
    } finally {
      if (_downloadingEntityId == track.id) {
        _downloadingEntityId = null;
        _downloadingProgress = 0.0;
      }
      notifyListeners();
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
