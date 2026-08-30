import 'track.dart';

class Album {
  final String id;
  final String name;
  final String artist;
  final String? artistId;
  final String? coverArtId;
  final int songCount;
  final int duration; // In seconds
  final int? year;
  final String? genre;
  final bool isStarred;
  final List<Track> tracks;

  const Album({
    required this.id,
    required this.name,
    required this.artist,
    this.artistId,
    this.coverArtId,
    this.songCount = 0,
    this.duration = 0,
    this.year,
    this.genre,
    this.isStarred = false,
    this.tracks = const [],
  });

  factory Album.fromSubsonicJson(Map<String, dynamic> json) {
    final songListRaw = json['song'];
    List<Track> parsedTracks = [];
    if (songListRaw is List) {
      parsedTracks = songListRaw
          .whereType<Map<String, dynamic>>()
          .map((e) => Track.fromSubsonicJson(e))
          .toList();
    }

    return Album(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['title']?.toString() ?? 'Unknown Album',
      artist: json['artist']?.toString() ?? 'Unknown Artist',
      artistId: json['artistId']?.toString(),
      coverArtId: json['coverArt']?.toString(),
      songCount: (json['songCount'] as num?)?.toInt() ?? parsedTracks.length,
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      year: (json['year'] as num?)?.toInt(),
      genre: json['genre']?.toString(),
      isStarred: json['starred'] != null,
      tracks: parsedTracks,
    );
  }

  Album copyWith({
    String? id,
    String? name,
    String? artist,
    String? artistId,
    String? coverArtId,
    int? songCount,
    int? duration,
    int? year,
    String? genre,
    bool? isStarred,
    List<Track>? tracks,
  }) {
    return Album(
      id: id ?? this.id,
      name: name ?? this.name,
      artist: artist ?? this.artist,
      artistId: artistId ?? this.artistId,
      coverArtId: coverArtId ?? this.coverArtId,
      songCount: songCount ?? this.songCount,
      duration: duration ?? this.duration,
      year: year ?? this.year,
      genre: genre ?? this.genre,
      isStarred: isStarred ?? this.isStarred,
      tracks: tracks ?? this.tracks,
    );
  }
}
