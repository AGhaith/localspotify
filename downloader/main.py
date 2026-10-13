import asyncio
from collections import OrderedDict
from difflib import SequenceMatcher
import json
import logging
import os
import re
import threading
import time
import unicodedata
import urllib.request
import urllib.parse
from pathlib import Path
from typing import NamedTuple

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
import yt_dlp
import syncedlyrics
from ytmusicapi import YTMusic

from download_liked_songs import (
    download_audio_with_ytdlp,
    embed_metadata,
    fetch_spotify_hd_cover,
    fetch_synced_lyrics,
    process_cover_image,
    sanitize_filename,
    save_lrc_file,
)


music_dir = Path(os.environ.get("MUSIC_DIR", "/music"))
max_downloads = max(1, int(os.environ.get("MAX_CONCURRENT_DOWNLOADS", "3")))
download_slots = asyncio.Semaphore(max_downloads)
in_flight: dict[str, asyncio.Task[tuple[str, bool]]] = {}
progress: dict[str, dict] = {}
progress_lock = threading.Lock()
progress_retention_seconds = 600
lyrics_cache: OrderedDict[tuple[str, str, str, float | None], tuple[float, dict | None]] = OrderedDict()
lyrics_cache_limit = 500
lyrics_miss_ttl = 600
logger = logging.getLogger("uvicorn.error")
ytmusic = YTMusic()
app = FastAPI()
VERSION_TERMS = (
    "remix", "live", "acoustic", "radio edit", "extended", "sped up",
    "slowed", "instrumental", "karaoke", "cover", "nightcore", "8d",
)


class DownloadRequest(BaseModel):
    title: str = Field(min_length=1)
    artist: str = Field(min_length=1)
    album: str | None = None
    durationMs: float | None = None
    coverUrl: str | None = None
    uri: str | None = None
    isrc: str | None = None
    deezerId: int | None = None


class AudioCandidate(NamedTuple):
    video_id: str
    title: str
    artists: list[str]
    seconds: float
    title_score: float
    artist_score: float
    album_score: float


def filename_key(title: str, artist: str) -> str:
    clean_title = sanitize_filename(title.strip())
    clean_artist = sanitize_filename(artist.strip().replace(";", ", "))
    return f"{clean_artist} - {clean_title}.m4a"


def lyrics_response(lyrics: str, source: str) -> dict:
    return {
        "synced": bool(re.search(r"\[\d{1,2}:\d{2}(?:\.\d{1,3})?\]", lyrics)),
        "lrc": lyrics,
        "source": source,
    }


def search_lyrics(title: str, artist: str, album: str, duration: float | None) -> dict | None:
    clean_title = re.sub(r"\s*[\[(]\s*(?:feat|ft|featuring)\b[^\])]*[\])]", "", title, flags=re.I)
    clean_title = re.sub(r"\s*[-–—]\s*remaster(?:ed)?\b.*$", "", clean_title, flags=re.I).strip()
    primary_artist = artist.split(",", 1)[0].strip()
    for search_artist in dict.fromkeys((artist, primary_artist)):
        lyrics, _ = fetch_synced_lyrics(search_artist, clean_title, album, duration)
        if lyrics:
            return lyrics_response(lyrics, "syncedlyrics")
        for search_options in ({"synced_only": True}, {"plain_only": True}):
            lyrics = syncedlyrics.search(f"{clean_title} {search_artist}", **search_options)
            if lyrics:
                return lyrics_response(lyrics, "syncedlyrics")
    return None


def set_progress(filename: str, stage: str, percent: int, message: str) -> None:
    updated = time.monotonic()
    with progress_lock:
        progress[filename] = {
            "stage": stage, "percent": percent, "message": message, "updated": updated,
        }
    if stage in ("ready", "failed"):
        expiry = threading.Timer(progress_retention_seconds, clear_expired_progress, args=(filename, updated))
        expiry.daemon = True
        expiry.start()


def clear_expired_progress(filename: str, updated: float) -> None:
    with progress_lock:
        current = progress.get(filename)
        if current and current["updated"] == updated:
            del progress[filename]


