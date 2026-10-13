import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localspotify/core/utils/catalog_matcher.dart';
import 'package:localspotify/data/models/track.dart';
import 'package:localspotify/data/services/spotify_service.dart';
import 'package:localspotify/data/services/spotify_importer_service.dart';
import 'package:localspotify/ui/core_widgets/track_row.dart';

void main() {
  group('SpotifyService & Parser Tests', () {
    test('extracts playlist ID from standard https URL', () {
      const url = 'https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M';
      final id = SpotifyService.parsePlaylistId(url);
      expect(id, equals('37i9dQZF1DXcBWIGoYBM5M'));
    });

    test('extracts playlist ID from shared URL with query params', () {
      const url =
          'https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M?si=e299b823e5a54e99&pt=abc';
      final id = SpotifyService.parsePlaylistId(url);
      expect(id, equals('37i9dQZF1DXcBWIGoYBM5M'));
    });

    test('extracts playlist ID from Spotify URI format', () {
      const uri = 'spotify:playlist:37i9dQZF1DXcBWIGoYBM5M';
      final id = SpotifyService.parsePlaylistId(uri);
      expect(id, equals('37i9dQZF1DXcBWIGoYBM5M'));
    });

    test('accepts raw playlist ID directly', () {
      const rawId = '37i9dQZF1DXcBWIGoYBM5M';
      final id = SpotifyService.parsePlaylistId(rawId);
      expect(id, equals('37i9dQZF1DXcBWIGoYBM5M'));
    });

    test('rejects invalid inputs', () {
      expect(SpotifyService.parsePlaylistId(''), isNull);
      expect(SpotifyService.parsePlaylistId('https://google.com'), isNull);
      expect(SpotifyService.parsePlaylistId('not_a_valid_id!@#'), isNull);
    });

    test('formats track duration properly', () {
      const track = SpotifyTrackItem(
        title: 'Midnight City',
        artist: 'M83',
        durationMs: 244000,
        uri: 'spotify:track:123',
      );
      expect(track.durationFormatted, equals('4:04'));
    });

    test('calculates SpotifyPlaylistInfo track count correctly', () {
      const info = SpotifyPlaylistInfo(
        id: '37i9dQZF1DXcBWIGoYBM5M',
        name: 'Chill Hits',
        description: 'Kick back to the best songs.',
        coverUrl: 'https://i.scdn.co/image/test.jpg',
        tracks: [
          SpotifyTrackItem(
            title: 'Song A',
            artist: 'Artist A',
            durationMs: 180000,
            uri: 'spotify:track:a',
          ),
          SpotifyTrackItem(
            title: 'Song B',
            artist: 'Artist B',
            durationMs: 210000,
            uri: 'spotify:track:b',
          ),
        ],
      );

      expect(info.trackCount, equals(2));
      expect(info.name, equals('Chill Hits'));
    });

    test('tracks ImportProgressStatus properties accurately', () {
      const status = ImportProgressStatus(
        stage: ImportStage.downloading,
        message: 'Downloading track (10/50)',
        progress: 0.2,
        currentTrack: 'Midnight City',
        completedCount: 10,
        totalCount: 50,
      );

      expect(status.stage, equals(ImportStage.downloading));
      expect(status.progress, equals(0.2));
      expect(status.completedCount, equals(10));
      expect(status.totalCount, equals(50));
      expect(status.currentTrack, equals('Midnight City'));
    });

    test('SpotifyTrackItem preserves previewUrl and high-res coverUrl', () {
      const track = SpotifyTrackItem(
        title: 'Starboy',
        artist: 'The Weeknd',
        durationMs: 230000,
        uri: 'spotify:track:456',
        previewUrl: 'https://audio-ssl.itunes.apple.com/preview.m4a',
        coverUrl: 'https://is1-ssl.mzstatic.com/image/thumb/600x600bb.jpg',
        album: 'Starboy',
      );

      expect(track.previewUrl, equals('https://audio-ssl.itunes.apple.com/preview.m4a'));
      expect(track.coverUrl, contains('600x600bb.jpg'));
    });

    test('ArtistCatalogAlbum extension accessors work correctly', () {
      const track = SpotifyTrackItem(
        title: 'Song 1',
        artist: 'Artist 1',
        durationMs: 180000,
        uri: 'uri1',
      );
      final ArtistCatalogAlbum album = ('Album A', '2022', 'https://cover.jpg', [track]);
      expect(album.albumTitle, equals('Album A'));
      expect(album.year, equals('2022'));
      expect(album.coverUrl, equals('https://cover.jpg'));
      expect(album.tracks.length, equals(1));
    });

    test('fetchArtistCatalog returns empty catalog on empty artist name', () async {
      final service = SpotifyService();
      final catalog = await service.fetchArtistCatalog('');
      expect(catalog.top, isEmpty);
      expect(catalog.albums, isEmpty);
    });

    test('fetchArtistProfile returns empty profile on empty artist name', () async {
      final service = SpotifyService();
      final profile = await service.fetchArtistProfile('');
      expect(profile.isEmpty, isTrue);
      expect(profile.topTracks, isEmpty);
      expect(profile.releases, isEmpty);
      expect(profile.relatedArtists, isEmpty);
    });

    test('fetchAlbumTracks returns empty list on empty album ID', () async {
      final service = SpotifyService();
      final tracks = await service.fetchAlbumTracks('');
      expect(tracks, isEmpty);
    });

    test('CatalogRelease typeLabel formats correctly for all record types', () {
      const album = CatalogRelease(id: '1', title: 'Album 1', recordType: 'album');
      expect(album.typeLabel, equals('Album'));

      const single = CatalogRelease(id: '2', title: 'Single 1', recordType: 'single');
      expect(single.typeLabel, equals('Single'));

      const ep = CatalogRelease(id: '3', title: 'EP 1', recordType: 'ep');
      expect(ep.typeLabel, equals('EP'));

      const compilation = CatalogRelease(id: '4', title: 'Comp 1', recordType: 'compile');
      expect(compilation.typeLabel, equals('Compilation'));
    });

    test('calculateNameSimilarity handles exact, diacritics, and article variations', () {
      expect(SpotifyService.calculateNameSimilarity('Beyonce', 'Beyonce'), equals(1.0));
      expect(SpotifyService.calculateNameSimilarity('Beyoncé', 'Beyonce'), equals(1.0));
      expect(SpotifyService.calculateNameSimilarity('The Beatles', 'Beatles'), greaterThanOrEqualTo(0.95));
      expect(SpotifyService.calculateNameSimilarity('Coldplay', 'coldplay'), equals(1.0));
    });

    test('calculateNameSimilarity rejects unrelated artists below threshold (fix item 4)', () {
      // "Ali" and "Alina" should be rejected (< 0.85)
      final simAliAlina = SpotifyService.calculateNameSimilarity('Ali', 'Alina');
      expect(simAliAlina, lessThan(0.85));

      // "Michael" and "Michael Jackson" should be rejected (< 0.85)
      final simMichael = SpotifyService.calculateNameSimilarity('Michael', 'Michael Jackson');
      expect(simMichael, lessThan(0.85));

      // Completely different artists
      final simDifferent = SpotifyService.calculateNameSimilarity('Taylor Swift', 'Kanye West');
      expect(simDifferent, lessThan(0.5));
    });

    test('findLibraryMatch matches by title and artist token equality (fix item 7)', () {
      const ownedTrack = Track(
        id: 'track_1',
        title: 'Song Title',
        artist: 'Ali',
        album: 'Album 1',
        duration: 180,
      );

      // Same title, exact artist -> MATCH
      const catalogMatch = SpotifyTrackItem(
        title: 'Song Title',
        artist: 'Ali',
        durationMs: 180000,
        uri: 'uri_1',
      );
      expect(findLibraryMatch(catalogMatch, [ownedTrack]), equals(ownedTrack));

      // Same title, but unrelated substring artist "Alina" -> MUST NOT MATCH (fix item 7)!
      const catalogAlina = SpotifyTrackItem(
        title: 'Song Title',
        artist: 'Alina',
        durationMs: 180000,
        uri: 'uri_2',
      );
      expect(findLibraryMatch(catalogAlina, [ownedTrack]), isNull);

      // Collaboration with featuring artist -> MATCH via token intersection
      const catalogCollab = SpotifyTrackItem(
        title: 'Song Title',
        artist: 'Ali feat. Guest',
        durationMs: 180000,
        uri: 'uri_3',
      );
      expect(findLibraryMatch(catalogCollab, [ownedTrack]), equals(ownedTrack));
    });

    test('findLibraryMatch normalizes title variants (remaster, deluxe, live)', () {
      const owned = Track(
        id: 'track_2',
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        album: 'After Hours',
        duration: 200,
      );

      const catalogRemaster = SpotifyTrackItem(
        title: 'Blinding Lights (Remastered 2020)',
        artist: 'The Weeknd',
        durationMs: 200000,
        uri: 'uri_4',
      );
      expect(findLibraryMatch(catalogRemaster, [owned]), equals(owned));
    });

    testWidgets('TrackRowLayout renders song info and trailing more without Play & Sync', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrackRowLayout(
              isCurrent: false,
              isPlaying: false,
              title: 'Starboy',
              subtitle: const Text('The Weeknd • Starboy'),
              durationText: '3:50',
              onMoreTap: () {},
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Starboy'), findsOneWidget);
      expect(find.text('The Weeknd • Starboy'), findsOneWidget);
      expect(find.text('3:50'), findsOneWidget);
      expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
      expect(find.text('Play & Sync'), findsNothing);
      expect(find.text('Syncing...'), findsNothing);
    });

    testWidgets('TrackRowLayout displays coverOverlay and dims cover when syncing or on error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrackRowLayout(
              isCurrent: false,
              isPlaying: false,
              title: 'Starboy',
              subtitle: const Text('The Weeknd'),
              durationText: '3:50',
              coverOverlay: const CircularProgressIndicator(),
              onMoreTap: () {},
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Play & Sync'), findsNothing);
      expect(find.text('Syncing...'), findsNothing);
    });

    test('Song pluralization formats 1 song and N songs correctly', () {
      String formatSongCount(int count) => '$count ${count == 1 ? "song" : "songs"}';

      expect(formatSongCount(1), equals('1 song'));
      expect(formatSongCount(2), equals('2 songs'));
      expect(formatSongCount(15), equals('15 songs'));
      expect(formatSongCount(0), equals('0 songs'));
    });
  });
}
