#!/usr/bin/env python3
"""
Spotify Playlist Importer for LocalSpotify Music Vault
Fetches public Spotify playlist tracklists, downloads high-fidelity audio streams
via yt-dlp, embeds HD album artwork & metadata tags into audio files, triggers
Navidrome library scan, and links the playlist on the user's account.
"""

import os
import sys
import json
import re
import urllib.request
import urllib.parse
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed

# Try importing dependencies
try:
    import yt_dlp
except ImportError:
    print("Warning: yt-dlp is required for downloading audio.")

try:
    import mutagen
    from mutagen.mp4 import MP4, MP4Cover
    from mutagen.mp3 import MP3
    from mutagen.id3 import ID3, TIT2, TPE1, TPE2, TALB, TRCK, APIC
except ImportError:
    print("Warning: mutagen is required for tagging audio files.")


def parse_spotify_playlist_id(url_or_id: str) -> str | None:
    """Extract 22-char Spotify playlist ID from URL or URI."""
    clean = url_or_id.strip()
    m_url = re.search(r'open\.spotify\.com/playlist/([a-zA-Z0-9]+)', clean)
    if m_url:
        return m_url.group(1)
    m_uri = re.search(r'spotify:playlist:([a-zA-Z0-9]+)', clean)
    if m_uri:
        return m_uri.group(1)
    if re.match(r'^[a-zA-Z0-9]{15,30}$', clean):
        return clean
    return None


def fetch_track_artwork(track_uri: str) -> str | None:
    """Fetches high-res cover image URL from Spotify track embed."""
    try:
        clean_id = track_uri.split(":")[-1] if ":" in track_uri else track_uri
        embed_url = f"https://open.spotify.com/embed/track/{clean_id}"
        req = urllib.request.Request(
            embed_url,
            headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"}
        )
        with urllib.request.urlopen(req, timeout=8) as resp:
            html = resp.read().decode('utf-8')

        marker = '<script id="__NEXT_DATA__" type="application/json">'
        start = html.find(marker)
        if start == -1:
            return None

        end = html.find('</script>', start)
        json_str = html[start + len(marker):end]
        data = json.loads(json_str)
        entity = data.get("props", {}).get("pageProps", {}).get("state", {}).get("data", {}).get("entity", {})
        images = entity.get("visualIdentity", {}).get("image", [])
        if images:
            # Pick highest resolution image
            return images[-1].get("url") or images[0].get("url")
    except Exception:
        pass
    return None


def fetch_spotify_playlist(playlist_id: str) -> dict:
    """Fetches tracklist, title, and cover image from Spotify public embed API."""
    embed_url = f"https://open.spotify.com/embed/playlist/{playlist_id}"
    req = urllib.request.Request(
        embed_url,
        headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"}
    )
    with urllib.request.urlopen(req, timeout=12) as resp:
        html = resp.read().decode('utf-8')

    marker = '<script id="__NEXT_DATA__" type="application/json">'
    start = html.find(marker)
    if start == -1:
        raise ValueError("Could not find Spotify playlist metadata in embed payload.")

    end = html.find('</script>', start)
    json_str = html[start + len(marker):end]
    data = json.loads(json_str)

    entity = data["props"]["pageProps"]["state"]["data"]["entity"]
    title = entity.get("title", "Imported Playlist")
    subtitle = entity.get("subtitle", "")
    track_list = entity.get("trackList", [])

    cover_url = None
    images = entity.get("visualIdentity", {}).get("image", [])
    if images:
        cover_url = images[-1].get("url") or images[0].get("url")

    tracks = []
    for t in track_list:
        tracks.append({
            "title": t.get("title", "Unknown Title"),
            "artist": t.get("subtitle", "Unknown Artist"),
            "duration_ms": t.get("duration", 0),
            "uri": t.get("uri", ""),
            "cover_url": None,
        })

    # Concurrently resolve track-specific cover art for top 50 tracks
    print(f"[INFO] Resolving individual track artwork for {len(tracks)} tracks...")
    with ThreadPoolExecutor(max_workers=8) as executor:
        futures = {
            executor.submit(fetch_track_artwork, t["uri"]): t
            for t in tracks if t["uri"]
        }
        for fut in as_completed(futures):
            t = futures[fut]
            try:
                art = fut.result()
                if art:
                    t["cover_url"] = art
            except Exception:
                pass

    return {
        "id": playlist_id,
        "title": title,
        "subtitle": subtitle,
        "cover_url": cover_url,
        "tracks": tracks
    }


