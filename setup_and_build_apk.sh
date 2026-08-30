#!/bin/bash
set -e

echo "🎵 [1/3] Building Subsonic Player Nuxt 4 Frontend (Modern UI)..."
cd "$(dirname "$0")/subsonic-player"
npm install --legacy-peer-deps
SPA_MODE=true npm run generate

echo "📦 [2/3] Syncing frontend assets to Tauri app bundle..."
cd ../app
mkdir -p src
cp -r ../subsonic-player/.output/public/* ./src/
npm install

echo "🚀 [3/3] Initializing and Building Tauri Android APK..."
npx tauri android init --ci
TARGET="${1:-aarch64}"
BUILD_TYPE="${2:-debug}"

FLAGS="--apk"
if [ "$BUILD_TYPE" = "debug" ]; then
  FLAGS="$FLAGS --debug"
fi
if [ "$TARGET" != "all" ]; then
  FLAGS="$FLAGS --target $TARGET"
fi

echo "Running: npx tauri android build $FLAGS"
npx tauri android build $FLAGS

echo "✅ Android APK successfully compiled with the new UI!"
