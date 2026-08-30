import 'package:flutter/foundation.dart';
import '../data/models/album.dart';
import '../data/models/artist.dart';
import '../data/models/playlist.dart';
import '../data/models/track.dart';
import '../data/repositories/music_repository.dart';

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
  bool _isSearching = false;

  // Active Pill
  String _activeFilter = 'all'; // 'all', 'music', 'radio'

  // Loading States
  bool _isLoadingHome = false;
  bool _isLoadingLibrary = false;
  String? _homeError;

  MusicProvider({required MusicRepository musicRepository})
      : _musicRepository = musicRepository;

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
  bool get isSearching => _isSearching;
  String get activeFilter => _activeFilter;
  bool get isLoadingHome => _isLoadingHome;
  bool get isLoadingLibrary => _isLoadingLibrary;
  String? get homeError => _homeError;

  String getCoverArtUrl(String? coverArtId, {int size = 500}) =>
      _musicRepository.getCoverArtUrl(coverArtId, size: size);

  void setFilter(String filter) {
    _activeFilter = filter;
    notifyListeners();
  }

  Future<void> loadHomeFeed() async {
    _isLoadingHome = true;
    _homeError = null;
    notifyListeners();

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

  Future<void> loadLibrary() async {
    _isLoadingLibrary = true;
    notifyListeners();

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

  Future<Album> getAlbumDetails(String albumId) {
    return _musicRepository.getAlbum(albumId);
  }

  Future<Artist> getArtistDetails(String artistId) {
    return _musicRepository.getArtist(artistId);
  }

  Future<Playlist> getPlaylistDetails(String playlistId) {
    return _musicRepository.getPlaylist(playlistId);
  }

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      _searchTracks = [];
      _searchAlbums = [];
      _searchArtists = [];
      _isSearching = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    try {
      final res = await _musicRepository.search(query);
      _searchTracks = res['songs'] as List<Track>? ?? [];
      _searchAlbums = res['albums'] as List<Album>? ?? [];
      _searchArtists = res['artists'] as List<Artist>? ?? [];
    } catch (_) {
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

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
}