def sanitize_name(name: str) -> str:
    """Sanitize directory and file names."""
    return re.sub(r'[\/\\:*?"<>|\x00-\x1f]', '', name).strip('. ')


def tag_audio_file(
    filepath: str,
    title: str,
    artist: str,
    album: str,
    track_num: int,
    total_tracks: int,
    cover_bytes: bytes | None
):
    """Embeds ID3 / MP4 tags and cover art into the downloaded audio file."""
    try:
        lower = filepath.lower()
        if lower.endswith(".m4a") or lower.endswith(".mp4"):
            audio = MP4(filepath)
            audio['\xa9nam'] = [title]
            audio['\xa9ART'] = [artist]
            audio['\xa9aART'] = [artist]
            audio['\xa9alb'] = [album]
            audio['trkn'] = [(track_num, total_tracks)]
            if cover_bytes:
                fmt = MP4Cover.FORMAT_PNG if cover_bytes.startswith(b'\x89PNG') else MP4Cover.FORMAT_JPEG
                audio['covr'] = [MP4Cover(cover_bytes, image_format=fmt)]
            audio.save()
        elif lower.endswith(".mp3"):
            audio = MP3(filepath, ID3=ID3)
            try:
                audio.add_tags()
            except Exception:
                pass
            audio.tags.add(TIT2(encoding=3, text=title))
            audio.tags.add(TPE1(encoding=3, text=artist))
            audio.tags.add(TPE2(encoding=3, text=artist))
            audio.tags.add(TALB(encoding=3, text=album))
            audio.tags.add(TRCK(encoding=3, text=f"{track_num}/{total_tracks}"))
            if cover_bytes:
                mime = 'image/png' if cover_bytes.startswith(b'\x89PNG') else 'image/jpeg'
                audio.tags.add(APIC(encoding=3, mime=mime, type=3, desc='Cover', data=cover_bytes))
            audio.save()
    except Exception as e:
        print(f"  [WARN] Could not embed tags into '{filepath}': {e}")


def find_existing_track_in_vault(title: str, artist: str, music_folder: str) -> str | None:
    """Scan music folder to find any existing audio file matching artist/title."""
    if not music_folder or not os.path.exists(music_folder):
        return None
    clean_title = sanitize_name(title).lower()
    clean_artist = sanitize_name(artist).lower()

    for root, _, files in os.walk(music_folder):
        for f in files:
            lower_f = f.lower()
            if any(lower_f.endswith(ext) for ext in ['.m4a', '.mp3', '.flac', '.ogg', '.opus', '.wav']):
                if clean_title in lower_f and (clean_artist in lower_f or clean_artist in root.lower()):
                    return os.path.join(root, f)
    return None


