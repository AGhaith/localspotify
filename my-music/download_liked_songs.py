#!/usr/bin/env python3
"""
High-Speed High-Quality Music Downloader with Official Spotify HD Artwork, Synced Lyrics & Rich Metadata
Reads Spotify export CSV (Liked_Songs.csv) and downloads tracks concurrently in highest quality
M4A (AAC) / MP3 / FLAC with 640x640 HD album artwork, synchronized .lrc lyrics, rich metadata, and real-time progress tracking.
"""

import os
import sys
import csv
import re
import io
import time
import argparse
import threading
import urllib.request
import urllib.parse
import json
from concurrent.futures import ThreadPoolExecutor, as_completed

try:
    from PIL import Image
except ImportError:
    print("Error: 'Pillow' library is required. Install it using: pip install Pillow")
    sys.exit(1)

try:
    import mutagen
    from mutagen.mp4 import MP4, MP4Cover
    from mutagen.mp3 import MP3
    from mutagen.id3 import ID3, APIC, TIT2, TPE1, TPE2, TALB, TDRC, TCON, TPUB, COMM, USLT
    from mutagen.flac import FLAC, Picture
except ImportError:
    print("Error: 'mutagen' library is required. Install it using: pip install mutagen")
    sys.exit(1)

try:
    import yt_dlp
except ImportError:
    print("Error: 'yt_dlp' library is required. Install it using: pip install yt-dlp")
    sys.exit(1)

# Optional syncedlyrics library for multi-source lyrics fallback
try:
    import syncedlyrics
    HAS_SYNCEDLYRICS = True
except ImportError:
    HAS_SYNCEDLYRICS = False


# Global print lock for thread-safe console logging
print_lock = threading.Lock()
shutdown_event = threading.Event()


def log(msg: str):
    """Thread-safe print helper."""
    with print_lock:
        print(msg, flush=True)


def format_bytes(num_bytes: float | int) -> str:
    """Formats bytes into human-readable MB / KB string."""
    if num_bytes is None or num_bytes <= 0:
        return "0.00 MB"
    mb = num_bytes / (1024 * 1024)
    if mb >= 1.0:
        return f"{mb:.2f} MB"
    kb = num_bytes / 1024
    return f"{kb:.1f} KB"


def sanitize_filename(name: str) -> str:
    """Removes invalid filesystem characters while preserving Unicode characters."""
    if not name:
        return ""
    # Remove filesystem forbidden chars: / \ : * ? " < > | and control characters
    sanitized = re.sub(r'[\/\\:*?"<>|\x00-\x1f]', '', name)
    sanitized = re.sub(r'\s+', ' ', sanitized).strip('. ')
    return sanitized


def process_cover_image(raw_bytes: bytes) -> bytes | None:
    """
    Validates and formats the cover image into a 1:1 square JPEG at high quality.
    Ensures 100% compatibility across all media players and music servers.
    """
    if not raw_bytes:
        return None
    try:
        with Image.open(io.BytesIO(raw_bytes)) as img:
            img = img.convert("RGB")
            w, h = img.size

            # Center crop to 1:1 square if not already square
            if w != h:
                min_dim = min(w, h)
                left = (w - min_dim) // 2
                top = (h - min_dim) // 2
                right = left + min_dim
                bottom = top + min_dim
                img = img.crop((left, top, right, bottom))

            # Ensure reasonable high-resolution bounds
            if img.size[0] > 1000:
                img = img.resize((1000, 1000), Image.Resampling.LANCZOS)

            buf = io.BytesIO()
            img.save(buf, format="JPEG", quality=95)
            return buf.getvalue()
    except Exception:
        return raw_bytes


