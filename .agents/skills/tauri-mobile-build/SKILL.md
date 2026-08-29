---
name: tauri-mobile-build
description: Instructions and best practices for building Android APKs and iOS apps using Tauri 2.0 locally and via GitHub Actions.
---

# Tauri 2.0 Mobile Build Guide

This skill provides step-by-step instructions for building Android APKs for LocalSpotify (and Tauri 2.0 apps).

## 1. GitHub Actions Cloud Builds (Recommended)

The GitHub Actions workflow is located at `.github/workflows/build-apk.yml`.

### How to Trigger:
1. **Automatic**: Push any changes to `main` under `app/**` or `.github/workflows/build-apk.yml`.
2. **Manual**: Go to **Actions** tab on GitHub -> Select **Build LocalSpotify Android APK** -> Click **Run workflow** (select `debug` or `release`, and target architecture `aarch64`, `armv7`, `x86_64`, or `all`).
3. **Download via CLI**:
   ```bash
   gh run list --limit 1
   gh run download <RUN_ID> --dir ./downloaded_apk
   ```

### Key Requirements in CI:
- Java 17 (`actions/setup-java@v4` with `temurin` or `zulu`)
- Android SDK (`android-actions/setup-android@v3`) with NDK `26.1.10909125`, `platforms;android-34`, `build-tools;34.0.0`
- Rust target `aarch64-linux-android` (and other architectures if building universal)
- Use `npx tauri android init --ci` to prevent interactive prompts in CI
- Export `NDK_HOME` dynamically to the detected NDK path in `$ANDROID_HOME/ndk/`

---

## 2. Local Machine Android Build

To build the APK on your local Linux machine:

### Prerequisites:
- **JDK 17**: `~/.jdk17` or system OpenJDK 17 (`java`, `javac`)
- **Android SDK & NDK**: `~/Android/Sdk` with `cmdline-tools`, `platforms;android-34`, `build-tools;34.0.0`, `ndk;26.1.10909125`
- **Rust Android Targets**:
  ```bash
  rustup target add aarch64-linux-android armv7-linux-androideabi i686-linux-android x86_64-linux-android
  ```

### One-Command Local Build:
Run the repository setup and build script:
```bash
./setup_and_build_apk.sh
```

### Manual Steps:
```bash
export JAVA_HOME="/home/ahmed/.jdk17"
export ANDROID_HOME="/home/ahmed/Android/Sdk"
export NDK_HOME="$ANDROID_HOME/ndk/26.1.10909125"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

cd app
npx tauri android init --ci
npx tauri android build --apk --debug --target aarch64
```

Generated APKs are placed in:
`app/src-tauri/gen/android/app/build/outputs/apk/universal/debug/app-universal-debug.apk` (or `arm64-v8a/debug/app-arm64-v8a-debug.apk`).
