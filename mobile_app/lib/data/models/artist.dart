import 'album.dart';

class Artist {
  final String id;
  final String name;
  final String? coverArtId;
  final String? artistImageUrl;
  final int albumCount;
  final bool isStarred;
  final List<Album> albums;

  const Artist({
    required this.id,
    required this.name,
    this.coverArtId,
    this.artistImageUrl,
    this.albumCount = 0,
    this.isStarred = false,
    this.albums = const [],
  });

  factory Artist.fromSubsonicJson(Map<String, dynamic> json) {
    final albumListRaw = json['album'];
    List<Album> parsedAlbums = [];
    if (albumListRaw is List) {
      parsedAlbums = albumListRaw
          .whereType<Map<String, dynamic>>()
          .map((e) => Album.fromSubsonicJson(e))
          .toList();
    }

    return Artist(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown Artist',
      coverArtId: json['coverArt']?.toString(),
      artistImageUrl: json['artistImageUrl']?.toString(),
      albumCount: (json['albumCount'] as num?)?.toInt() ?? parsedAlbums.length,
      isStarred: json['starred'] != null,
      albums: parsedAlbums,
    );
  }
}