def fetch_spotify_hd_cover(track_uri: str) -> bytes | None:
    """
    Fetches the 640x640 HD album artwork directly from Spotify CDN
    using the Spotify oEmbed API.
    """
    if not track_uri:
        return None

    track_id = track_uri.split(":")[-1].split("?")[0]
    oembed_url = f"https://open.spotify.com/oembed?url=https://open.spotify.com/track/{track_id}"
    req = urllib.request.Request(
        oembed_url,
        headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"}
    )

    try:
        with urllib.request.urlopen(req, timeout=6) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            thumb_url = data.get("thumbnail_url")
            if not thumb_url:
                return None

            # Spotify CDN sizes: ab67616d00001e02 (300x300) / ab67616d00004851 (64x64) -> ab67616d0000b273 (640x640 HD)
            hd_url = thumb_url.replace("ab67616d00001e02", "ab67616d0000b273").replace("ab67616d00004851", "ab67616d0000b273")

            img_req = urllib.request.Request(hd_url, headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"})
            with urllib.request.urlopen(img_req, timeout=6) as img_resp:
                raw_img = img_resp.read()
                return process_cover_image(raw_img)
    except Exception:
        # Fallback to standard thumbnail URL if HD URL fails
        try:
            if 'thumb_url' in locals() and thumb_url:
                fallback_req = urllib.request.Request(thumb_url, headers={"User-Agent": "Mozilla/5.0"})
                with urllib.request.urlopen(fallback_req, timeout=6) as fb_resp:
                    return process_cover_image(fb_resp.read())
        except Exception:
            pass
        return None


def fetch_synced_lyrics(artist: str, track: str, album: str = "", duration_sec: float | None = None) -> tuple[str | None, bool]:
    """
    Fetches synchronized (.lrc) or plain text lyrics.
    First tries LRCLIB API (free, open-source synced lyrics database),
    then falls back to syncedlyrics multi-provider if available.
    
    Returns: (lyrics_content, is_synced)
    """
    clean_artist = re.split(r'[;,]', artist)[0].strip() if artist else ""
    clean_track = re.sub(r'\(feat\..*?\)|\[feat\..*?\]', '', track, flags=re.IGNORECASE).strip()

    # 1. Try LRCLIB API Direct GET (Exact match)
    params = {
        "track_name": clean_track,
        "artist_name": clean_artist,
    }
    if album:
        params["album_name"] = album
    if duration_sec and duration_sec > 0:
        params["duration"] = int(duration_sec)

    query_str = urllib.parse.urlencode(params)
    url = f"https://lrclib.net/api/get?{query_str}"
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "LocalSpotify/1.0 (https://github.com/AGhaith/localspotify)"}
    )

    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            synced = data.get("syncedLyrics")
            plain = data.get("plainLyrics")
            if synced:
                return synced, True
            if plain:
                return plain, False
    except Exception:
        pass

    # 2. Try LRCLIB Search endpoint (Fuzzy match)
    search_q = urllib.parse.urlencode({"q": f"{clean_artist} {clean_track}"})
    search_url = f"https://lrclib.net/api/search?{search_q}"
    req_search = urllib.request.Request(
        search_url,
        headers={"User-Agent": "LocalSpotify/1.0 (https://github.com/AGhaith/localspotify)"}
    )
    try:
        with urllib.request.urlopen(req_search, timeout=5) as resp:
            results = json.loads(resp.read().decode('utf-8'))
            if isinstance(results, list) and len(results) > 0:
                best = results[0]
                synced = best.get("syncedLyrics")
                plain = best.get("plainLyrics")
                if synced:
                    return synced, True
                if plain:
                    return plain, False
    except Exception:
        pass

    # 3. Fallback: syncedlyrics library (Musixmatch / Deezer / NetEase) if installed
    if HAS_SYNCEDLYRICS:
        try:
            lrc_res = syncedlyrics.search(f"{clean_artist} {clean_track}")
            if lrc_res:
                is_synced = bool(re.search(r'\[\d{2}:\d{2}\.\d{2,3}\]', lrc_res))
                return lrc_res, is_synced
        except Exception:
            pass

    return None, False


def save_lrc_file(output_base: str, lyrics_text: str) -> str:
    """Saves synchronized or plain lyrics to a standard .lrc file for Navidrome."""
    lrc_path = f"{output_base}.lrc"
    try:
        with open(lrc_path, "w", encoding="utf-8") as f:
            f.write(lyrics_text.strip() + "\n")
        return lrc_path
    except Exception as e:
        log(f"  ⚠️ Could not write .lrc file: {e}")
        return ""


