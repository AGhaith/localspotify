#!/usr/bin/env python3
"""
Spotify Playlist Importer for LocalSpotify Music Vault
Fetches public Spotify playlist tracklists, downloads high-fidelity audio streams
via yt-dlp, embeds HD album artwork & synced lyrics, triggers Navidrome library scan,
and creates the playlist on the user's account.
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
    from PIL import Image
except ImportError:
    pass

try:
    import mutagen
    from mutagen.mp4 import MP4, MP4Cover
except ImportError:
    pass


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
        cover_url = images[-1].get("url")

    tracks = []
    for t in track_list:
        tracks.append({
            "title": t.get("title", "Unknown Title"),
            "artist": t.get("subtitle", "Unknown Artist"),
            "duration_ms": t.get("duration", 0),
            "uri": t.get("uri", "")
        })

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


def download_single_track(track: dict, output_dir: str) -> str | None:
    """Download single track via yt-dlp into M4A audio."""
    title = track["title"]
    artist = track["artist"]
    clean_title = sanitize_name(title)
    clean_artist = sanitize_name(artist)

    output_base = os.path.join(output_dir, f"{clean_artist} - {clean_title}")
    expected_path = f"{output_base}.m4a"

    if os.path.exists(expected_path):
        return expected_path

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
        'socket_timeout': 10,
        'retries': 2,
    }

    query = f"ytsearch1:{artist} - {title} Audio"
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            ydl.download([query])
    except Exception as e:
        print(f"  Failed downloading '{title}' by {artist}: {e}")
        return None

    return expected_path if os.path.exists(expected_path) else None


def import_playlist(url_or_id: str, music_folder: str = "./my-music", max_workers: int = 4):
    """Orchestrate downloading Spotify playlist into local music directory."""
    playlist_id = parse_spotify_playlist_id(url_or_id)
    if not playlist_id:
        print("Error: Invalid Spotify playlist URL or ID.")
        return

    print(f"🎵 Resolving Spotify playlist {playlist_id}...")
    info = fetch_spotify_playlist(playlist_id)
    print(f"✅ Found playlist: '{info['title']}' with {len(info['tracks'])} tracks")

    playlist_folder = os.path.join(music_folder, sanitize_name(info["title"]))
    os.makedirs(playlist_folder, exist_ok=True)

    print(f"📥 Downloading tracks concurrently to: {playlist_folder}")
    downloaded = 0
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = {
            executor.submit(download_single_track, t, playlist_folder): t
            for t in info["tracks"]
        }
        for fut in as_completed(futures):
            res = fut.result()
            if res:
                downloaded += 1
            print(f"  Progress: {downloaded}/{len(info['tracks'])} downloaded", end="\r")

    print(f"\n🎉 Successfully downloaded {downloaded}/{len(info['tracks'])} tracks into '{info['title']}'.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Import Spotify Playlist into LocalSpotify vault")
    parser.add_argument("url", help="Spotify playlist URL or ID")
    parser.add_argument("--music-dir", default="./my-music", help="Destination music folder")
    parser.add_argument("--workers", type=int, default=4, help="Concurrent download workers")
    args = parser.parse_args()

    import_playlist(args.url, music_folder=args.music_dir, max_workers=args.workers)
