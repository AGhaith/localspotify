import 'album.dart';
import 'track.dart';

class Artist {
  final String id;
  final String name;
  final String? coverArtId;
  final String? artistImageUrl;
  final int albumCount;
  final bool isStarred;
  final String? biography;
  final String? musicBrainzId;
  final List<Artist> similarArtists;
  final List<Album> albums;
  final List<Track> topTracks;

  const Artist({
    required this.id,
    required this.name,
    this.coverArtId,
    this.artistImageUrl,
    this.albumCount = 0,
    this.isStarred = false,
    this.biography,
    this.musicBrainzId,
    this.similarArtists = const [],
    this.albums = const [],
    this.topTracks = const [],
  });

  Artist copyWith({
    String? id,
    String? name,
    String? coverArtId,
    String? artistImageUrl,
    int? albumCount,
    bool? isStarred,
    String? biography,
    String? musicBrainzId,
    List<Artist>? similarArtists,
    List<Album>? albums,
    List<Track>? topTracks,
  }) {
    return Artist(
      id: id ?? this.id,
      name: name ?? this.name,
      coverArtId: coverArtId ?? this.coverArtId,
      artistImageUrl: artistImageUrl ?? this.artistImageUrl,
      albumCount: albumCount ?? this.albumCount,
      isStarred: isStarred ?? this.isStarred,
      biography: biography ?? this.biography,
      musicBrainzId: musicBrainzId ?? this.musicBrainzId,
      similarArtists: similarArtists ?? this.similarArtists,
      albums: albums ?? this.albums,
      topTracks: topTracks ?? this.topTracks,
    );
  }

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

  factory Artist.fromArtistInfoJson({
    required Artist baseArtist,
    required Map<String, dynamic> infoJson,
  }) {
    final similarRaw = infoJson['similarArtist'];
    final List<Artist> similar = [];
    if (similarRaw is List) {
      for (final s in similarRaw) {
        if (s is Map<String, dynamic>) {
          similar.add(Artist(
            id: s['id']?.toString() ?? '',
            name: s['name']?.toString() ?? '',
            coverArtId: s['coverArt']?.toString(),
            artistImageUrl: s['artistImageUrl']?.toString(),
          ));
        }
      }
    }

    return baseArtist.copyWith(
      biography: infoJson['biography']?.toString(),
      musicBrainzId: infoJson['musicBrainzId']?.toString(),
      artistImageUrl: infoJson['largeImageUrl']?.toString() ??
          infoJson['mediumImageUrl']?.toString() ??
          baseArtist.artistImageUrl,
      similarArtists: similar,
    );
  }
}
