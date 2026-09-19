import 'package:flutter_test/flutter_test.dart';
import 'package:localspotify/core/utils/duration_formatter.dart';
import 'package:localspotify/data/models/album.dart';
import 'package:localspotify/data/models/artist.dart';
import 'package:localspotify/data/models/track.dart';

void main() {
  group('DurationFormatter Tests', () {
    test('formats seconds to mm:ss', () {
      expect(DurationFormatter.format(65), equals('1:05'));
      expect(DurationFormatter.format(0), equals('0:00'));
      expect(DurationFormatter.format(3600), equals('1:00:00'));
      expect(DurationFormatter.format(3665), equals('1:01:05'));
    });

    test('formats Duration object', () {
      expect(DurationFormatter.formatDuration(const Duration(minutes: 3, seconds: 42)), equals('3:42'));
    });
  });

  group('Track Model Tests', () {
    test('parses Subsonic track JSON with localCoverArtPath support', () {
      final json = {
        'id': 'tr-100',
        'title': 'Midnight City',
        'artist': 'M83',
        'artistId': 'art-200',
        'album': 'Hurry Up, We\'re Dreaming',
        'albumId': 'alb-300',
        'duration': 244,
        'bitRate': 320,
        'suffix': 'flac',
        'starred': '2023-01-01T00:00:00Z',
      };

      final track = Track.fromSubsonicJson(json);
      expect(track.id, equals('tr-100'));
      expect(track.title, equals('Midnight City'));
      expect(track.artist, equals('M83'));
      expect(track.suffix, equals('flac'));
      expect(track.isStarred, isTrue);
      expect(track.isOffline, isFalse);
      expect(track.localCoverArtPath, isNull);

      final downloadedTrack = track.copyWith(
        isOffline: true,
        localAudioPath: '/storage/emulated/0/music/tr-100.flac',
        localCoverArtPath: '/storage/emulated/0/music/covers/tr-100.jpg',
      );
      expect(downloadedTrack.isOffline, isTrue);
      expect(downloadedTrack.localCoverArtPath, equals('/storage/emulated/0/music/covers/tr-100.jpg'));

      final jsonOutput = downloadedTrack.toJson();
      final restored = Track.fromJson(jsonOutput);
      expect(restored.id, equals('tr-100'));
      expect(restored.localCoverArtPath, equals('/storage/emulated/0/music/covers/tr-100.jpg'));
    });
  });

  group('Artist Model Tests', () {
    test('parses getArtistInfo2 JSON with biography and similar artists', () {
      final json = {
        'biography': 'M83 is a French electronic music project formed in 2001 in Antibes.',
        'similarArtist': [
          {'id': 'art-201', 'name': 'Chvrches'},
          {'id': 'art-202', 'name': 'Phoenix'},
        ],
      };

      const artist = Artist(
        id: 'art-200',
        name: 'M83',
        albumCount: 8,
      );

      final enriched = Artist.fromArtistInfoJson(
        baseArtist: artist,
        infoJson: json,
      );
      expect(enriched.biography, contains('French electronic music project'));
      expect(enriched.similarArtists.length, equals(2));
      expect(enriched.similarArtists[0].name, equals('Chvrches'));
      expect(enriched.similarArtists[1].name, equals('Phoenix'));
    });
  });

  group('Album Model Tests', () {
    test('parses Subsonic album JSON', () {
      final json = {
        'id': 'alb-300',
        'name': 'Hurry Up, We\'re Dreaming',
        'artist': 'M83',
        'artistId': 'art-200',
        'songCount': 22,
        'duration': 4400,
        'year': 2011,
      };

      final album = Album.fromSubsonicJson(json);
      expect(album.id, equals('alb-300'));
      expect(album.name, equals('Hurry Up, We\'re Dreaming'));
      expect(album.artistId, equals('art-200'));
      expect(album.year, equals(2011));
    });
  });
}
