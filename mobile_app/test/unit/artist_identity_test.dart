import 'package:flutter_test/flutter_test.dart';
import 'package:localspotify/core/utils/artist_identity.dart';
import 'package:localspotify/core/utils/catalog_matcher.dart';
import 'package:localspotify/data/models/artist.dart';
import 'package:localspotify/data/models/track.dart';
import 'package:localspotify/data/services/spotify_service.dart';

void main() {
  test('merges spellings by Deezer ID and matches cross-script library track',
      () async {
    final identity = ArtistIdentity();
    Future<ArtistProfile> resolve(String name) async {
      return ArtistProfile(
        artistId: '42',
        artistName: 'Amr Diab',
        topTracks: const [],
        releases: const [],
      );
    }

    final artists = await identity.merge(const [
      Artist(id: 'latin', name: 'Amr Diab'),
      Artist(id: 'arabic', name: 'عمرو دياب'),
    ], resolve);
    expect(artists, hasLength(1));
    expect(artists.single.name, 'Amr Diab');
    expect(identity.namesFor(artists.single.id, artists.single.name),
        ['Amr Diab', 'عمرو دياب']);

    const catalog = SpotifyTrackItem(
        title: 'Habibi',
        artist: 'Amr Diab',
        durationMs: 200000,
        uri: 'deezer:1');
    const owned = Track(
        id: 'song',
        title: 'حبيبي',
        artist: 'عمرو دياب',
        album: 'Album',
        duration: 200);
    expect(findLibraryMatch(catalog, [owned], identity: identity), owned);
  });

  test('leaves Arabic artist separate when Deezer IDs differ', () async {
    final identity = ArtistIdentity();
    final artists = await identity.merge(
        const [
          Artist(id: 'latin', name: 'Amr Diab'),
          Artist(id: 'arabic', name: 'عمرو دياب'),
        ],
        (name) async => ArtistProfile(
              artistId: name == 'Amr Diab' ? '1' : '2',
              artistName: name,
              topTracks: const [],
              releases: const [],
            ));
    expect(artists, hasLength(2));
  });
}
