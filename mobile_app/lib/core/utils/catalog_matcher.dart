import '../../data/models/track.dart';
import '../../data/services/spotify_service.dart';
import '../../state/music_provider.dart';

/// Normalizes a track title by removing parenthetical suffixes (feat, live, remaster, etc.)
/// and special punctuation for reliable matching.
String cleanTrackTitle(String title) {
  var s = title.toLowerCase();
  s = s.replaceAll(
    RegExp(
      r'\s*[\(\[](?:feat\.?|ft\.?|with|live|remaster(?:ed)?|deluxe|version|radio edit|bonus|instrumental|edit|mix)[^\)\]]*[\)\]]',
      caseSensitive: false,
    ),
    '',
  );
  s = s.replaceAll(RegExp(r'[^\w\s\u0600-\u06FF]'), ' ');
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Matches a catalog track against owned library tracks by comparing normalized
/// title equality AND artist token equality (set intersection, NOT substring matching).
/// Optionally checks release/album for best match disambiguation.
Track? findLibraryMatch(SpotifyTrackItem catalogTrack, List<Track> libraryTracks) {
  final catTitle = cleanTrackTitle(catalogTrack.title);
  if (catTitle.isEmpty) return null;

  final catTokens = splitArtistNames(catalogTrack.artist)
      .map(normalizeArtistName)
      .where((token) => token.isNotEmpty)
      .toSet();

  final catAlbumNorm = catalogTrack.album != null && catalogTrack.album!.isNotEmpty
      ? cleanTrackTitle(catalogTrack.album!)
      : '';

  Track? fallbackMatch;

  for (final libTrack in libraryTracks) {
    final libTitle = cleanTrackTitle(libTrack.title);
    if (libTitle != catTitle) continue;

    final libTokens = splitArtistNames(libTrack.artist)
        .map(normalizeArtistName)
        .where((token) => token.isNotEmpty)
        .toSet();

    // Check artist token equality:
    // If either has no extracted tokens, match by title;
    // otherwise require set intersection (e.g. "Ali" and "Alina" have no intersection).
    final artistMatches = catTokens.isEmpty ||
        libTokens.isEmpty ||
        catTokens.intersection(libTokens).isNotEmpty;

    if (!artistMatches) continue;

    // Disambiguate by release / album if available
    if (catAlbumNorm.isNotEmpty && libTrack.album.isNotEmpty) {
      final libAlbumNorm = cleanTrackTitle(libTrack.album);
      if (libAlbumNorm == catAlbumNorm) {
        return libTrack;
      }
    }

    fallbackMatch ??= libTrack;
  }

  return fallbackMatch;
}
