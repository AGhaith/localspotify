# LocalSpotify - Comprehensive Project Handoff

## 1. Project Overview & System Purpose

**LocalSpotify** is a private, self-hosted music streaming ecosystem designed to provide an authentic, modern Spotify user experience on mobile and web while maintaining total ownership of music media and playlists.

The system combines:
1. **Flutter Native Mobile Client** (`mobile_app/`): High-performance Android application (targeting 120 FPS) with background audio playback, lock screen media controls, caching, and dynamic palette theming matching Spotify's exact design language.
2. **Navidrome Audio Server** (`navidrome` container): High-efficiency Subsonic-compatible music streaming server managing the music catalog, transcode pipelines, and metadata indexing.
3. **Nuxt 4 Web Client & Companion API** (`subsonic-player` container): Web player and Node/Nitro backend providing REST endpoints for playlist importing, server-side background orchestration, and caching.
4. **Redis Cache** (`localspotify-redis` container): Session storage and response caching.
5. **Automated Spotify Importer Pipeline** (`import_spotify_playlist.py`): Scrapes Spotify playlist metadata, downloads audio via `yt-dlp`, tags files with metadata and artwork, places files into the library vault, triggers server rescans, and builds playlists automatically.

---

## 2. Hard Constraints & Design Principles

> [!IMPORTANT]
> The following rules are strictly enforced across the entire codebase. Future modifications must adhere to them without exception.

1. **Zero Emojis Everywhere**:
   - No emojis in any mobile screens, UI widgets, error dialogs, notifications, backend logs, or shell scripts.
   - Use clean, standard Material Symbols / Icons (e.g., `Icons.playlist_add_check_rounded`, `Icons.sync_rounded`).

2. **Zero Mentions of Backend Technology Names in User-Facing UI**:
   - The terms **"Subsonic"** and **"Navidrome"** must never appear in the mobile UI or user-facing web text.
   - All references to the backend must be presented as **"Library Vault"**, **"Local Vault"**, or simply **"Library"**.

