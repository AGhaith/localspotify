import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:localspotify/data/models/album.dart';
import 'package:localspotify/data/repositories/music_repository.dart';
import 'package:localspotify/state/music_provider.dart';

class _FailingAlbumRepository extends Fake implements MusicRepository {
  final starRequest = Completer<void>();

  @override
  List<String> getRecentSearches() => [];

  @override
  Future<void> starAlbum(String albumId) => starRequest.future;
}

void main() {
  test('failed album save restores the unsaved library state', () async {
    final repository = _FailingAlbumRepository();
    final provider = MusicProvider(musicRepository: repository);
    addTearDown(provider.dispose);
    const album = Album(id: 'album-1', name: 'Album', artist: 'Artist');

    final toggle = provider.toggleAlbumSaved(album);
    expect(provider.isAlbumSaved(album.id), isTrue);
    expect(provider.savedAlbums, hasLength(1));

    repository.starRequest.completeError(Exception('Save failed'));
    await toggle;
    expect(provider.isAlbumSaved(album.id), isFalse);
    expect(provider.savedAlbums, isEmpty);
  });
}
