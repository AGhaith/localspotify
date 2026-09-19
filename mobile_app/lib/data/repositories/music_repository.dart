import '../models/album.dart';
import '../models/artist.dart';
import '../models/lyrics.dart';
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
    return _apiService.getLyrics(
      songId: track.id,
      artist: track.artist,
      title: track.title,
    );
  }

  Future<List<Playlist>> getPlaylists() {
    return _apiService.getPlaylists();
  }

  Future<Playlist> getPlaylist(String playlistId) {
    return _apiService.getPlaylist(playlistId);
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

  // ================= Offline & Storage Handling =================
  List<Track> getDownloadedTracks() {
    return _storageService.getDownloadedTracks();
  }

  bool isTrackDownloaded(String trackId) {
    return _storageService.isTrackDownloaded(trackId);
  }

  Future<Track> downloadTrack(Track track, {void Function(int, int)? onProgress}) {
    final streamUrl = _apiService.getStreamUrl(track.id);
    final coverArtUrl = _apiService.getCoverArtUrl(track.coverArtId, size: 500);
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
}