def download_progress_hook(filename: str, status: dict) -> None:
    if status.get("status") != "downloading":
        return
    total = status.get("total_bytes") or status.get("total_bytes_estimate")
    downloaded = status.get("downloaded_bytes") or 0
    percent = min(100, max(0, int(downloaded * 100 / total))) if total else 50
    set_progress(filename, "downloading", percent, "Downloading audio")


def download_cover(url: str) -> bytes | None:
    if not url.startswith(("http://", "https://")):
        return None
    try:
        request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(request, timeout=10) as response:
            image_bytes = response.read(10 * 1024 * 1024 + 1)
            if len(image_bytes) > 10 * 1024 * 1024:
                logger.warning("Cover image exceeds 10 MB")
                return None
            return process_cover_image(image_bytes)
    except Exception:
        logger.warning("Could not fetch cover image", exc_info=True)
        return None


def normalize_text(text: str) -> str:
    text = unicodedata.normalize("NFKD", text.casefold())
    text = "".join(char for char in text if not unicodedata.combining(char))
    return " ".join(re.sub(r"[^\w\s]|_", " ", text).split())


def normalize_title(title: str) -> str:
    title = re.sub(r"\s*[\[(]\s*(?:(?:feat|ft|featuring)\b\.?|official\b)[^\])]*[\])]", "", title, flags=re.I)
    title = re.sub(r"\s*[-–—]\s*remaster(?:ed)?\b.*$", "", title, flags=re.I)
    return normalize_text(title)


def similarity(left: str, right: str) -> float:
    return SequenceMatcher(None, left, right).ratio() if left and right else 0.0


def version_terms(title: str) -> set[str]:
    words = normalize_text(title)
    return {term for term in VERSION_TERMS if re.search(rf"\b{term}\b", words)}


def version_signature(title: str) -> tuple[frozenset[str], str]:
    featured = re.search(r"\b(?:feat\.?|ft\.?|featuring)\s+([^\])]+)", title, flags=re.I)
    return frozenset(version_terms(title)), normalize_text(featured.group(1)) if featured else ""


def mostly_non_latin(title: str) -> bool:
    letters = [char for char in title if char.isalpha()]
    return bool(letters) and sum("a" <= char.casefold() <= "z" for char in letters) < len(letters) / 2


def artist_similarity(requested: str, candidates: list[str]) -> float:
    requested_names = re.split(r",\s*|&|\s+x\s+", requested, flags=re.I)
    return max(
        (similarity(normalize_text(name), normalize_text(candidate))
         for name in requested_names for candidate in candidates),
        default=0.0,
    )


def matches_ytmusic_metadata(track: DownloadRequest, candidate: AudioCandidate) -> bool:
    if mostly_non_latin(track.title) or mostly_non_latin(candidate.title):
        return candidate.artist_score >= 0.8 or candidate.album_score >= 0.8
    return candidate.title_score >= 0.75 and candidate.artist_score >= 0.8


def accepted_candidate(track: DownloadRequest, source: str, song: dict, duration: float) -> AudioCandidate | None:
    title = song.get("title") or ""
    seconds = song.get("duration_seconds" if source in ("isrc", "ytmusic") else "duration")
    video_id = song.get("videoId" if source in ("isrc", "ytmusic") else "id")
    tolerance = 3 if source in ("isrc", "ytmusic") else 15
    if not video_id or not isinstance(seconds, (int, float)) or abs(seconds - duration) > tolerance:
        return None
    if version_signature(track.title) != version_signature(title):
        return None
    artists = ([artist.get("name", "") for artist in song.get("artists", [])]
               if source in ("isrc", "ytmusic") else [song.get("uploader") or song.get("channel") or ""])
    album = song.get("album") or {}
    album_name = album.get("name", "") if isinstance(album, dict) else ""
    candidate = AudioCandidate(
        video_id, title, artists, seconds,
        similarity(normalize_title(track.title), normalize_title(title)),
        artist_similarity(track.artist, artists),
        similarity(normalize_text(track.album or ""), normalize_text(album_name)),
    )
    if source == "ytmusic" and not matches_ytmusic_metadata(track, candidate):
        return None
    if source == "isrc" and any(artists) and not set(normalize_text(track.artist).split()).intersection(
        normalize_text(" ".join(artists)).split()
    ):
        return None
    return candidate


