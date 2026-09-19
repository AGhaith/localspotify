import 'package:flutter_test/flutter_test.dart';
import 'package:localspotify/data/services/spotify_service.dart';
import 'package:localspotify/data/services/spotify_importer_service.dart';

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
  });
}