def download_single_track(
    track: dict,
    output_dir: str,
    playlist_title: str,
    track_index: int,
    total_tracks: int,
    fallback_cover_url: str | None,
    cached_cover_bytes: bytes | None = None,
    music_folder: str = "./my-music"
) -> str | None:
    """Download single track via yt-dlp into M4A audio or reuse existing vault file."""
    title = track["title"]
    artist = track["artist"]
    clean_title = sanitize_name(title)
    clean_artist = sanitize_name(artist)

    output_base = os.path.join(output_dir, f"{clean_artist} - {clean_title}")
    expected_path = f"{output_base}.m4a"

    # Download cover image bytes
    cover_bytes = cached_cover_bytes
    track_art_url = track.get("cover_url") or fallback_cover_url
    if track.get("cover_url") and track.get("cover_url") != fallback_cover_url:
        try:
            req = urllib.request.Request(
                track["cover_url"],
                headers={"User-Agent": "Mozilla/5.0"}
            )
            with urllib.request.urlopen(req, timeout=8) as r:
                cover_bytes = r.read()
        except Exception:
            cover_bytes = cached_cover_bytes

    if os.path.exists(expected_path):
        # Re-tag existing file to ensure metadata & thumbnails are present
        tag_audio_file(expected_path, title, artist, playlist_title, track_index, total_tracks, cover_bytes)
        return expected_path

    # Check if already present anywhere in music vault
    existing_vault_file = find_existing_track_in_vault(title, artist, music_folder)
    if existing_vault_file and os.path.exists(existing_vault_file):
        print(f"  [REUSE EXISTING] '{title}' by {artist} already exists in library: {existing_vault_file}")
        try:
            if os.path.abspath(existing_vault_file) != os.path.abspath(expected_path):
                import shutil
                shutil.copy2(existing_vault_file, expected_path)
                tag_audio_file(expected_path, title, artist, playlist_title, track_index, total_tracks, cover_bytes)
            return expected_path
        except Exception:
            return existing_vault_file

    ydl_opts = {
        'format': 'bestaudio[ext=m4a]/bestaudio/best',
        'outtmpl': f'{output_base}.%(ext)s',
        'postprocessors': [{
            'key': 'FFmpegExtractAudio',
            'preferredcodec': 'm4a',
        }],
        'quiet': True,
        'no_warnings': True,
        'noprogress': True,
        'noplaylist': True,
        'socket_timeout': 15,
        'retries': 3,
    }

    expected_duration = track.get("duration_ms", 0) / 1000.0 if track.get("duration_ms") else 0
    queries = [
        f"ytsearch5:{artist} - {title} Official Audio",
        f"ytsearch5:{artist} - {title} Topic",
        f"ytsearch5:{artist} - {title}",
    ]

    selected_video_url = None
    search_ydl_opts = {
        'extract_flat': True,
        'quiet': True,
        'no_warnings': True,
        'socket_timeout': 10,
    }

    for query in queries:
        try:
            with yt_dlp.YoutubeDL(search_ydl_opts) as ydl:
                info = ydl.extract_info(query, download=False)
                entries = info.get('entries', []) if info else []
                for entry in entries:
                    if not entry:
                        continue
                    v_title = entry.get('title', '').lower()
                    v_duration = entry.get('duration', 0) or 0

                    # Check duration match
                    if expected_duration > 20 and v_duration > 0:
                        if abs(v_duration - expected_duration) > 15:
                            continue

                    # Filter forbidden keywords unless present in target title
                    t_lower = title.lower()
                    if 'cover' not in t_lower and any(w in v_title for w in ['cover', 'karaoke', 'tutorial', 'parody', 'reaction']):
                        continue
                    if 'live' not in t_lower and any(w in v_title for w in ['live at', 'live in', 'live from', 'concert']):
                        continue
                    if 'remix' not in t_lower and any(w in v_title for w in ['remix', 'slowed', 'speed up', 'reverb', 'bass boosted']):
                        continue
                    if any(w in v_title for w in ['1 hour', '10 hour', 'loop', 'full album']):
                        continue

                    v_id = entry.get('id')
                    if v_id:
                        selected_video_url = f"https://www.youtube.com/watch?v={v_id}"
                        break
        except Exception:
            pass

        if selected_video_url:
            break

    download_target = selected_video_url or f"ytsearch1:{artist} - {title} Official Audio"

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            ydl.download([download_target])
    except Exception as e:
        print(f"  Failed downloading '{title}' by {artist}: {e}")
        return None

    if os.path.exists(expected_path):
        tag_audio_file(expected_path, title, artist, playlist_title, track_index, total_tracks, cover_bytes)
        return expected_path

    return None


