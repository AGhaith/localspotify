import '../../data/models/artist.dart';
import '../../data/services/spotify_service.dart';

typedef ArtistProfileResolver = Future<ArtistProfile> Function(String name);

/// Resolved Deezer identities for the current library load.
class ArtistIdentity {
  static final ArtistIdentity shared = ArtistIdentity();

  final Map<String, ArtistProfile> _profiles = {};
  final Map<String, String> _aliases = {};
  final Map<String, List<String>> _namesByArtistId = {};

  String _key(String name) => name.trim().toLowerCase();
  String? idFor(String name) => _profiles[_key(name)]?.artistId;
  String canonicalName(String name) =>
      _profiles[_key(name)]?.artistName ?? name;
  List<String> namesFor(String artistId, String fallback) =>
      _namesByArtistId[artistId] ?? [fallback];
  String mergedKey(String name) => _aliases[_key(name)] ?? _key(name);

  Future<List<Artist>> merge(
      List<Artist> artists, ArtistProfileResolver resolve) async {
    _aliases.clear();
    _namesByArtistId.clear();
    final arabic = artists
        .where((a) => RegExp(r'[\u0600-\u06ff]').hasMatch(a.name))
        .toList();
    final latin = artists
        .where((a) => !RegExp(r'[\u0600-\u06ff]').hasMatch(a.name))
        .toList();
    if (arabic.isEmpty || latin.isEmpty) return artists;

    Future<ArtistProfile> profile(String name) async {
      final key = _key(name);
      if (_profiles[key]?.artistId.isNotEmpty ?? false) return _profiles[key]!;
      try {
        return _profiles[key] = await resolve(name);
      } catch (_) {
        return _profiles[key] = ArtistProfile.empty;
      }
    }

    final arabicProfiles =
        await Future.wait(arabic.map((a) => profile(a.name)));
    final wantedIds = arabicProfiles
        .where((p) => p.artistId.isNotEmpty)
        .map((p) => p.artistId)
        .toSet();
    if (wantedIds.isEmpty) return artists;
    final latinProfiles = await Future.wait(latin.map((a) => profile(a.name)));
    final matchingLatinIds = latinProfiles
        .where((p) => wantedIds.contains(p.artistId))
        .map((p) => p.artistId)
        .toSet();
    if (matchingLatinIds.isEmpty) return artists;

    final byId = <String, List<Artist>>{};
    for (final artist in artists) {
      final id = idFor(artist.name);
      if (id != null && matchingLatinIds.contains(id)) {
        byId.putIfAbsent(id, () => []).add(artist);
      }
    }
    final result = <Artist>[];
    final emitted = <String>{};
    for (final artist in artists) {
      final id = idFor(artist.name);
      final group = id == null ? null : byId[id];
      if (group == null || group.length < 2) {
        result.add(artist);
        continue;
      }
      if (!emitted.add(id!)) continue;
      final canonical = canonicalName(artist.name);
      final names = group.map((a) => a.name).toList();
      _namesByArtistId['sub_name_${Uri.encodeComponent(canonical)}'] = names;
      for (final name in names) {
        _aliases[_key(name)] = _key(canonical);
      }
      result.add(artist.copyWith(
        id: 'sub_name_${Uri.encodeComponent(canonical)}',
        name: canonical,
        albumCount: group.fold<int>(0, (sum, a) => sum + a.albumCount),
      ));
    }
    return result;
  }
}