def download_audio_with_ytdlp(artist: str, track: str, output_base: str, audio_format: str = "m4a", need_thumbnail: bool = False) -> tuple[str | None, bytes | None]:
    """
    Downloads audio using yt-dlp Python API with optimized stream selection
    and automatic YouTube thumbnail fallback if needed.
    """
    expected_filepath = f"{output_base}.{audio_format}"
    thumb_path = f"{output_base}.jpg"

    # Prioritize native streams (e.g. M4A/AAC 140) to eliminate transcoding latency
    format_selector = (
        'bestaudio[ext=m4a]/bestaudio[ext=aac]/bestaudio/best'
        if audio_format in ('m4a', 'mp4')
        else 'bestaudio/best'
    )

    ydl_opts = {
        'format': format_selector,
        'outtmpl': f'{output_base}.%(ext)s',
        'postprocessors': [{
            'key': 'FFmpegExtractAudio',
            'preferredcodec': audio_format,
            'preferredquality': '0',
        }],
        'writethumbnail': need_thumbnail,
        'quiet': True,
        'no_warnings': True,
        'noprogress': True,
        'noplaylist': True,
        'socket_timeout': 10,
        'retries': 2,
        'concurrent_fragment_downloads': 2,
    }

    fallback_cover = None

    # Search with audio priority
    query = f"ytsearch1:{artist} - {track} Audio"
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            ydl.download([query])
    except Exception:
        # Secondary fallback search
        try:
            fallback_query = f"ytsearch1:{artist} - {track}"
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                ydl.download([fallback_query])
        except Exception:
            pass

    # Read and process fallback thumbnail if yt-dlp was requested to save one
    if need_thumbnail:
        if os.path.exists(thumb_path):
            try:
                with open(thumb_path, "rb") as tf:
                    fallback_cover = process_cover_image(tf.read())
                os.remove(thumb_path)
            except Exception:
                pass

        for ext in (".webp", ".png"):
            extra_thumb = f"{output_base}{ext}"
            if os.path.exists(extra_thumb):
                try:
                    if not fallback_cover:
                        with open(extra_thumb, "rb") as tf:
                            fallback_cover = process_cover_image(tf.read())
                    os.remove(extra_thumb)
                except Exception:
                    pass

    filepath = expected_filepath if os.path.exists(expected_filepath) else None
    return filepath, fallback_cover


def embed_metadata(filepath: str, metadata: dict, cover_bytes: bytes | None, lyrics_text: str | None = None, audio_format: str = "m4a"):
    """
    Embeds rich metadata, synchronized lyrics, and high-resolution cover artwork into M4A / MP3 / FLAC files.
    """
    title = metadata.get("title", "")
    artists = metadata.get("artists", "")
    album = metadata.get("album", "")
    date = metadata.get("date", "")
    genre = metadata.get("genre", "")
    label = metadata.get("label", "")
    uri = metadata.get("uri", "")

    album_artist = re.split(r'[;,]', artists)[0].strip() if artists else ""
    display_artists = artists.replace(";", ", ") if artists else ""

    if audio_format in ("m4a", "mp4"):
        try:
            audio = MP4(filepath)
            if title:
                audio["\xa9nam"] = title
            if display_artists:
                audio["\xa9ART"] = display_artists
            if album_artist:
                audio["aART"] = album_artist
            if album:
                audio["\xa9alb"] = album
            if date:
                audio["\xa9day"] = date
            if genre:
                audio["\xa9gen"] = genre
            if label:
                audio["cprt"] = label
            if uri:
                audio["\xa9cmt"] = uri
            if lyrics_text:
                audio["\xa9lyr"] = lyrics_text

            if cover_bytes:
                audio["covr"] = [MP4Cover(cover_bytes, imageformat=MP4Cover.FORMAT_JPEG)]
            audio.save()
        except Exception as e:
            log(f"  ⚠️ Failed to embed M4A tags for {filepath}: {e}")

    elif audio_format == "mp3":
        try:
            audio = MP3(filepath, ID3=ID3)
            try:
                audio.add_tags()
            except Exception:
                pass

            if title:
                audio.tags.add(TIT2(encoding=3, text=title))
            if display_artists:
                audio.tags.add(TPE1(encoding=3, text=display_artists))
            if album_artist:
                audio.tags.add(TPE2(encoding=3, text=album_artist))
            if album:
                audio.tags.add(TALB(encoding=3, text=album))
            if date:
                audio.tags.add(TDRC(encoding=3, text=date))
            if genre:
                audio.tags.add(TCON(encoding=3, text=genre))
            if label:
                audio.tags.add(TPUB(encoding=3, text=label))
            if uri:
                audio.tags.add(COMM(encoding=3, lang="eng", desc="Spotify URI", text=uri))
            if lyrics_text:
                audio.tags.add(USLT(encoding=3, lang="eng", desc="Lyrics", text=lyrics_text))

            if cover_bytes:
                audio.tags.add(APIC(
                    encoding=3,
                    mime="image/jpeg",
                    type=3,  # Front cover
                    desc="Cover",
                    data=cover_bytes
                ))
            audio.save(v2_version=3)
        except Exception as e:
            log(f"  ⚠️ Failed to embed MP3 tags for {filepath}: {e}")

    elif audio_format == "flac":
        try:
            audio = FLAC(filepath)
            if title:
                audio["title"] = title
            if display_artists:
                audio["artist"] = display_artists
            if album_artist:
                audio["albumartist"] = album_artist
            if album:
                audio["album"] = album
            if date:
                audio["date"] = date
            if genre:
                audio["genre"] = genre
            if label:
                audio["organization"] = label
            if uri:
                audio["comment"] = uri
            if lyrics_text:
                audio["lyrics"] = lyrics_text

            if cover_bytes:
                pic = Picture()
                pic.type = 3
                pic.mime = "image/jpeg"
                pic.desc = "Cover"
                pic.data = cover_bytes
                audio.clear_pictures()
                audio.add_picture(pic)
            audio.save()
        except Exception as e:
            log(f"  ⚠️ Failed to embed FLAC tags for {filepath}: {e}")


