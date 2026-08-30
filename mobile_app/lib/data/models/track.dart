import 'package:audio_service/audio_service.dart';

class Track {
  final String id;
  final String title;
  final String artist;
  final String? artistId;
  final String album;
  final String? albumId;
  final int duration; // In seconds
  final String? coverArtId;
  final String? path;
  final int? trackNumber;
  final int? discNumber;
  final int? year;
  final String? genre;
  final int? bitRate;
  final String? suffix; // e.g. mp3, flac, m4a
  final bool isStarred;
  final bool isOffline;
  final String? localAudioPath;

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    this.artistId,
    required this.album,
    this.albumId,
    required this.duration,
    this.coverArtId,
    this.path,
    this.trackNumber,
    this.discNumber,
    this.year,
    this.genre,
    this.bitRate,
    this.suffix,
    this.isStarred = false,
    this.isOffline = false,
    this.localAudioPath,
  });

  Track copyWith({
    String? id,
    String? title,
    String? artist,
    String? artistId,
    String? album,
    String? albumId,
    int? duration,
    String? coverArtId,
    String? path,
    int? trackNumber,
    int? discNumber,
    int? year,
    String? genre,
    int? bitRate,
    String? suffix,
    bool? isStarred,
    bool? isOffline,
    String? localAudioPath,
  }) {
    return Track(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      artistId: artistId ?? this.artistId,
      album: album ?? this.album,
      albumId: albumId ?? this.albumId,
      duration: duration ?? this.duration,
      coverArtId: coverArtId ?? this.coverArtId,
      path: path ?? this.path,
      trackNumber: trackNumber ?? this.trackNumber,
      discNumber: discNumber ?? this.discNumber,
      year: year ?? this.year,
      genre: genre ?? this.genre,
      bitRate: bitRate ?? this.bitRate,
      suffix: suffix ?? this.suffix,
      isStarred: isStarred ?? this.isStarred,
      isOffline: isOffline ?? this.isOffline,
      localAudioPath: localAudioPath ?? this.localAudioPath,
    );
  }

  factory Track.fromSubsonicJson(Map<String, dynamic> json) {
    return Track(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Unknown Title',
      artist: json['artist']?.toString() ?? 'Unknown Artist',
      artistId: json['artistId']?.toString(),
      album: json['album']?.toString() ?? 'Unknown Album',
      albumId: json['albumId']?.toString(),
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      coverArtId: json['coverArt']?.toString(),
      path: json['path']?.toString(),
      trackNumber: (json['track'] as num?)?.toInt(),
      discNumber: (json['discNumber'] as num?)?.toInt(),
      year: (json['year'] as num?)?.toInt(),
      genre: json['genre']?.toString(),
      bitRate: (json['bitRate'] as num?)?.toInt(),
      suffix: json['suffix']?.toString(),
      isStarred: json['starred'] != null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'artistId': artistId,
        'album': album,
        'albumId': albumId,
        'duration': duration,
        'coverArtId': coverArtId,
        'path': path,
        'trackNumber': trackNumber,
        'discNumber': discNumber,
        'year': year,
        'genre': genre,
        'bitRate': bitRate,
        'suffix': suffix,
        'isStarred': isStarred,
        'isOffline': isOffline,
        'localAudioPath': localAudioPath,
      };

  factory Track.fromJson(Map<String, dynamic> json) => Track(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        artist: json['artist']?.toString() ?? '',
        artistId: json['artistId']?.toString(),
        album: json['album']?.toString() ?? '',
        albumId: json['albumId']?.toString(),
        duration: (json['duration'] as num?)?.toInt() ?? 0,
        coverArtId: json['coverArtId']?.toString(),
        path: json['path']?.toString(),
        trackNumber: (json['trackNumber'] as num?)?.toInt(),
        discNumber: (json['discNumber'] as num?)?.toInt(),
        year: (json['year'] as num?)?.toInt(),
        genre: json['genre']?.toString(),
        bitRate: (json['bitRate'] as num?)?.toInt(),
        suffix: json['suffix']?.toString(),
        isStarred: json['isStarred'] as bool? ?? false,
        isOffline: json['isOffline'] as bool? ?? false,
        localAudioPath: json['localAudioPath']?.toString(),
      );

  MediaItem toMediaItem({required Uri audioUri, Uri? artUri}) {
    return MediaItem(
      id: id,
      album: album,
      title: title,
      artist: artist,
      duration: Duration(seconds: duration),
      artUri: artUri,
      extras: {
        'url': audioUri.toString(),
        'isOffline': isOffline,
        'localAudioPath': localAudioPath,
        'trackNumber': trackNumber,
      },
    );
  }
}
