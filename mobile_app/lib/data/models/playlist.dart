import 'track.dart';

class Playlist {
  final String id;
  final String name;
  final String? comment;
  final String? owner;
  final bool isPublic;
  final int songCount;
  final int duration; // In seconds
  final String? coverArtId;
  final List<Track> tracks;

  const Playlist({
    required this.id,
    required this.name,
    this.comment,
    this.owner,
    this.isPublic = true,
    this.songCount = 0,
    this.duration = 0,
    this.coverArtId,
    this.tracks = const [],
  });

  factory Playlist.fromSubsonicJson(Map<String, dynamic> json) {
    final entryListRaw = json['entry'];
    List<Track> parsedTracks = [];
    if (entryListRaw is List) {
      parsedTracks = entryListRaw
          .whereType<Map<String, dynamic>>()
          .map((e) => Track.fromSubsonicJson(e))
          .toList();
    }

    return Playlist(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unnamed Playlist',
      comment: json['comment']?.toString(),
      owner: json['owner']?.toString(),
      isPublic: json['public'] as bool? ?? true,
      songCount: (json['songCount'] as num?)?.toInt() ?? parsedTracks.length,
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      coverArtId: json['coverArt']?.toString(),
      tracks: parsedTracks,
    );
  }
}