class ProgressTracker:
    """Thread-safe tracker for progress statistics and downloaded megabytes."""

    def __init__(self, total_tasks: int):
        self.lock = threading.Lock()
        self.total_tasks = total_tasks
        self.completed_count = 0
        self.downloaded_count = 0
        self.skipped_count = 0
        self.failed_count = 0
        self.lyrics_count = 0
        self.total_bytes = 0
        self.start_time = time.time()

    def record_skip(self, track_display: str):
        with self.lock:
            self.completed_count += 1
            self.skipped_count += 1
            idx = self.completed_count
            pct = (idx / self.total_tasks) * 100 if self.total_tasks else 100
        log(f"[{idx:>3}/{self.total_tasks}] ({pct:5.1f}%) ⏩ Skipping (Already exists): {track_display}")

    def record_success(self, track_display: str, file_size: int, cover_source: str, has_lyrics: bool, is_synced: bool, duration_sec: float):
        with self.lock:
            self.completed_count += 1
            self.downloaded_count += 1
            if has_lyrics:
                self.lyrics_count += 1
            self.total_bytes += file_size
            idx = self.completed_count
            total_mb_str = format_bytes(self.total_bytes)
            pct = (idx / self.total_tasks) * 100 if self.total_tasks else 100
            elapsed = max(0.1, time.time() - self.start_time)
            mb_sec = (self.total_bytes / (1024 * 1024)) / elapsed

        size_str = format_bytes(file_size)
        lyric_tag = " [📜 Synced .lrc]" if is_synced else (" [📄 Lyrics]" if has_lyrics else "")
        log(f"[{idx:>3}/{self.total_tasks}] ({pct:5.1f}%) ✨ {track_display} | 🎵 {size_str} [{cover_source}]{lyric_tag} ({duration_sec:.1f}s) | 📦 Total: {total_mb_str} ({mb_sec:.2f} MB/s)")

    def record_failure(self, track_display: str, reason: str = "Download failed"):
        with self.lock:
            self.completed_count += 1
            self.failed_count += 1
            idx = self.completed_count
            pct = (idx / self.total_tasks) * 100 if self.total_tasks else 100
        log(f"[{idx:>3}/{self.total_tasks}] ({pct:5.1f}%) ❌ {reason}: {track_display}")