def sync_navidrome_playlist(
    playlist_name: str,
    track_titles: list[str],
    server_url: str = "http://localhost:6767",
    user: str = "admin",
    password: str = "admin"
):
    """Triggers Navidrome scan, matches downloaded tracks, and creates/updates playlist."""
    import time
    try:
        clean_url = server_url.rstrip("/")
        auth_params = f"u={user}&p={password}&v=1.16.1&c=LocalSpotify&f=json"

        # 1. Trigger Scan
        print(f"[INFO] Triggering library scan on {clean_url}...")
        req = urllib.request.Request(f"{clean_url}/rest/startScan.view?{auth_params}")
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            print(f"[OK] Scan initiated: {data.get('subsonic-response', {}).get('status')}")

        # 2. Poll for scan completion (up to 30 seconds)
        print("[INFO] Waiting for library indexing...")
        for _ in range(15):
            time.sleep(2)
            try:
                status_req = urllib.request.Request(f"{clean_url}/rest/getScanStatus.view?{auth_params}")
                with urllib.request.urlopen(status_req, timeout=5) as s_resp:
                    s_data = json.loads(s_resp.read().decode("utf-8"))
                    scan_info = s_data.get("subsonic-response", {}).get("scanStatus", {})
                    if not scan_info.get("scanning", False):
                        print(f"[OK] Indexing completed. Indexed {scan_info.get('count', 0)} files.")
                        break
            except Exception:
                pass

        # 3. Search for downloaded track IDs
        matched_song_ids = []
        for title in track_titles:
            try:
                search_query = urllib.parse.quote(title)
                search_req = urllib.request.Request(f"{clean_url}/rest/search3.view?{auth_params}&query={search_query}")
                with urllib.request.urlopen(search_req, timeout=5) as q_resp:
                    q_data = json.loads(q_resp.read().decode("utf-8"))
                    songs = q_data.get("subsonic-response", {}).get("searchResult3", {}).get("song", [])
                    if songs and isinstance(songs, list):
                        matched_song_ids.append(songs[0]["id"])
            except Exception:
                pass

        print(f"[INFO] Matched {len(matched_song_ids)} tracks in library catalog.")

        # 4. Find existing playlist or create new one
        pl_req = urllib.request.Request(f"{clean_url}/rest/getPlaylists.view?{auth_params}")
        existing_pl_id = None
        with urllib.request.urlopen(pl_req, timeout=5) as p_resp:
            p_data = json.loads(p_resp.read().decode("utf-8"))
            pls = p_data.get("subsonic-response", {}).get("playlists", {}).get("playlist", [])
            for p in pls:
                if p.get("name", "").lower() == playlist_name.lower():
                    existing_pl_id = p.get("id")
                    break

        if existing_pl_id and matched_song_ids:
            # Update existing playlist
            for s_id in matched_song_ids:
                up_req = urllib.request.Request(f"{clean_url}/rest/updatePlaylist.view?{auth_params}&playlistId={existing_pl_id}&songIdToAdd={s_id}")
                urllib.request.urlopen(up_req, timeout=5)
            print(f"[OK] Added {len(matched_song_ids)} songs to existing playlist '{playlist_name}'.")
        elif matched_song_ids:
            # Create new playlist
            param_songs = "&".join([f"songId={s_id}" for s_id in matched_song_ids])
            enc_name = urllib.parse.quote(playlist_name)
            create_req = urllib.request.Request(f"{clean_url}/rest/createPlaylist.view?{auth_params}&name={enc_name}&{param_songs}")
            urllib.request.urlopen(create_req, timeout=5)
            print(f"[OK] Created playlist '{playlist_name}' with {len(matched_song_ids)} tracks.")
        else:
            print(f"[WARN] No songs matched yet to add to playlist '{playlist_name}'.")
    except Exception as e:
        print(f"[WARN] Navidrome playlist synchronization skipped: {e}")


def import_playlist(
    url_or_id: str,
    music_folder: str = "./my-music",
    max_workers: int = 4,
    server_url: str = "http://localhost:6767",
    sync_server: bool = True
):
    """Orchestrate downloading Spotify playlist into local music directory."""
    playlist_id = parse_spotify_playlist_id(url_or_id)
    if not playlist_id:
        print("Error: Invalid Spotify playlist URL or ID.")
        return

    print(f"[INFO] Resolving Spotify playlist {playlist_id}...")
    info = fetch_spotify_playlist(playlist_id)
    total_tracks = len(info["tracks"])
    print(f"[OK] Found playlist: '{info['title']}' with {total_tracks} tracks")

    playlist_folder = os.path.join(music_folder, sanitize_name(info["title"]))
    os.makedirs(playlist_folder, exist_ok=True)

    # Download playlist cover.jpg for folder-level indexing
    cached_cover_bytes = None
    if info.get("cover_url"):
        try:
            req = urllib.request.Request(info["cover_url"], headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=10) as r:
                cached_cover_bytes = r.read()
            cover_file = os.path.join(playlist_folder, "cover.jpg")
            with open(cover_file, "wb") as f:
                f.write(cached_cover_bytes)
            print(f"[OK] Saved playlist cover art: {cover_file}")
        except Exception as e:
            print(f"[WARN] Could not save folder cover.jpg: {e}")

    print(f"[INFO] Downloading tracks concurrently to: {playlist_folder}")
    downloaded = 0
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = {
            executor.submit(
                download_single_track,
                t,
                playlist_folder,
                info["title"],
                i + 1,
                total_tracks,
                info["cover_url"],
                cached_cover_bytes,
                music_folder
            ): t
            for i, t in enumerate(info["tracks"])
        }
        for fut in as_completed(futures):
            res = fut.result()
            if res:
                downloaded += 1
            print(f"  Progress: {downloaded}/{total_tracks} downloaded & tagged", end="\r")

    print(f"\n[OK] Successfully downloaded & tagged {downloaded}/{total_tracks} tracks into '{info['title']}'.")

    if sync_server:
        titles = [t["title"] for t in info["tracks"]]
        sync_navidrome_playlist(info["title"], titles, server_url=server_url)


