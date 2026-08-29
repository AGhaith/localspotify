# 🎧 LocalSpotify - Self-Hosted Music Streaming Server

A modern self-hosted Spotify alternative powered by **Navidrome**, **Subsonic Web Player**, and an automated **high-speed Spotify playlist downloader**.

---

## 🚀 Architecture

- **[Navidrome](https://www.navidrome.org/)**: Lightweight, high-performance Subsonic-compatible music server.
  - Port: `6767`
  - Integrated with **Spotify API** (HD artist portraits & top tracks) and **Last.fm** (biographies, metadata & scrobbling).
- **[Subsonic Player](https://github.com/vd39/subsonic-player)**: Modern, Spotify-like Web UI.
  - Port: `6969`
- **Spotify Downloader (`download_liked_songs.py`)**:
  - High-speed concurrent music downloader using `yt-dlp` and `mutagen`.
  - Downloads highest-quality M4A audio.
  - Automatically embeds official Spotify 640x640 HD album artwork and full ID3/MP4 metadata tags.
  - Live progress display with transferred size in MB.

---

## 🛠️ Quick Start

### 1. Start the Music Server Stack
```bash
docker compose up -d
```

- **Navidrome Web UI**: `http://localhost:6767`
- **Subsonic Player UI**: `http://localhost:6969`

### 2. Download Your Spotify Library
Place your Spotify export CSV (`Liked_Songs.csv`) in `my-music/` and run:

```bash
cd my-music
python3 download_liked_songs.py
```

#### Downloader Options:
```bash
# Custom concurrency (e.g. 8 parallel worker threads)
python3 download_liked_songs.py -w 8

# Specify audio format (m4a, mp3, flac)
python3 download_liked_songs.py -f m4a

# Download only first 20 tracks for testing
python3 download_liked_songs.py -n 20

# Save standalone .jpg cover art files alongside audio
python3 download_liked_songs.py --save-jpg
```

---

## ⚙️ Configuration

Set your Spotify and Last.fm API keys in `docker-compose.yml`:

```yaml
environment:
  ND_ENABLEEXTERNALSERVICES: "true"
  ND_SPOTIFY_ID: "your_spotify_client_id"
  ND_SPOTIFY_SECRET: "your_spotify_client_secret"
  ND_LASTFM_ENABLED: "true"
  ND_LASTFM_APIKEY: "your_lastfm_api_key"
  ND_LASTFM_SECRET: "your_lastfm_secret"
```
