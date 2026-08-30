---
name: flutter-mobile-client
description: >-
  Expert guidelines, architecture patterns, and troubleshooting workflows for the
  LocalSpotify Flutter native mobile application (120 FPS, JustAudio + AudioService,
  Subsonic / Navidrome API, offline cache, and Android APK builds). Use when building,
  modifying, or debugging the Flutter client.
---

# LocalSpotify Flutter Native Client Guide

This skill provides architecture guidelines, coding patterns, and build troubleshooting for the high-performance native Flutter music client (`mobile_app/`).

---

## 1. Core Architecture

The mobile app adheres to a strict layered Flutter architecture:

```
mobile_app/
├── lib/
│   ├── core/
│   │   ├── theme/           # AppColors, AppTypography, AppTheme
│   │   └── utils/           # Md5Hasher, DurationFormatter
│   ├── data/
│   │   ├── models/          # Track, Album, Artist, Playlist, UserSession
│   │   ├── repositories/    # AuthRepository, MusicRepository
│   │   └── services/        # SubsonicApiService, OfflineStorageService, LocalSpotifyAudioHandler
│   ├── state/               # AuthProvider, MusicProvider, AudioPlayerProvider
│   └── ui/
│       ├── core_widgets/    # CachedCoverArt, NeoCard, NeoButton, TrackRow, AlbumCard
│       └── features/        # auth, home, library, search, offline, player, main_navigation
```

---

## 2. Audio Engine Guidelines

- **Playback & Notification**: Uses `just_audio` backed by `audio_service`'s `BaseAudioHandler`.
- **Activity Inheritance**: `MainActivity.kt` MUST extend `AudioServiceActivity`.
- **Manifest Requirements**:
  - `FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_MEDIA_PLAYBACK` permissions.
  - `AudioService` service definition with `android:foregroundServiceType="mediaPlayback"`.
- **State Separation**:
  - Audio player state is managed in `AudioPlayerProvider`.
  - Enum for repeat mode is named `AppRepeatMode` to prevent ambiguous symbol collisions with Flutter's SDK.

---

## 3. Strict Type Safety & Compatibility (Flutter 3.47+ / Dart 3.x)

1. **Icons**:
   - Use built-in Flutter Material Rounded icons (`Icons.*_rounded`).
   - Do NOT use packages that subclass `IconData` (e.g. older `phosphor_flutter`), as `IconData` is a `final class` in Dart 3.
2. **Themes**:
   - `ThemeData.cardTheme` strictly requires `CardThemeData(...)`.
3. **Double Clamping**:
   - Always pass double literals to clamp functions: `.clamp(16.0, 48.0)`.

---

## 4. Subsonic / Navidrome API Integration

- **Authentication**: Subsonic REST API uses token authentication: `token = md5(password + salt)`.
- **Cover Art**: Cover art is loaded via `/rest/getCoverArt` with cached dimensions to maintain 120 FPS scrolling performance.
- **Offline Storage**: Downloaded tracks are stored locally in the application documents directory and indexed with persistent metadata.

---

## 5. Android APK Compilation & CI

- **Build Command**: `flutter build apk --release --android-skip-build-dependency-validation`
- **Gradle Version**: Configured with Gradle 8.14 in `gradle-wrapper.properties`.
- **Android Gradle Plugin**: `8.3.2` with Kotlin `1.9.24`.
- **Java**: Target Java 17 (`JavaVersion.VERSION_17`).