def process_track(task_info: dict, tracker: ProgressTracker, audio_format: str, save_jpg: bool, enable_lyrics: bool = True) -> bool:
    """Worker task to process a single song end-to-end (audio + HD cover + synced lyrics + ID3)."""
    if shutdown_event.is_set():
        return False

    row = task_info["row"]
    track_name = (row.get("Track Name") or "").strip()
    artists = (row.get("Artist Name(s)") or "").strip()
    album_name = (row.get("Album Name") or "").strip()
    release_date = (row.get("Release Date") or "").strip()
    genres = (row.get("Genres") or "").strip()
    label = (row.get("Record Label") or "").strip()
    track_uri = (row.get("Track URI") or row.get("\ufeffTrack URI") or "").strip()

    if not track_name or not artists:
        return False

    clean_track = sanitize_filename(track_name)
    clean_artist = sanitize_filename(artists.replace(";", ", "))
    output_base = f"{clean_artist} - {clean_track}"
    expected_file = f"{output_base}.{audio_format}"
    display_title = f"{artists} - {track_name}"

    # Check if already downloaded
    if os.path.exists(expected_file):
        # If lyrics are enabled and .lrc is missing, try fetching lyrics only
        if enable_lyrics and not os.path.exists(f"{output_base}.lrc"):
            lyrics_text, is_synced = fetch_synced_lyrics(artists, track_name, album_name)
            if lyrics_text:
                save_lrc_file(output_base, lyrics_text)
                log(f"  📜 Added missing lyrics for: {display_title}")
        tracker.record_skip(display_title)
        return True

    t0 = time.time()

    # 1. Fetch Spotify HD Cover Art (640x640)
    cover_bytes = fetch_spotify_hd_cover(track_uri)
    cover_source = "Spotify HD 640x640" if cover_bytes else "YouTube Thumb"

    # 2. Fetch Synced Lyrics (LRCLIB / Syncedlyrics) concurrently
    lyrics_text = None
    is_synced = False
    if enable_lyrics:
        try:
            lyrics_text, is_synced = fetch_synced_lyrics(artists, track_name, album_name)
            if lyrics_text:
                save_lrc_file(output_base, lyrics_text)
        except Exception:
            pass

    if shutdown_event.is_set():
        return False

    # 3. Download audio stream (only fetch YouTube thumb if Spotify HD cover failed)
    file_path, fallback_cover = download_audio_with_ytdlp(
        artists, track_name, output_base, audio_format=audio_format, need_thumbnail=(cover_bytes is None)
    )

    if shutdown_event.is_set():
        # Clean up partial if interrupted
        if file_path and os.path.exists(file_path):
            try:
                os.remove(file_path)
            except Exception:
                pass
        return False

    if not file_path or not os.path.exists(file_path):
        tracker.record_failure(display_title, "Download stream failed")
        return False

    file_size = os.path.getsize(file_path)
    final_cover = cover_bytes or fallback_cover

    # Optional standalone artwork save
    if save_jpg and final_cover:
        jpg_path = f"{output_base}.jpg"
        try:
            with open(jpg_path, "wb") as img_file:
                img_file.write(final_cover)
        except Exception:
            pass

    # 4. Embed metadata, lyrics & artwork
    metadata = {
        "title": track_name,
        "artists": artists,
        "album": album_name,
        "date": release_date,
        "genre": genres,
        "label": label,
        "uri": track_uri
    }
    embed_metadata(file_path, metadata, final_cover, lyrics_text=lyrics_text, audio_format=audio_format)

    # Re-calculate size after embedding metadata and cover
    try:
        file_size = os.path.getsize(file_path)
    except Exception:
        pass

    duration_sec = time.time() - t0
    tracker.record_success(display_title, file_size, cover_source, bool(lyrics_text), is_synced, duration_sec)
    return True


def fetch_lyrics_for_existing_files(directory: str = "."):
    """Scans all audio files in the directory and downloads missing .lrc files."""
    audio_exts = (".mp3", ".m4a", ".flac", ".opus", ".ogg")
    files = [f for f in os.listdir(directory) if f.lower().endswith(audio_exts)]
    
    log("=" * 70)
    log(f"📜 Scanning {len(files)} local songs for missing synced lyrics...")
    log("=" * 70)

    count_added = 0
    for filename in files:
        base_name, _ = os.path.splitext(filename)
        lrc_file = os.path.join(directory, f"{base_name}.lrc")
        if os.path.exists(lrc_file):
            continue

        parts = base_name.split(" - ", 1)
        if len(parts) == 2:
            artist, title = parts[0].strip(), parts[1].strip()
        else:
            artist, title = "", base_name.strip()

        lyrics_text, is_synced = fetch_synced_lyrics(artist, title)
        if lyrics_text:
            save_lrc_file(os.path.join(directory, base_name), lyrics_text)
            sync_tag = "⚡ Synced" if is_synced else "Plain"
            log(f"  ✔ [{sync_tag}] Downloaded lyrics for: {base_name}")
            count_added += 1
        else:
            log(f"  ❌ No lyrics found for: {base_name}")

    log("=" * 70)
    log(f"🎉 Lyrics scan finished: {count_added} new .lrc files saved!")
    log("=" * 70)


