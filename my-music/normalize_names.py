#!/usr/bin/env python3
"""Preview or apply Deezer's track and artist names to local audio tags."""

import argparse
from difflib import SequenceMatcher
import json
from pathlib import Path
import re
import ssl
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

from mutagen.flac import FLAC
from mutagen.id3 import TPE1, TPE2, TIT2
from mutagen.mp3 import MP3
from mutagen.mp4 import MP4
from name_policy import canonical_metadata, contributors, normalized, safe_deezer_match


def similar(left, right):
    a, b = normalized(left), normalized(right)
    return bool(a and b) and SequenceMatcher(None, a, b).ratio() >= 0.75


def accepts_search(title, artist, duration, candidate):
    if duration is None or abs((candidate.get("duration") or -1000) - duration) > 3:
        return False
    candidate_artist = (candidate.get("artist") or {}).get("name") or ""
    return safe_deezer_match(title, candidate.get("title") or "") and similar(title, candidate.get("title") or "") and any(
        similar(part.strip(), candidate_artist)
        for part in re.split(r"[,;]", artist)
    )


class Deezer:
    def __init__(self):
        self.cache = {}
        self.last_request = 0.0

    def get(self, path):
        if path in self.cache:
            return self.cache[path]
        for attempt in range(3):
            delay = 0.125 - (time.monotonic() - self.last_request)
            if delay > 0:
                time.sleep(delay)
            self.last_request = time.monotonic()
            request = urllib.request.Request("https://api.deezer.com/" + path,
                                             headers={"User-Agent": "LocalSpotify/1.0", "Accept-Language": "en"})
            try:
                with urllib.request.urlopen(request, timeout=10) as response:
                    result = json.load(response)
            except urllib.error.HTTPError as error:
                if error.code == 429 and attempt < 2:
                    time.sleep(2 ** attempt)
                    continue
                raise
            except (urllib.error.URLError, TimeoutError, ssl.SSLError):
                if attempt == 2:
                    raise
                time.sleep(2 ** attempt)
                continue
            error = result.get("error") or {}
            if error and (error.get("code") == 4 or "quota" in
                          str(error.get("message", "")).lower()):
                if attempt == 2:
                    raise RuntimeError(f"Deezer quota error: {error}")
                time.sleep(2 ** attempt)
                continue
            self.cache[path] = result
            return result
        return {}


def first(values):
    return str(values[0]) if values else ""


def tags_for(path):
    if path.suffix.lower() in (".m4a", ".mp4"):
        audio = MP4(path)
        tags = audio.tags or {}
        isrc = tags.get("----:com.apple.iTunes:ISRC") or tags.get("\xa9isr")
        if isinstance(isrc, list) and isrc:
            isrc = isrc[0]
        if isinstance(isrc, bytes):
            isrc = isrc.decode("utf-8", "replace")
        return audio, (first(tags.get("\xa9nam")), first(tags.get("\xa9ART")),
                       first(tags.get("aART"))), str(isrc or "").strip()
    if path.suffix.lower() == ".mp3":
        audio = MP3(path)
        tags = audio.tags or {}
        isrc = tags.get("TSRC")
        return audio, (first(tags.getall("TIT2")), first(tags.getall("TPE1")),
                       first(tags.getall("TPE2"))), str(isrc or "").strip()
    audio = FLAC(path)
    return audio, (first(audio.get("title")), first(audio.get("artist")),
                   first(audio.get("albumartist"))), first(audio.get("isrc")).strip()


def write_tags(audio, path, old, new):
    if path.suffix.lower() in (".m4a", ".mp4"):
        for tag, before, after in zip(("\xa9nam", "\xa9ART", "aART"), old, new):
            if before != after:
                audio[tag] = after
    elif path.suffix.lower() == ".mp3":
        if audio.tags is None:
            audio.add_tags()
        for tag, frame, before, after in zip(
                ("TIT2", "TPE1", "TPE2"), (TIT2, TPE1, TPE2), old, new):
            if before != after:
                audio.tags.setall(tag, [frame(encoding=3, text=after)])
    else:
        for tag, before, after in zip(("title", "artist", "albumartist"), old, new):
            if before != after:
                audio[tag] = after
    audio.save()


def resolve(client, title, artist, duration, isrc):
    if isrc:
        track = client.get("track/isrc:" + urllib.parse.quote(isrc))
        return track if track.get("id") and (duration is None or
            abs((track.get("duration") or -1000) - duration) <= 3) else None
    lead_artist = artist.split(",")[0].strip()
    queries = (f'artist:"{lead_artist}" track:"{title}"', f"{lead_artist} {title}")
    for query in queries:
        candidates = client.get("search?q=" + urllib.parse.quote(query)).get("data") or []
        for candidate in candidates:
            if accepts_search(title, artist, duration, candidate):
                return client.get(f"track/{candidate['id']}")
    return None


