import 'package:flutter_test/flutter_test.dart';
import 'package:localspotify/data/models/lyrics.dart';

void main() {
  group('Lyrics Model & Parser Tests', () {
    test('parses OpenSubsonic structured lyrics with millisecond offsets', () {
      final json = {
        'structuredLyrics': [
          {
            'lang': 'en',
            'synced': true,
            'line': [
              {'start': 1500, 'value': 'Is this the real life?'},
              {'start': 4200, 'value': 'Is this just fantasy?'},
              {'start': 8000, 'value': 'Caught in a landslide'},
            ],
          },
        ],
      };

      final lyrics = Lyrics.fromSubsonicJson(json);
      expect(lyrics.isSynced, isTrue);
      expect(lyrics.lines.length, equals(3));
      expect(lyrics.lines[0].timestamp, equals(const Duration(milliseconds: 1500)));
      expect(lyrics.lines[0].text, equals('Is this the real life?'));
      expect(lyrics.lines[1].timestamp, equals(const Duration(milliseconds: 4200)));
      expect(lyrics.lines[1].text, equals('Is this just fantasy?'));
      expect(lyrics.lines[2].timestamp, equals(const Duration(milliseconds: 8000)));
    });

    test('parses Subsonic LRC format lyrics with standard timestamps', () {
      const lrcContent = '''
[00:01.50]Hello from the other side
[00:04.20]I must have called a thousand times
[00:08.00]To tell you I am sorry
''';

      final lyrics = Lyrics.fromLrc(lrcContent);
      expect(lyrics.isSynced, isTrue);
      expect(lyrics.lines.length, equals(3));
      expect(lyrics.lines[0].timestamp, equals(const Duration(seconds: 1, milliseconds: 500)));
      expect(lyrics.lines[0].text, equals('Hello from the other side'));
      expect(lyrics.lines[1].timestamp, equals(const Duration(seconds: 4, milliseconds: 200)));
      expect(lyrics.lines[2].timestamp, equals(const Duration(seconds: 8)));
    });

    test('parses unsynced plain text lyrics fallback', () {
      const plainText = '''
Line one of song
Line two of song
Line three of song
''';

      final lyrics = Lyrics.fromPlainText(plainText);
      expect(lyrics.isSynced, isFalse);
      expect(lyrics.lines.isEmpty, isTrue);
      expect(lyrics.rawText, contains('Line one of song'));
    });
  });
}
