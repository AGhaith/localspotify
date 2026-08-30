import '../models/album.dart';
import '../models/artist.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../services/subsonic_api_service.dart';
import '../services/offline_storage_service.dart';

class MusicRepository {
  final SubsonicApiService _apiService;
  final OfflineStorageService _storageService;

  MusicRepository({
    required SubsonicApiService apiService,
    required OfflineStorageService storageService,
  })  : _apiService = apiService,
        _storageService = storageService;

  String getCoverArtUrl(String? coverArtId, {int size = 500}) {
    return _apiService.getCoverArtUrl(coverArtId, size: size);
  }

  String getStreamUrl(String trackId) {
    return _apiService.getStreamUrl(trackId);
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

  Future<Artist> getArtist(String artistId) {
    return _apiService.getArtist(artistId);
  }

  Future<List<Playlist>> getPlaylists() {
    return _apiService.getPlaylists();
  }

  Future<Playlist> getPlaylist(String playlistId) {
    return _apiService.getPlaylist(playlistId);
  }

  Future<List<Track>> getStarredTracks() {
    return _apiService.getStarredTracks();
  }

  Future<void> toggleStarTrack(Track track) async {
    if (track.isStarred) {
      await _apiService.unstarItem(songId: track.id);
    } else {
      await _apiService.starItem(songId: track.id);
    }
  }

  Future<Map<String, dynamic>> search(String query) {
    return _apiService.search(query);
  }

  Future<void> scrobble(String trackId) {
    return _apiService.scrobble(trackId);
  }

  // ================= Offline Handling =================
  List<Track> getDownloadedTracks() {
    return _storageService.getDownloadedTracks();
  }

  bool isTrackDownloaded(String trackId) {
    return _storageService.isTrackDownloaded(trackId);
  }

  Future<Track> downloadTrack(Track track, {void Function(int, int)? onProgress}) {
    final streamUrl = _apiService.getStreamUrl(track.id);
    return _storageService.downloadTrack(
      track: track,
      downloadUrl: streamUrl,
      onProgress: onProgress,
    );
  }

  Future<void> deleteDownloadedTrack(String trackId) {
    return _storageService.deleteDownloadedTrack(trackId);
  }
}