def deezer_json(path: str) -> dict:
    request = urllib.request.Request(f"https://api.deezer.com/{path}", headers={"User-Agent": "LocalSpotify/1.0"})
    with urllib.request.urlopen(request, timeout=8) as response:
        return json.load(response)


def deezer_isrc(track: DownloadRequest) -> str | None:
    if track.isrc:
        return track.isrc.strip() or None
    if track.deezerId:
        song = deezer_json(f"track/{track.deezerId}")
        duration = track.durationMs / 1000 if track.durationMs else None
        if (version_signature(track.title) == version_signature(song.get("title") or "")
                and (duration is None or abs(song.get("duration", -1000) - duration) <= 3)):
            return song.get("isrc")
    queries = (f'artist:"{track.artist}" track:"{track.title}"', f"{track.artist} {track.title}")
    for query in queries:
        songs = deezer_json(f"search?q={urllib.parse.quote(query)}").get("data", [])
        for song in songs:
            if deezer_track_matches(track, song):
                return deezer_json(f"track/{song['id']}").get("isrc")
    return None


def deezer_track_matches(track: DownloadRequest, song: dict) -> bool:
    title = song.get("title") or ""
    artist = (song.get("artist") or {}).get("name") or ""
    duration = track.durationMs / 1000 if track.durationMs else None
    return (version_signature(track.title) == version_signature(title)
            and similarity(normalize_title(track.title), normalize_title(title)) >= 0.75
            and artist_similarity(track.artist, [artist]) >= 0.8
            and (duration is None or abs(song.get("duration", -1000) - duration) <= 3))


def select_audio_candidates(track: DownloadRequest) -> list[tuple[str, AudioCandidate]]:
    duration = track.durationMs / 1000 if track.durationMs else None
    if duration is None:
        return []
    chosen = []
    try:
        isrc = deezer_isrc(track)
    except (OSError, ValueError, KeyError, TypeError):
        logger.warning("Deezer ISRC lookup failed for %s - %s", track.artist, track.title, exc_info=True)
        isrc = None
    searches = []
    if isrc:
        searches.append(("isrc", lambda: ytmusic.search(isrc, filter="songs")))
    searches.extend((("ytmusic", lambda: ytmusic.search(f"{track.artist} {track.title}", filter="songs", limit=5)[:5]),
                     ("youtube", lambda: youtube_search(track))))
    for source, search in searches:
        try:
            songs = search()
        except Exception:
            logger.warning("%s search failed for %s - %s", source, track.artist, track.title, exc_info=True)
            continue
        for song in songs:
            candidate = accepted_candidate(track, source, song, duration)
            if candidate:
                chosen.append((source, candidate))
    return chosen


def download_video(video_id: str, output_base: Path, need_thumbnail: bool) -> tuple[str | None, bytes | None]:
    filename = f"{output_base.name}.m4a"
    ydl_opts = {
        "format": "bestaudio[ext=m4a]/bestaudio[ext=aac]/bestaudio/best",
        "outtmpl": f"{output_base}.%(ext)s",
        "postprocessors": [{"key": "FFmpegExtractAudio", "preferredcodec": "m4a", "preferredquality": "0"}],
        "writethumbnail": need_thumbnail,
        "quiet": True,
        "no_warnings": True,
        "noprogress": True,
        "noplaylist": True,
        "socket_timeout": 10,
        "retries": 2,
        "concurrent_fragment_downloads": 2,
        "progress_hooks": [lambda status: download_progress_hook(filename, status)],
    }
    set_progress(filename, "downloading", 0, "Downloading audio")
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        ydl.download([f"https://www.youtube.com/watch?v={video_id}"])

    fallback_cover = None
    if need_thumbnail:
        for extension in (".jpg", ".webp", ".png"):
            thumbnail = Path(f"{output_base}{extension}")
            if thumbnail.exists():
                try:
                    if fallback_cover is None:
                        fallback_cover = process_cover_image(thumbnail.read_bytes())
                    thumbnail.unlink()
                except Exception:
                    logger.warning("Could not read or remove thumbnail %s", thumbnail, exc_info=True)

    file_path = f"{output_base}.m4a"
    return (file_path if os.path.exists(file_path) else None), fallback_cover


