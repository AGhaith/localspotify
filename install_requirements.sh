#!/usr/bin/env bash
set -e

echo "======================================================"
echo "📦 Installing LocalSpotify Requirements"
echo "======================================================"

# Helper function to run commands with sudo if needed
run_root() {
    if [ "$EUID" -eq 0 ]; then
        "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    else
        echo "❌ Error: Root/sudo privileges are required to install system packages."
        exit 1
    fi
}

# 1. Check Python 3
if ! command -v python3 >/dev/null 2>&1; then
    echo "⚙️ Python 3 is not installed. Installing python3..."
    if command -v apt-get >/dev/null 2>&1; then
        run_root apt-get update
        run_root apt-get install -y python3
    elif command -v dnf >/dev/null 2>&1; then
        run_root dnf install -y python3
    elif command -v pacman >/dev/null 2>&1; then
        run_root pacman -Sy --noconfirm python
    else
        echo "❌ Unsupported package manager. Please install Python 3 manually."
        exit 1
    fi
else
    echo "✔ Python 3 found: $(python3 --version)"
fi

# 2. Check and Install pip
if ! command -v pip3 >/dev/null 2>&1 && ! command -v pip >/dev/null 2>&1 && ! python3 -m pip --version >/dev/null 2>&1; then
    echo "⚙️ pip is not installed. Installing python3-pip..."
    if command -v apt-get >/dev/null 2>&1; then
        run_root apt-get update
        run_root apt-get install -y python3-pip python3-setuptools
    elif command -v dnf >/dev/null 2>&1; then
        run_root dnf install -y python3-pip
    elif command -v pacman >/dev/null 2>&1; then
        run_root pacman -Sy --noconfirm python-pip
    else
        echo "Attempting ensurepip..."
        python3 -m ensurepip --upgrade || python3 -m ensurepip --default-pip
    fi
else
    echo "✔ pip found: $(python3 -m pip --version 2>/dev/null || pip3 --version 2>/dev/null || pip --version)"
fi

# 3. Check and Install ffmpeg (required for yt-dlp audio extraction/remuxing)
if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "⚙️ ffmpeg is not installed. Installing ffmpeg..."
    if command -v apt-get >/dev/null 2>&1; then
        run_root apt-get update
        run_root apt-get install -y ffmpeg
    elif command -v dnf >/dev/null 2>&1; then
        run_root dnf install -y ffmpeg
    elif command -v pacman >/dev/null 2>&1; then
        run_root pacman -Sy --noconfirm ffmpeg
    fi
else
    echo "✔ ffmpeg found"
fi

# Determine pip command
PIP_CMD="pip3"
if ! command -v pip3 >/dev/null 2>&1; then
    PIP_CMD="python3 -m pip"
fi

# 4. Install Python dependencies with --break-system-packages
echo ""
echo "🚀 Installing Python packages (yt-dlp, Pillow, mutagen) with --break-system-packages..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/requirements.txt" ]; then
    $PIP_CMD install --break-system-packages -r "$SCRIPT_DIR/requirements.txt"
else
    $PIP_CMD install --break-system-packages yt-dlp Pillow mutagen
fi

echo ""
echo "======================================================"
echo "🎉 All requirements installed successfully!"
echo "You can now run: python3 my-music/download_liked_songs.py"
echo "======================================================"