def main():
    parser = argparse.ArgumentParser(
        description="High-Speed Spotify tracks downloader with HD cover art, synchronized .lrc lyrics, rich tags, and parallel downloads."
    )
    parser.add_argument("--csv", "-c", default="Liked_Songs.csv", help="Path to Liked_Songs.csv (default: Liked_Songs.csv)")
    parser.add_argument("--format", "-f", default="m4a", choices=["m4a", "mp3", "flac"], help="Audio format (default: m4a)")
    parser.add_argument("--workers", "-w", type=int, default=5, help="Number of concurrent download threads (default: 5)")
    parser.add_argument("--save-jpg", action="store_true", help="Also save standalone .jpg album artwork file alongside song")
    parser.add_argument("--no-lyrics", action="store_true", help="Disable automatic lyrics downloading and .lrc generation")
    parser.add_argument("--lyrics-only", action="store_true", help="Only scan existing downloaded files and fetch missing .lrc lyrics")
    parser.add_argument("--limit", "-n", type=int, default=0, help="Limit number of tracks to download (0 for all)")
    parser.add_argument("--start", "-s", type=int, default=1, help="Start from row index (1-based, default: 1)")
    args = parser.parse_args()

    # Lyrics-only mode
    if args.lyrics_only:
        fetch_lyrics_for_existing_files(".")
        return

    csv_file = args.csv
    audio_format = args.format.lower()
    num_workers = max(1, min(args.workers, 16))
    enable_lyrics = not args.no_lyrics

    if not os.path.exists(csv_file):
        print(f"Error: CSV file '{csv_file}' not found.")
        sys.exit(1)

    with open(csv_file, mode="r", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        rows = list(reader)

    total_csv_tracks = len(rows)
    end_idx = total_csv_tracks if args.limit <= 0 else min(total_csv_tracks, args.start - 1 + args.limit)
    selected_rows = rows[args.start - 1 : end_idx]
    total_selected = len(selected_rows)

    print("=" * 70)
    print(f"⚡ High-Speed Spotify Music & Lyrics Downloader")
    print(f"📁 CSV File      : {csv_file} ({total_csv_tracks} total, {total_selected} selected)")
    print(f"🚀 Concurrency   : {num_workers} parallel worker threads")
    print(f"🎵 Audio Format  : {audio_format.upper()} (Optimized stream)")
    print(f"🖼️ Cover Art     : Spotify HD 640x640 (Embedded{' + Standalone .jpg' if args.save_jpg else ''})")
    print(f"📜 Synced Lyrics : {'Enabled (LRCLIB + Embedded + .lrc sidecar)' if enable_lyrics else 'Disabled'}")
    print(f"🏷️ Metadata     : Complete ID3/MP4 tags (Title, Artist, Album, Date, Genre, Label)")
    print("=" * 70)
    print("Starting download pool...\n")

    tracker = ProgressTracker(total_tasks=total_selected)
    tasks = [{"index": idx + 1, "row": row} for idx, row in enumerate(selected_rows, start=args.start)]

    try:
        with ThreadPoolExecutor(max_workers=num_workers) as executor:
            futures = [
                executor.submit(process_track, task, tracker, audio_format, args.save_jpg, enable_lyrics)
                for task in tasks
            ]
            for future in as_completed(futures):
                if shutdown_event.is_set():
                    break
                try:
                    future.result()
                except Exception as e:
                    log(f"⚠️ Worker error: {e}")

    except KeyboardInterrupt:
        shutdown_event.set()
        print("\n\n🛑 Process interrupted by user. Stopping active threads safely...")

    total_time = max(0.1, time.time() - tracker.start_time)
    print("\n" + "=" * 70)
    print(f"🎉 Summary:")
    print(f"   Downloaded : {tracker.downloaded_count} tracks ({format_bytes(tracker.total_bytes)})")
    print(f"   Lyrics     : {tracker.lyrics_count} synchronized .lrc lyrics generated")
    print(f"   Skipped    : {tracker.skipped_count} tracks (already existed)")
    print(f"   Failed     : {tracker.failed_count} tracks")
    print(f"   Processed  : {tracker.completed_count} / {total_selected} tracks")
    print(f"   Total Time : {int(total_time // 60)}m {int(total_time % 60)}s (avg {(tracker.total_bytes / (1024 * 1024)) / total_time:.2f} MB/s)")
    print("=" * 70)


if __name__ == "__main__":
    main()