def resolve_artist_id(client, old_name, track):
    matches = client.get("search/artist?q=" + urllib.parse.quote(old_name)).get("data") or []
    ids = {str(artist["id"]) for artist in contributors(track)}
    relevant = {str(artist.get("id")) for artist in matches if str(artist.get("id")) in ids}
    return next(iter(relevant)) if len(relevant) == 1 else None


def selftest():
    track = {"title": "حبيبي", "artist": {"id": 7, "name": "Amr Diab"},
             "contributors": [{"id": 8, "name": "Guest"}]}
    assert canonical_metadata("Habibi", "عمرو دياب, Guest, Unknown", "عمرو دياب", track,
                              lambda name: 7) == ("حبيبي", "Amr Diab, Guest, Unknown", "Amr Diab")
    assert canonical_metadata("Move", "Crystal Waters, The Basement Boys", "Crystal Waters",
                              {"title": "Move", "artist": {"id": 1, "name": "Crystal Waters"}}) == (
                                  "Move", "Crystal Waters, The Basement Boys", "Crystal Waters")
    assert canonical_metadata("Move", "Nasser, Kay", "Nasser",
                              {"title": "Move", "artist": {"id": 1, "name": "Nasser"}})[1] == "Nasser, Kay"
    assert canonical_metadata("Move", "Magic System, 113, Mohamed Lamine", "Magic System",
                              {"title": "Move", "artist": {"id": 1, "name": "Magic System"}})[1] == (
                                  "Magic System, 113, Mohamed Lamine")
    assert canonical_metadata("X - Radio Edit", "LF SYSTEM", "LF SYSTEM",
                              {"title": "X (Radio Edit)", "artist": {"id": 1, "name": "LF System"}}) == (
                                  "X - Radio Edit", "LF System", "LF System")
    assert canonical_metadata("Coke Studio Egypt 2023", "Artist", "Artist",
                              {"title": "( Coke Studio Egypt 2023 )", "artist": {"id": 1, "name": "Artist"}})[0] == (
                                  "Coke Studio Egypt 2023")
    assert canonical_metadata("Un Gaou à Oran", "Artist", "Artist",
                              {"title": "Un Gaou à Oran (Live)"}) is None
    assert canonical_metadata("HELLO", "Artist", "Artist",
                              {"title": "Hello"})[0] == "Hello"
    assert accepts_search("Hello!", "Artist", 200,
                          {"title": "hello", "artist": {"name": "artist"}, "duration": 202})
    assert not accepts_search("Hello", "Artist", 200,
                              {"title": "Different", "artist": {"name": "Artist"}, "duration": 200})
    assert not accepts_search("Hello", "Artist", 200,
                              {"title": "Hello", "artist": {"name": "Artist"}, "duration": 205})
    print("Selftest passed")


def main():
    sys.stdout.reconfigure(encoding="utf-8", errors="backslashreplace")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("folder", nargs="?", type=Path, default=Path(__file__).parent)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--dry-run", action="store_true", help="preview changes (default)")
    mode.add_argument("--apply", action="store_true")
    parser.add_argument("--selftest", action="store_true")
    args = parser.parse_args()
    if args.selftest:
        selftest()
        return
    client = Deezer()
    counts = dict(scanned=0, matched=0, changed=0, unchanged=0, unmatched=0, errors=0)
    print("File | Field | Old -> New")
    for path in sorted(args.folder.rglob("*")):
        if path.suffix.lower() not in (".m4a", ".mp3", ".flac"):
            continue
        counts["scanned"] += 1
        try:
            audio, old, isrc = tags_for(path)
            duration = audio.info.length if audio.info else None
            track = resolve(client, old[0], old[1], duration, isrc)
            if not track:
                counts["unmatched"] += 1
                continue
            new = canonical_metadata(*old, track,
                lambda name: resolve_artist_id(client, name, track))
            if new is None:
                counts["unmatched"] += 1
                continue
            counts["matched"] += 1
            differences = [(field, before, after) for field, before, after in
                           zip(("title", "artist", "albumartist"), old, new) if before != after]
            if differences:
                counts["changed"] += 1
                for field, before, after in differences:
                    print(f"{path} | {field} | {before} -> {after}")
                if args.apply:
                    write_tags(audio, path, old, new)
            else:
                counts["unchanged"] += 1
        except (OSError, ValueError, KeyError, TypeError, RuntimeError) as error:
            counts["errors"] += 1
            print(f"{path} | ERROR | {error}")
    print("Summary: " + ", ".join(f"{key}={value}" for key, value in counts.items()))


if __name__ == "__main__":
    main()
