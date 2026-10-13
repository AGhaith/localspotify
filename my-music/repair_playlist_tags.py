#!/usr/bin/env python3
"""Preview or repair album metadata damaged by the legacy playlist importer."""

import argparse
from pathlib import Path
import urllib.error
import urllib.parse
import urllib.request

from mutagen.flac import Picture
from mutagen.id3 import APIC, TALB, TPE2
from mutagen.mp4 import MP4Cover

from name_policy import normalized, safe_deezer_match
from normalize_names import Deezer, similar, tags_for


AUDIO_SUFFIXES = {".m4a", ".mp4", ".mp3", ".flac"}


def album_tag(audio, suffix):
    if suffix in {".m4a", ".mp4"}:
        return str((audio.tags or {}).get("\xa9alb", [""])[0])
    if suffix == ".mp3":
        frames = audio.tags.getall("TALB") if audio.tags else []
        return str(frames[0].text[0]) if frames else ""
    return str(audio.get("album", [""])[0])


def is_damaged(album, parent, playlist):
    return bool(album and (normalized(album) == normalized(parent) or
                           (playlist and normalized(album) == normalized(playlist))))


def accepts_track(title, artist, duration, track):
    candidate_title = track.get("title") or ""
    candidate_artist = (track.get("artist") or {}).get("name") or ""
    return (safe_deezer_match(title, candidate_title) and
            safe_deezer_match(candidate_title, title) and
            similar(title, candidate_title) and
            any(similar(part.strip(), candidate_artist) for part in artist.replace(";", ",").split(",")) and
            duration is not None and abs((track.get("duration") or -1000) - duration) <= 3)


def find_track(client, title, artist, duration, isrc):
    if isrc:
        track = client.get("track/isrc:" + urllib.parse.quote(isrc))
        if track.get("id") and accepts_track(title, artist, duration, track):
            return track
    query = urllib.parse.quote(f'{artist.split(",")[0]} {title}')
    for candidate in client.get("search?q=" + query).get("data") or []:
        if accepts_track(title, artist, duration, candidate):
            track = client.get(f"track/{candidate['id']}")
            if accepts_track(title, artist, duration, track):
                return track
    return None


def write_repair(audio, suffix, album, album_artist, cover):
    if suffix in {".m4a", ".mp4"}:
        audio["\xa9alb"] = [album]
        audio["aART"] = [album_artist]
        fmt = MP4Cover.FORMAT_PNG if cover.startswith(b"\x89PNG") else MP4Cover.FORMAT_JPEG
        audio["covr"] = [MP4Cover(cover, imageformat=fmt)]
    elif suffix == ".mp3":
        if audio.tags is None:
            audio.add_tags()
        audio.tags.setall("TALB", [TALB(encoding=3, text=album)])
        audio.tags.setall("TPE2", [TPE2(encoding=3, text=album_artist)])
        mime = "image/png" if cover.startswith(b"\x89PNG") else "image/jpeg"
        audio.tags.setall("APIC", [APIC(encoding=3, mime=mime, type=3, desc="Cover", data=cover)])
    else:
        audio["album"] = album
        audio["albumartist"] = album_artist
        audio.clear_pictures()
        picture = Picture()
        picture.type = 3
        picture.mime = "image/png" if cover.startswith(b"\x89PNG") else "image/jpeg"
        picture.data = cover
        audio.add_picture(picture)
    audio.save()


def selftest():
    song = {"title": "Example", "artist": {"name": "Singer"}, "duration": 201}
    assert is_damaged("My Playlist", "My Playlist", None)
    assert is_damaged("My Playlist", "Other Folder", "My Playlist")
    assert not is_damaged("Actual Album", "My Playlist", None)
    assert accepts_track("Example", "Singer", 202, song)
    assert not accepts_track("Example (Live)", "Singer", 201, song)
    assert not accepts_track("Example", "Singer", 205, song)
    assert not accepts_track("Example", "Other Artist", 201, song)
    print("Selftest passed")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("folder", nargs="?", type=Path, default=Path(__file__).parent)
    parser.add_argument("--playlist", help="repair files with this exact album tag")
    parser.add_argument("--apply", action="store_true", help="write tags (default: dry run)")
    parser.add_argument("--selftest", action="store_true")
    args = parser.parse_args()
    if args.selftest:
        selftest()
        return

    client = Deezer()
    counts = dict(scanned=0, candidates=0, matched=0, changed=0, unmatched=0, errors=0)
    print("File | Old album -> Deezer album | Album artist | Cover")
    for path in sorted(args.folder.rglob("*")):
        if path.suffix.lower() not in AUDIO_SUFFIXES:
            continue
        counts["scanned"] += 1
        try:
            audio, (title, artist, _), isrc = tags_for(path)
            old_album = album_tag(audio, path.suffix.lower())
            if not is_damaged(old_album, path.parent.name, args.playlist):
                continue
            counts["candidates"] += 1
            duration = audio.info.length if audio.info else None
            track = find_track(client, title, artist, duration, isrc)
            if not track or not track.get("album", {}).get("id"):
                counts["unmatched"] += 1
                continue
            album = client.get(f"album/{track['album']['id']}")
            album_name = album.get("title")
            album_artist = (album.get("artist") or {}).get("name")
            cover_url = album.get("cover_xl")
            if not (album_name and album_artist and cover_url):
                counts["unmatched"] += 1
                continue
            counts["matched"] += 1
            print(f"{path} | {old_album} -> {album_name} | {album_artist} | {cover_url}")
            counts["changed"] += 1
            if args.apply:
                request = urllib.request.Request(cover_url, headers={"User-Agent": "LocalSpotify/1.0"})
                with urllib.request.urlopen(request, timeout=15) as response:
                    cover = response.read()
                write_repair(audio, path.suffix.lower(), album_name, album_artist, cover)
        except (OSError, ValueError, KeyError, TypeError, RuntimeError, urllib.error.URLError) as error:
            counts["errors"] += 1
            print(f"{path} | ERROR | {error}")
    print("Summary: " + ", ".join(f"{key}={value}" for key, value in counts.items()))


if __name__ == "__main__":
    main()
