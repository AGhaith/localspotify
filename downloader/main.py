import asyncio
from difflib import SequenceMatcher
import logging
import os
import re
import unicodedata
import urllib.request
from pathlib import Path
from typing import NamedTuple

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
import yt_dlp
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
in_flight: dict[str, asyncio.Task[str]] = {}
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


class AudioCandidate(NamedTuple):
    video_id: str
    title: str
    artists: list[str]
    seconds: float
    title_score: float
    artist_score: float
    album_score: float


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
    seconds = song.get("duration_seconds" if source == "ytmusic" else "duration")
    video_id = song.get("videoId" if source == "ytmusic" else "id")
    tolerance = 3 if source == "ytmusic" else 15
    if not video_id or not isinstance(seconds, (int, float)) or abs(seconds - duration) > tolerance:
        return None
    if version_terms(track.title) != version_terms(title):
        return None
    artists = ([artist.get("name", "") for artist in song.get("artists", [])]
               if source == "ytmusic" else [song.get("uploader") or song.get("channel") or ""])
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
    return candidate


def download_video(video_id: str, output_base: Path, need_thumbnail: bool) -> tuple[str | None, bytes | None]:
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
    }
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


def download_matching_audio(track: DownloadRequest, output_base: Path, need_thumbnail: bool) -> tuple[str | None, bytes | None]:
    duration = track.durationMs / 1000 if track.durationMs else None
    if duration:
        searches = (
            ("ytmusic", lambda: ytmusic.search(f"{track.artist} {track.title}", filter="songs", limit=5)[:5]),
            ("youtube", lambda: youtube_search(track)),
        )
        for source, search in searches:
            try:
                songs = search()
            except Exception:
                logger.warning("%s search failed for %s - %s", source, track.artist, track.title, exc_info=True)
                continue
            for song in songs:
                candidate = accepted_candidate(track, source, song, duration)
                if candidate is None:
                    continue
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
                return file_path, cover
    logger.info("Audio source=fallback candidate=unknown artists=unknown scores=unknown duration=unknown for %s - %s", track.artist, track.title)
    return download_audio_with_ytdlp(
        track.artist, track.title, str(output_base), audio_format="m4a", need_thumbnail=need_thumbnail
    )


def youtube_search(track: DownloadRequest) -> list[dict]:
    with yt_dlp.YoutubeDL({"extract_flat": True, "quiet": True, "no_warnings": True}) as ydl:
        search = ydl.extract_info(f"ytsearch5:{track.artist} - {track.title} Audio", download=False)
    return search.get("entries", [])


def download_track(track: DownloadRequest, output_base: Path, expected_file: Path) -> str:
    if expected_file.is_file():
        return expected_file.name

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

    file_path, fallback_cover = download_matching_audio(track, output_base, cover_bytes is None)
    if not file_path or not expected_file.is_file():
        raise RuntimeError("Download stream failed")

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
    return expected_file.name


async def run_download(track: DownloadRequest, output_base: Path, expected_file: Path) -> str:
    async with download_slots:
        return await asyncio.to_thread(download_track, track, output_base, expected_file)


def clear_finished_download(filename: str, finished: asyncio.Task[str]) -> None:
    if in_flight.get(filename) is finished:
        del in_flight[filename]


@app.get("/health")
def health() -> dict[str, bool]:
    return {"ok": True}


@app.post("/download")
async def download(track: DownloadRequest) -> dict[str, str]:
    title = track.title.strip()
    artist = track.artist.strip()
    clean_title = sanitize_filename(title)
    clean_artist = sanitize_filename(artist.replace(";", ", "))
    if not clean_title or not clean_artist:
        raise HTTPException(status_code=422, detail="title and artist must contain valid filename characters")

    track = track.model_copy(update={"title": title, "artist": artist})
    filename = f"{clean_artist} - {clean_title}.m4a"
    expected_file = music_dir / filename
    task = in_flight.get(filename)
    if task is None:
        if expected_file.is_file():
            return {"status": "ready", "file": filename}
        try:
            music_dir.mkdir(parents=True, exist_ok=True)
        except OSError as exc:
            raise HTTPException(status_code=502, detail=f"Cannot create music directory: {exc}") from exc
        task = asyncio.create_task(run_download(track, expected_file.with_suffix(""), expected_file))
        in_flight[filename] = task
        task.add_done_callback(lambda finished: clear_finished_download(filename, finished))

    try:
        file = await asyncio.shield(task)
        return {"status": "ready", "file": file}
    except Exception as exc:
        logger.exception("Download failed for %s", filename)
        raise HTTPException(status_code=502, detail=str(exc) or "Download failed") from exc
