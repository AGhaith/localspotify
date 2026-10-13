"""Conservative Deezer spelling choices shared by tagging and downloads."""

import re
import unicodedata


VERSION_WORDS = re.compile(
    r"\b(?:live|remix|acoustic|instrumental|sped up|slowed|karaoke|cover|"
    r"edit|mix|version|remaster(?:ed)?)\b", re.I,
)
ARABIC = re.compile(r"[\u0600-\u06ff]")
LATIN = re.compile(r"[a-zA-Z]")


def normalized(value):
    value = unicodedata.normalize("NFKD", value.casefold())
    letters = "".join(char for char in value if not unicodedata.combining(char))
    return " ".join(re.sub(r"[^\w\s]|_", " ", letters).split())


def version_words(title):
    return {match.group().casefold().replace("remastered", "remaster")
            for match in VERSION_WORDS.finditer(normalized(title))}


def safe_deezer_match(old_title, deezer_title):
    return bool(deezer_title) and not (version_words(deezer_title) - version_words(old_title))


def title_spelling(old_title, deezer_title):
    if old_title.casefold() == deezer_title.casefold():
        return deezer_title
    old_arabic, new_arabic = bool(ARABIC.search(old_title)), bool(ARABIC.search(deezer_title))
    old_latin, new_latin = bool(LATIN.search(old_title)), bool(LATIN.search(deezer_title))
    if (old_arabic and not old_latin and new_latin and not new_arabic) or (
            old_latin and not old_arabic and new_arabic and not new_latin):
        return deezer_title
    return old_title


def contributors(track):
    artists = [track.get("artist") or {}, *(track.get("contributors") or [])]
    return [artist for artist in artists if artist.get("name") and artist.get("id")]


def artist_spelling(old_name, artists, resolve_artist_id=None):
    old_key = normalized(old_name)
    for artist in artists:
        if old_key == normalized(artist["name"]):
            return artist["name"]
    if ARABIC.search(old_name) and resolve_artist_id is not None:
        artist_id = resolve_artist_id(old_name)
        for artist in artists:
            if str(artist["id"]) == str(artist_id):
                return artist["name"]
    return old_name


def artist_spellings(old_artists, artists, resolve_artist_id=None):
    if not old_artists:
        return old_artists
    parts = re.split(r"(\s*[,;]\s*)", old_artists)
    return "".join(artist_spelling(part, artists, resolve_artist_id)
                   if index % 2 == 0 else part
                   for index, part in enumerate(parts))


def canonical_metadata(old_title, old_artists, old_albumartist, track,
                       resolve_artist_id=None):
    deezer_title = track.get("title") or ""
    if not safe_deezer_match(old_title, deezer_title):
        return None
    artists = contributors(track)
    return (
        title_spelling(old_title, deezer_title),
        artist_spellings(old_artists, artists, resolve_artist_id),
        artist_spelling(old_albumartist, artists, resolve_artist_id)
        if old_albumartist else old_albumartist,
    )
