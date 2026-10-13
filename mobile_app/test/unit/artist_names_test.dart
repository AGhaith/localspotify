import 'package:flutter_test/flutter_test.dart';
import 'package:localspotify/state/music_provider.dart';

void main() {
  test('normalizes Latin names without conflating Arabic names', () {
    expect(normalizeArtistName('  Beyoncé!  '), 'beyonce');
    expect(normalizeArtistName('Beyonce'), 'beyonce');
    expect(normalizeArtistName('  علي  '), 'علي');
    expect(normalizeArtistName('علي'), isNot(normalizeArtistName('علية')));
  });

  test('splits collaboration markers but keeps name punctuation', () {
    expect(splitArtistNames('AC/DC'), ['AC/DC']);
    expect(splitArtistNames('Simon & Garfunkel'), ['Simon & Garfunkel']);
    expect(splitArtistNames('Ali feat. Alina'), ['Ali', 'Alina']);
    expect(splitArtistNames('Ali, Alina'), ['Ali', 'Alina']);
  });
}
