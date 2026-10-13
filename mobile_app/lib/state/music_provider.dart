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

enum SpotifySyncState { idle, syncing, error }

String normalizeArtistName(String name) {
  final trimmed = name.trim();
  if (RegExp(r'[\u0600-\u06ff]').hasMatch(trimmed)) return trimmed;
  const accents = 'àáâãäåāçćčďèéêëēěìíîïīñńòóôõöøōřśšùúûüūýÿžźż';
  const plain = 'aaaaaaacccdeeeeeeiiiiinnooooooorssuuuuuyyzzz';
  final lower =
      trimmed.toLowerCase().replaceAll(RegExp(r'[\u0300-\u036f]'), '');
  final folded = lower.split('').map((letter) {
    final index = accents.indexOf(letter);
    return index < 0 ? letter : plain[index];
  }).join();
  return folded
      .replaceAll(
          RegExp(r'''[!"#\$%&'()*+,\-./:;<=>?@\[\\\]^_`{|}~\u2000-\u206f]'''),
          ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

List<String> splitArtistNames(String name) => name
    .split(RegExp(r'\s*(?:,|;|\bfeat\.?|\bft\.?|\bwith\b)\s*',
        caseSensitive: false))
    .map((part) => part.trim())
    .where((part) => part.isNotEmpty)
    .toList();

bool _trackMatchesArtist(Track track, Artist artist) {
  if (!artist.id.startsWith('sub_') && track.artistId == artist.id) return true;
  final name = normalizeArtistName(artist.name);
  return name.isNotEmpty &&
      splitArtistNames(track.artist)
          .any((part) => normalizeArtistName(part) == name);
}

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

    for (final artist in rawArtists) {
      final name = artist.name.trim();
      final subNames = splitArtistNames(name);
      if (subNames.length > 1) {
        for (final sub in subNames) {
          final key = normalizeArtistName(sub);
          cleanMap.putIfAbsent(
            key,
            () => Artist(
              id: 'sub_split_${Uri.encodeComponent(artist.id)}|${Uri.encodeComponent(sub)}',
              name: sub,
              coverArtId: artist.coverArtId,
              artistImageUrl: artist.artistImageUrl,
              albumCount: 1,
            ),
          );
        }
      } else {
        cleanMap[normalizeArtistName(name)] = artist;
      }
    }

    return cleanMap.values.toList();
  }

  // In-memory detail caches to eliminate redundant network requests and UI flickering
  final Map<String, Album> _albumCache = {};
  final Map<String, Artist> _artistCache = {};
  final Map<String, List<Track>> _artistLibraryTracksCache = {};
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

  Future<Artist> getArtistDetails(String artistId,
      {bool forceRefresh = false}) async {
    if (forceRefresh) {
      _artistCache.remove(artistId);
      _artistLibraryTracksCache.remove(artistId);
    }
    if (!forceRefresh && _artistCache.containsKey(artistId)) {
      return _artistCache[artistId]!;
    }
    if (!artistId.startsWith('sub_')) {
      final artist = await _musicRepository.getArtist(artistId);
      if (artist.id != artistId || artist.name.trim().isEmpty) {
        throw StateError('Invalid artist details for $artistId');
      }
      _artistCache[artistId] = artist;
      return artist;
    }

    final found = _artists.where((a) => a.id == artistId).firstOrNull;
    final artistName = artistId.startsWith('sub_name_')
        ? Uri.decodeComponent(artistId.substring('sub_name_'.length))
        : artistId.startsWith('sub_split_') && artistId.contains('|')
            ? Uri.decodeComponent(artistId.substring(artistId.indexOf('|') + 1))
            : found?.name;
    if (artistName == null || artistName.isEmpty) {
      throw StateError('Artist name unavailable for $artistId');
    }
    final selected = Artist(id: artistId, name: artistName);
    final searchRes = await _musicRepository.searchArtistLibrary(artistName);
    final tracks = ((searchRes['songs'] as List<Track>?) ?? [])
        .where((track) => _trackMatchesArtist(track, selected))
        .toList();
    final albums = ((searchRes['albums'] as List<Album>?) ?? [])
        .where((album) => splitArtistNames(album.artist).any((part) =>
            normalizeArtistName(part) == normalizeArtistName(artistName)))
        .toList();
    final artist = selected.copyWith(
      coverArtId:
          tracks.isNotEmpty ? tracks.first.coverArtId : found?.coverArtId,
      albumCount: albums.length,
      albums: albums,
      topTracks: tracks,
    );
    _artistCache[artistId] = artist;
    _artistLibraryTracksCache[artistId] = tracks;
    return artist;
  }

  Future<List<Track>> getArtistLibraryTracks(Artist artist) async {
    final cached = _artistLibraryTracksCache[artist.id];
    if (cached != null) return cached;
    final details = await getArtistDetails(artist.id);
    if (artist.id.startsWith('sub_')) {
      return _artistLibraryTracksCache[artist.id] ?? details.topTracks;
    }
    final tracks = <Track>[];
    for (var i = 0; i < details.albums.length; i += 4) {
      final batch = details.albums.skip(i).take(4);
      final albums = await Future.wait(
          batch.map((album) => _musicRepository.getAlbum(album.id)));
      for (final album in albums) {
        tracks.addAll(album.tracks);
      }
    }
    final unique =
        {for (final track in tracks) track.id: track}.values.toList();
    _artistLibraryTracksCache[artist.id] = unique;
    return unique;
  }

  Future<void> openArtistByName(BuildContext context, String artistName) async {
    final clean = artistName.trim();
    if (clean.isEmpty) return;

    // 1. Check if directly in _artists list
    for (final a in _artists) {
      if (normalizeArtistName(a.name) == normalizeArtistName(clean)) {
        if (!context.mounted) return;
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
      final matched = searchArtists
          .where(
            (a) => normalizeArtistName(a.name) == normalizeArtistName(clean),
          )
          .firstOrNull;
      if (matched != null) {
        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ArtistDetailScreen(artistId: matched.id)),
        );
        return;
      }
    } catch (_) {}

    // 3. Fallback: navigate using sub_name_ ID with artist name
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => ArtistDetailScreen(
              artistId: 'sub_name_${Uri.encodeComponent(clean)}')),
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

  Future<ArtistCatalog> getArtistCatalog(String artistName) {
    return _musicRepository.getArtistCatalog(artistName);
  }

  Future<Track?> convertAndSyncSpotifyTrack(SpotifyTrackItem spotifyItem) async {
    final trackId = spotifyItem.id;
    if (_spotifyTrackSyncStates[trackId] == SpotifySyncState.syncing) {
      return null;
    }

    _spotifyTrackSyncStates[trackId] = SpotifySyncState.syncing;
    _spotifyTrackSyncProgress[trackId] = 0.0;
    _spotifyTrackSyncMessages[trackId] = 'Syncing "${spotifyItem.title}"...';
    _activeSyncingItem = spotifyItem;
    notifyListeners();

    Timer? pollTimer;
    bool isCancelled = false;
    bool isPollInProgress = false;

    try {
      pollTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
        if (isCancelled || _spotifyTrackSyncStates[trackId] != SpotifySyncState.syncing) {
          timer.cancel();
          return;
        }

        if (isPollInProgress) return;
        isPollInProgress = true;

        try {
          final progress = await _musicRepository.getImportProgress(
            title: spotifyItem.title,
            artist: spotifyItem.artist,
          );

          if (isCancelled || _spotifyTrackSyncStates[trackId] != SpotifySyncState.syncing) {
            return;
          }

          if (progress == null || progress.stage == 'idle') {
            return;
          }

          final newProgress = (progress.percent / 100.0).clamp(0.0, 1.0);
          final String newMessage;
          switch (progress.stage) {
            case 'searching':
              newMessage = 'Finding the right version...';
              break;
            case 'downloading':
              newMessage = 'Downloading ${progress.percent}%';
              break;
            case 'processing':
              newMessage = 'Adding lyrics and artwork...';
              break;
            case 'ready':
              newMessage = 'Starting playback...';
              break;
            default:
              newMessage = progress.message.isNotEmpty
                  ? progress.message
                  : (_spotifyTrackSyncMessages[trackId] ?? 'Syncing...');
          }

          final currentProgress = _spotifyTrackSyncProgress[trackId] ?? 0.0;
          final currentMessage = _spotifyTrackSyncMessages[trackId] ?? '';

          if (currentProgress != newProgress || currentMessage != newMessage) {
            _spotifyTrackSyncProgress[trackId] = newProgress;
            _spotifyTrackSyncMessages[trackId] = newMessage;
            notifyListeners();
          }
        } catch (_) {
          // Ignore polling errors
        } finally {
          isPollInProgress = false;
        }
      });

      final track = await _musicRepository.createTrackFromSpotifyItem(spotifyItem);

      _spotifyTrackSyncProgress[trackId] = 1.0;
      _spotifyTrackSyncStates[trackId] = SpotifySyncState.idle;
      _spotifyTrackSyncMessages[trackId] = 'Playing';
      notifyListeners();

      // Clear active banner and progress/message entries after brief feedback
      Future.delayed(const Duration(seconds: 3), () {
        if (_activeSyncingItem?.id == trackId) {
          _activeSyncingItem = null;
        }
        _spotifyTrackSyncStates.remove(trackId);
        _spotifyTrackSyncProgress.remove(trackId);
        _spotifyTrackSyncMessages.remove(trackId);
        notifyListeners();
      });

      return track;
    } catch (e) {
      _spotifyTrackSyncStates[trackId] = SpotifySyncState.error;
      _spotifyTrackSyncProgress[trackId] = 0.0;
      _spotifyTrackSyncMessages[trackId] = 'Failed to load audio. Tap to retry.';
      notifyListeners();
      return null;
    } finally {
      isCancelled = true;
      pollTimer?.cancel();
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