def download_individual_track(
    title: str,
    artist: str,
    album: str = "Singles",
    duration_ms: int = 0,
    cover_url: str | None = None,
    music_folder: str = "./my-music",
    server_url: str = "http://localhost:6767",
    sync_server: bool = True
) -> dict:
    """Download single track via yt-dlp, embed metadata & high-res artwork, and trigger Navidrome scan."""
    clean_artist = sanitize_name(artist) if artist else "Unknown Artist"
    clean_album = sanitize_name(album) if album else "Singles"
    clean_title = sanitize_name(title) if title else "Unknown Title"

    artist_dir = os.path.join(music_folder, clean_artist, clean_album)
    os.makedirs(artist_dir, exist_ok=True)

    print(f"[INFO] Downloading single track '{title}' by '{artist}' into: {artist_dir}")
    track_dict = {
        "title": title,
        "artist": artist,
        "duration_ms": duration_ms,
        "cover_url": cover_url
    }

    cached_cover_bytes = None
    if cover_url:
        try:
            req = urllib.request.Request(cover_url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=8) as r:
                cached_cover_bytes = r.read()
        except Exception:
            pass

    file_path = download_single_track(
        track=track_dict,
        output_dir=artist_dir,
        playlist_title=clean_album,
        track_index=1,
        total_tracks=1,
        fallback_cover_url=cover_url,
        cached_cover_bytes=cached_cover_bytes,
        music_folder=music_folder
    )

    if file_path and os.path.exists(file_path):
        print(f"[OK] Downloaded & tagged track: {file_path}")
        if sync_server:
            try:
                # Trigger quick Navidrome scan
                clean_url = server_url.rstrip("/")
                auth_params = "u=admin&p=admin&v=1.16.1&c=localspotify&f=json"
                req = urllib.request.Request(f"{clean_url}/rest/startScan.view?{auth_params}")
                urllib.request.urlopen(req, timeout=5)
                print(f"[OK] Triggered Navidrome library scan on {clean_url}")
            except Exception as e:
                print(f"[WARN] Navidrome scan trigger skipped: {e}")
        return {
            "success": True,
            "filePath": file_path,
            "title": title,
            "artist": artist,
            "album": clean_album
        }
    else:
        print(f"[ERROR] Failed to download audio for '{title}' by '{artist}'")
        return {
            "success": False,
            "filePath": None,
            "title": title,
            "artist": artist
        }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Import Spotify Playlist or Track into LocalSpotify vault")
    parser.add_argument("url", nargs="?", default=None, help="Spotify playlist URL or ID")
    parser.add_argument("--track-title", help="Download a single track by title")
    parser.add_argument("--track-artist", help="Track artist")
    parser.add_argument("--track-album", default="Singles", help="Track album name")
    parser.add_argument("--track-cover", help="Track cover art URL")
    parser.add_argument("--track-duration-ms", type=int, default=0, help="Track duration in milliseconds")
    parser.add_argument("--music-dir", default="./my-music", help="Destination music folder")
    parser.add_argument("--workers", type=int, default=4, help="Concurrent download workers")
    parser.add_argument("--server", default="http://localhost:6767", help="Navidrome server URL")
    parser.add_argument("--no-sync", action="store_true", help="Skip Navidrome library scan and playlist update")
    args = parser.parse_args()

    if args.track_title and args.track_artist:
        download_individual_track(
            title=args.track_title,
            artist=args.track_artist,
            album=args.track_album,
            duration_ms=args.track_duration_ms,
            cover_url=args.track_cover,
            music_folder=args.music_dir,
            server_url=args.server,
            sync_server=not args.no_sync
        )
    elif args.url:
        import_playlist(
            args.url,
            music_folder=args.music_dir,
            max_workers=args.workers,
            server_url=args.server,
            sync_server=not args.no_sync
        )
    else:
        parser.print_help()