3. **Hardcoded Server Addressing (Zero User Prompts)**:
   - Users are never prompted to enter a server IP, port, or base URL.
   - The server address is hardcoded in [app_config.dart](file:///d:/Side%20Projects/localspotify/mobile_app/lib/core/config/app_config.dart) to the Tailscale node:
     - Streaming Server (Subsonic API): `http://100.92.248.49:6767`
     - Companion Node/Nitro API: `http://100.92.248.49:6969`

4. **Authentic Spotify Dark Palette**:
   - Main Background: `#121212` (Spotify charcoal grey, never pure `#000000`).
   - Cards / Containers: `#181818`.
   - Elevated Surfaces / Dialogs: `#242424`.
   - Card Hover / Highlights: `#282828`.
   - Primary Accent: `#1DB954` (Spotify green).
   - Text Hierarchy: Primary `#FFFFFF`, Secondary `#B3B3B3`, Muted `#6A6A6A`.

5. **Dynamic Artwork Palette Matching**:
   - Drawers, bottom sheets, and detail headers must use `PaletteGenerator` (`package:palette_generator`) to dynamically extract dominant and vibrant colors from cover art, tinting the `#121212` background using smooth radial/linear gradients.

---

## 3. Infrastructure & Network Topology

```
+-------------------------------------------------------------------------------+
|                             Local Network / Tailscale                         |
|                                                                               |
|   +-----------------------+              +--------------------------------+   |
|   |   Android Mobile App  |              |          Web Browser           |   |
|   |    (Flutter Engine)   |              |         (Nuxt 4 Client)        |   |
|   +-----------+-----------+              +---------------+----------------+   |
|               |                                          |                    |
|       Port 6767 (Subsonic)                       Port 6969 (HTTP)             |
|       Port 6969 (Companion)                             |                    |
|               |                                          |                    |
|               v                                          v                    |
|   +-----------------------------------------------------------------------+   |
|   |                         Docker Host (100.92.248.49)                   |   |
|   |                                                                       |   |
|   |  +------------------------+      +---------------------------------+  |   |
|   |  |   subsonic-player      |      |           navidrome             |  |   |
|   |  |  (Nuxt 4 / Nitro API)  |      |   (Subsonic API Server :6767)   |  |   |
|   |  |       Port 6969        |      +----------------+----------------+  |   |
|   |  +-----------+------------+                       |                   |   |
|   |              |                                    |                   |   |
|   |              | Spawns yt-dlp & creates tracks     | Reads & Streams   |   |
|   |              v                                    v                   |   |
|   |    +-------------------+                +--------------------+        |   |
|   |    |    Redis Cache    |                |    /music Vault    |        |   |
|   |    |   (Internal :6379)|                |    (Host: ./my-music)       |   |
|   |    +-------------------+                +--------------------+        |   |
|   +-----------------------------------------------------------------------+   |
+-------------------------------------------------------------------------------+
```

### Container Specifications (`docker-compose.yml`)

* **`navidrome`**:
  * Image: `deluan/navidrome:latest`
  * Host Port: `6767` -> Container Port: `4533`
  * Volumes: `./navidrome-data:/data`, `./my-music:/music:ro`
  * Environment: Scrobbling enabled, playlists enabled, CORS enabled for all origins.
* **`redis`**:
  * Image: `redis:7-alpine`
  * Network: Internal container network (`expose: 6379`, no host port collision).
  * Volume: `./redis-data:/data`
* **`subsonic-player`**:
  * Dockerfile: `./subsonic-player/Dockerfile`
  * Host Port: `6969` -> Container Port: `3000`
  * Volumes: `./my-music:/music` (read-write for downloading tracks)
  * Environment: `NUXT_PUBLIC_SERVER_URL=http://100.92.248.49:6767`, `REDIS_HOST=redis`

---

## 4. End-to-End Spotify Playlist Import Pipeline

The playlist import workflow bridges client UI, embed scraping, companion backend dispatch, server-side download execution, and real-time reconciliation:

```
[User pastes Spotify URL in Flutter Import Drawer]
                       │
                       ▼
[Flutter: SpotifyImporterService.fetchPlaylistMetadata]
  • Scrapes https://open.spotify.com/embed/playlist/<id>
  • Extracts title, description, cover image URL, and all track items
                       │
                       ▼
[Flutter: ImportSpotifyPlaylistSheet]
  • Runs PaletteGenerator on cover image URL
  • Renders glassmorphic drawer matching cover colors
  • User presses "Import to Library"
                       │
                       ▼
[Flutter: SpotifyImporterService.dispatchServerDownload]
  • Sends POST to http://100.92.248.49:6969/api/import-playlist
  • Saves cover URL & imported tracklist into local SharedPreferences cache
                       │
                       ▼
[Nitro API: server/api/import-playlist.post.ts]
  • Validates payload and creates playlist on Navidrome via Subsonic API
  • Spawns python3 import_spotify_playlist.py in detached background process
                       │
                       ▼
[Python Script: import_spotify_playlist.py]
  • Downloads tracks with yt-dlp: ytsearch1:<artist> - <title> audio
  • Embeds metadata tags (ID3 / FLAC) and covers
  • Saves files into /music/<Artist>/<Album>/<Track>.mp3
  • Calls Navidrome /rest/startScan to index new files
  • Calls Navidrome /rest/updatePlaylist to link song IDs
                       │
                       ▼
[Flutter: PlaylistDetailScreen]
  • Auto-Sync Poller triggers every 4 seconds
  • Queries Navidrome search for newly indexed songs via MusicProvider.syncPlaylistWithVault()
  • Automatically links songs to playlist with updatePlaylist.view
  • Updates linear progress bar ($syncPercent% • X of Y tracks ready)
  • When 100% indexed, unlocks "Play All" and "Shuffle" buttons
```

---

## 5. Mobile App Architecture (`mobile_app/`)

### Key Directories & Files

```
mobile_app/lib/
├── core/
│   ├── config/
│   │   └── app_config.dart                  # Server IP (100.92.248.49:6767), App meta
│   ├── theme/
│   │   ├── app_colors.dart                  # #121212, #181818, #242424, #1DB954
│   │   ├── app_theme.dart                   # Dark theme data & typography
│   │   └── app_typography.dart              # Standardized Spotify type scale
│   └── utils/
│       └── helpers.dart                     # Time and duration formatters
├── data/
│   ├── models/
│   │   ├── album.dart                       # Album model with discography metadata
│   │   ├── artist.dart                      # Artist model
│   │   ├── playlist.dart                    # Playlist model (with custom cover support)
│   │   ├── search_result.dart               # Unified search response
│   │   └── track.dart                       # Track model with local/stream URLs
│   ├── repositories/
│   │   └── music_repository.dart            # Cache-first data layer, cover resolution, vault sync
│   └── services/
│       ├── audio_player_service.dart        # JustAudio + AudioService background player
│       ├── offline_storage_service.dart     # SharedPreferences & Hive caches
│       ├── spotify_importer_service.dart    # Spotify scraper & companion API dispatcher
│       └── subsonic_api_service.dart        # Subsonic REST client (salt, md5 auth)
├── state/
│   ├── auth_provider.dart                   # Auth lifecycle & auto-login
│   ├── music_provider.dart                  # Catalogs, playlists, auto-sync reconciliation
│   └── player_provider.dart                 # Queue management, playback state, seek, repeat
└── ui/
    ├── features/
    │   ├── album/album_detail_screen.dart   # Album tracklist & metadata
    │   ├── artist/artist_detail_screen.dart # Artist overview & top songs
    │   ├── auth/login_screen.dart           # Clean login with Google OAuth button
    │   ├── home/home_screen.dart            # Recently added, quick plays, new albums
    │   ├── library/
    │   │   ├── import_spotify_playlist_sheet.dart # Palette-matched import drawer
    │   │   ├── library_screen.dart          # Playlists & saved albums list
    │   │   └── playlist_detail_screen.dart  # Auto-syncing playlist screen with progress bar
    │   ├── main_navigation/
    │   │   └── bottom_nav_shell.dart        # Bottom navigation (Home, Search, Library)
    │   ├── player/
    │   │   ├── mini_player_bar.dart         # Floating mini player above nav bar
    │   │   └── now_playing_sheet.dart       # Full-screen playback sheet with seek & queue
    │   └── search/search_screen.dart        # Instant search for artists, albums, songs
    └── shared_widgets/
        ├── cached_cover_art.dart            # Smart image loader with placeholder fallbacks
        └── track_tile.dart                  # Standard track row with playback trigger
```

---

## 6. Recent Fixes & Improvements

1. **Album Palette Matching Import Drawer**:
   - Replaced flat dark drawer with dynamic artwork palette extraction using `PaletteGenerator`.
   - Added subtle gradient backdrop, glassmorphism preview cards, and styled action button **"Import to Library"**.
2. **Real Sync Progress Bar & Friendly Status**:
   - Replaced all technical messages ("Downloading tracks on server") with **"Syncing..."** and **"Syncing Playlist"**.
   - Added a live `LinearProgressIndicator` showing real percentage completion (`$syncPercent%`) and track readiness (`X of Y ready in library`).
3. **Infinite Loading / Stuck Playlist Resolution**:
   - Implemented `syncPlaylistTracksWithVault()` in [music_repository.dart](file:///d:/Side%20Projects/localspotify/mobile_app/lib/data/repositories/music_repository.dart) and [music_provider.dart](file:///d:/Side%20Projects/localspotify/mobile_app/lib/state/music_provider.dart).
   - Added automated periodic 4-second poller in [playlist_detail_screen.dart](file:///d:/Side%20Projects/localspotify/mobile_app/lib/ui/features/library/playlist_detail_screen.dart) to reconcile newly indexed tracks and transition the playlist to ready mode.
4. **Spotify Charcoal Grey Theme**:
   - Updated global color system from `#000000` to authentic `#121212`.
5. **Now Playing Sheet Layout Fix**:
   - Wrapped the album title header in `Expanded` to prevent 34px horizontal/bottom overflow on small or high-DPI screens.
6. **Docker Redis Conflict Resolution**:
   - Updated `docker-compose.yml` to use `expose: 6379` instead of binding to the host port, eliminating port conflict issues during rebuilds.

---

## 7. Developer & Operations Guide

### A. Updating and Managing the Server Stack (`launch.sh`)

The root [launch.sh](file:///d:/Side%20Projects/localspotify/launch.sh) script handles pulling Git updates, building containers, and performing service health checks on the remote server:

```bash
# Standard update: Pull latest git changes, rebuild containers, and start services
./launch.sh

# Restart services without git pull
./launch.sh --no-pull

# Restart services without rebuilding Docker images
./launch.sh --no-build

# Build the Android APK alongside the server stack
./launch.sh --apk

# Check container health and status
./launch.sh --status

# Stream live container logs
./launch.sh --logs
```

### B. Building & Deploying the Android App

```bash
cd mobile_app

# Run static analysis
flutter analyze

# Run unit test suite
flutter test

# Build release APK
flutter build apk --release
# Output: mobile_app/build/app/outputs/flutter-apk/app-release.apk

# Install directly to connected ADB device
adb install -r build/app/outputs/flutter-apk/app-release.apk

# Launch app directly on device
adb shell monkey -p com.localspotify.app -c android.intent.category.LAUNCHER 1
```

---

## 8. Credentials & Environment Reference

| Service | Environment / Key | Purpose |
| :--- | :--- | :--- |
| **Navidrome** | Host: `http://100.92.248.49:6767` | Subsonic streaming backend |
| **Companion API** | Host: `http://100.92.248.49:6969` | Spotify playlist importer & Nuxt Nitro endpoints |
| **Default User** | Username: `admin` | Auto-login fallback credentials |
| **Last.fm API** | Key: `8cd4f9a0768e6bb7cf406566a7803a01` | Scrobbling & artist metadata in Navidrome |
| **Music Vault** | Host path: `./my-music` -> Container: `/music` | Shared media library volume |

---

## 9. Future Roadmap & Opportunities

1. **Offline Track Download**:
   - Implement audio file caching in `offline_storage_service.dart` so tracks can be played entirely offline without network access.
2. **Native Google OAuth Integration**:
   - Complete the Subsonic user mapping backend for seamless Google OAuth token authentication.
3. **Synchronized Lyrics**:
   - Utilize Navidrome's synchronized lyrics endpoint (`getLyricsBySongId`) to provide a Spotify-like karaoke lyrics view on the now-playing sheet.
4. **Desktop Client Builds**:
   - Compile the Flutter application for Windows/Linux desktop using Flutter's desktop runner.