def download_matching_audio(track: DownloadRequest, output_base: Path, need_thumbnail: bool) -> tuple[str | None, bytes | None, bool]:
    filename = f"{output_base.name}.m4a"
    for source, candidate in select_audio_candidates(track):
        try:
            file_path, cover = download_video(candidate.video_id, output_base, need_thumbnail)
            if not file_path:
                raise RuntimeError("Downloaded audio file is missing")
        except (yt_dlp.utils.DownloadError, OSError, RuntimeError):
            Path(f"{output_base}.m4a").unlink(missing_ok=True)
            logger.warning("Audio download failed source=%s candidate=%s id=%s", source, candidate.title, candidate.video_id, exc_info=True)
            continue
        logger.info(
            "Audio source=%s candidate=%r artists=%r scores=title:%.2f,artist:%.2f,album:%.2f duration=%ss for %s - %s",
            source, candidate.title, candidate.artists, candidate.title_score,
            candidate.artist_score, candidate.album_score, candidate.seconds, track.artist, track.title,
        )
        return file_path, cover, False
    try:
        top_song = youtube_search(track)[0]
        secondary_song = youtube_plain_search(track)[0]
    except (IndexError, yt_dlp.utils.DownloadError, OSError):
        logger.warning("Could not verify fallback version for %s - %s", track.artist, track.title, exc_info=True)
        return None, None, False
    if any(version_signature(track.title) != version_signature(song.get("title") or "")
           for song in (top_song, secondary_song)):
        logger.warning("Rejected fallback version candidates=%r, %r for %s - %s",
                       top_song.get("title"), secondary_song.get("title"), track.artist, track.title)
        return None, None, False
    low_confidence = bool(track.durationMs)
    if low_confidence:
        logger.warning("low-confidence match source=fallback candidate=%r for %s - %s", top_song.get("title"), track.artist, track.title)
    set_progress(filename, "downloading", 50, "Downloading audio")
    file_path, cover = download_audio_with_ytdlp(
        track.artist, track.title, str(output_base), audio_format="m4a", need_thumbnail=need_thumbnail
    )
    return file_path, cover, low_confidence


def youtube_search(track: DownloadRequest) -> list[dict]:
    with yt_dlp.YoutubeDL({"extract_flat": True, "quiet": True, "no_warnings": True}) as ydl:
        search = ydl.extract_info(f"ytsearch5:{track.artist} - {track.title} Audio", download=False)
    return search.get("entries", [])


def youtube_plain_search(track: DownloadRequest) -> list[dict]:
    with yt_dlp.YoutubeDL({"extract_flat": True, "quiet": True, "no_warnings": True}) as ydl:
        search = ydl.extract_info(f"ytsearch1:{track.artist} - {track.title}", download=False)
    return search.get("entries", [])


def download_track(track: DownloadRequest, output_base: Path, expected_file: Path) -> tuple[str, bool]:
    if expected_file.is_file():
        set_progress(expected_file.name, "ready", 100, "Ready")
        return expected_file.name, False

    file_path, fallback_cover, low_confidence = download_matching_audio(track, output_base, True)
    if not file_path or not expected_file.is_file():
        raise RuntimeError("Download stream failed")

    set_progress(expected_file.name, "processing", 95, "Processing audio")
    cover_bytes = None
    if track.uri and track.uri.startswith("spotify:track:"):
        cover_bytes = fetch_spotify_hd_cover(track.uri)
    elif track.coverUrl:
        cover_bytes = download_cover(track.coverUrl)

    lyrics_text = None
    try:
        duration_sec = track.durationMs / 1000 if track.durationMs else None
        lyrics_text, _ = fetch_synced_lyrics(
            track.artist, track.title, track.album or "", duration_sec
        )
        if lyrics_text:
            save_lrc_file(str(output_base), lyrics_text)
    except Exception:
        logger.warning("Could not fetch lyrics for %s", expected_file.name, exc_info=True)

    embed_metadata(
        file_path,
        {
            "title": track.title,
            "artists": track.artist,
            "album": track.album or "",
            "date": "",
            "genre": "",
            "label": "",
            "uri": track.uri or "",
        },
        cover_bytes or fallback_cover,
        lyrics_text=lyrics_text,
        audio_format="m4a",
    )
    set_progress(expected_file.name, "ready", 100, "Ready")
    return expected_file.name, low_confidence


async def run_download(track: DownloadRequest, output_base: Path, expected_file: Path) -> tuple[str, bool]:
    async with download_slots:
        try:
            return await asyncio.to_thread(download_track, track, output_base, expected_file)
        except Exception as exc:
            set_progress(expected_file.name, "failed", 0, str(exc) or "Download failed")
            raise


def clear_finished_download(filename: str, finished: asyncio.Task[tuple[str, bool]]) -> None:
    if in_flight.get(filename) is finished:
        del in_flight[filename]


@app.get("/health")
def health() -> dict[str, bool]:
    return {"ok": True}


@app.get("/progress")
def get_progress(title: str, artist: str) -> dict:
    filename = filename_key(title, artist)
    with progress_lock:
        current = progress.get(filename)
        if current:
            return {key: current[key] for key in ("stage", "percent", "message")}
    if (music_dir / filename).is_file():
        return {"stage": "ready", "percent": 100, "message": "Ready"}
    return {"stage": "idle", "percent": 0, "message": ""}


@app.get("/lyrics")
async def get_lyrics(title: str, artist: str, album: str = "", duration: float | None = None) -> dict:
    title, artist, album = title.strip(), artist.strip(), album.strip()
    if not sanitize_filename(title) or not sanitize_filename(artist.replace(";", ", ")):
        raise HTTPException(status_code=422, detail="title and artist are required")

    audio_path = music_dir / filename_key(title, artist)
    lyrics_path = audio_path.with_suffix(".lrc")
    if lyrics_path.is_file():
        return lyrics_response(lyrics_path.read_text(encoding="utf-8"), "file")

    cache_key = (title, artist, album, duration)
    cached = lyrics_cache.get(cache_key)
    if cached and (cached[1] is not None or time.monotonic() - cached[0] < lyrics_miss_ttl):
        lyrics_cache.move_to_end(cache_key)
        if cached[1] is None:
            raise HTTPException(status_code=404, detail="Lyrics not found")
        if audio_path.is_file():
            save_lrc_file(str(lyrics_path.with_suffix("")), cached[1]["lrc"])
        return cached[1]

    try:
        found = await asyncio.wait_for(
            asyncio.to_thread(search_lyrics, title, artist, album, duration), timeout=15
        )
    except TimeoutError:
        logger.warning("Lyrics search timed out for %s - %s", artist, title)
        raise HTTPException(status_code=404, detail="Lyrics not found") from None

    if found and audio_path.is_file():
        save_lrc_file(str(lyrics_path.with_suffix("")), found["lrc"])
    lyrics_cache[cache_key] = (time.monotonic(), found)
    lyrics_cache.move_to_end(cache_key)
    if len(lyrics_cache) > lyrics_cache_limit:
        lyrics_cache.popitem(last=False)
    if found is None:
        raise HTTPException(status_code=404, detail="Lyrics not found")
    return found


@app.post("/download")
async def download(track: DownloadRequest) -> dict:
    title = track.title.strip()
    artist = track.artist.strip()
    filename = filename_key(title, artist)
    if not sanitize_filename(title) or not sanitize_filename(artist.replace(";", ", ")):
        raise HTTPException(status_code=422, detail="title and artist must contain valid filename characters")

    track = track.model_copy(update={"title": title, "artist": artist})
    expected_file = music_dir / filename
    task = in_flight.get(filename)
    if task is None:
        if expected_file.is_file():
            return {"status": "ready", "file": filename}
        try:
            music_dir.mkdir(parents=True, exist_ok=True)
        except OSError as exc:
            raise HTTPException(status_code=502, detail=f"Cannot create music directory: {exc}") from exc
        set_progress(filename, "searching", 5, "Searching for audio")
        task = asyncio.create_task(run_download(track, expected_file.with_suffix(""), expected_file))
        in_flight[filename] = task
        task.add_done_callback(lambda finished: clear_finished_download(filename, finished))

    try:
        file, low_confidence = await asyncio.shield(task)
        response = {"status": "ready", "file": file}
        if low_confidence:
            response["lowConfidence"] = True
        return response
    except Exception as exc:
        logger.exception("Download failed for %s", filename)
        raise HTTPException(status_code=502, detail=str(exc) or "Download failed") from exc
