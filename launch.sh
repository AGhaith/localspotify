#!/usr/bin/env bash
# ==============================================================================
# LocalSpotify - Server Updater & Launcher
# ==============================================================================
# Usage:
#   ./launch.sh            Pull latest git changes, update dependencies, rebuild & start stack
#   ./launch.sh --no-pull  Skip git pull, just rebuild and restart services
#   ./launch.sh --no-build Restart services without rebuilding docker images
#   ./launch.sh --apk      Also run Android APK compilation
#   ./launch.sh --logs     Tail live logs from all containers
#   ./launch.sh --status   Show status of containers and exit
# ==============================================================================

set -euo pipefail

# Directory where script resides (repo root)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT"

# Flags
DO_PULL=true
DO_BUILD=true
BUILD_APK=false
TAIL_LOGS=false
STATUS_ONLY=false

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-pull|-n)
      DO_PULL=false
      shift
      ;;
    --no-build)
      DO_BUILD=false
      shift
      ;;
    --apk)
      BUILD_APK=true
      shift
      ;;
    --logs|-l)
      TAIL_LOGS=true
      shift
      ;;
    --status|-s)
      STATUS_ONLY=true
      shift
      ;;
    --help|-h)
      echo "LocalSpotify Launcher & Updater"
      echo ""
      echo "Options:"
      echo "  ./launch.sh            Pull git updates, update dependencies, rebuild & start stack"
      echo "  ./launch.sh --no-pull  Skip git pull (use if already pulled manually)"
      echo "  ./launch.sh --no-build Restart containers without rebuilding images"
      echo "  ./launch.sh --apk      Also build Android APK after updating services"
      echo "  ./launch.sh --logs     Follow live container logs"
      echo "  ./launch.sh --status   Display running services status"
      echo "  ./launch.sh --help     Show this help screen"
      exit 0
      ;;
    *)
      echo "[ERROR] Unknown option: $1"
      echo "Run './launch.sh --help' for usage."
      exit 1
      ;;
  esac
done

# Color helpers (disabled if no tty)
if [ -t 1 ]; then
  BOLD="\033[1m"
  GREEN="\033[0;32m"
  YELLOW="\033[1;33m"
  RED="\033[0;31m"
  BLUE="\033[0;34m"
  CYAN="\033[0;36m"
  RESET="\033[0m"
else
  BOLD=""
  GREEN=""
  YELLOW=""
  RED=""
  BLUE=""
  CYAN=""
  RESET=""
fi

log_info() {
  echo -e "${BLUE}[INFO]${RESET} $1"
}

log_success() {
  echo -e "${GREEN}[OK]${RESET} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${RESET} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${RESET} $1"
}

log_header() {
  echo ""
  echo -e "${BOLD}${CYAN}=== $1 ===${RESET}"
}

echo -e "${BOLD}"
echo "========================================================"
echo "          LocalSpotify Server Launcher & Updater        "
echo "========================================================"
echo -e "${RESET}"

# 1. Detect Docker & Docker Compose
if ! command -v docker >/dev/null 2>&1; then
  log_error "Docker is not installed or not in PATH."
  echo "Please install Docker first: https://docs.docker.com/engine/install/"
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  log_error "Docker daemon is not running. Please start Docker."
  exit 1
fi

if docker compose version >/dev/null 2>&1; then
  DOCKER_COMPOSE="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  DOCKER_COMPOSE="docker-compose"
else
  log_error "Neither 'docker compose' nor 'docker-compose' was found."
  echo "Please install Docker Compose plugin or binary."
  exit 1
fi

# If status only requested
if [ "$STATUS_ONLY" = true ]; then
  log_header "Service Status"
  $DOCKER_COMPOSE ps
  exit 0
fi

# If logs requested
if [ "$TAIL_LOGS" = true ]; then
  log_info "Tailing live logs (Ctrl+C to exit)..."
  $DOCKER_COMPOSE logs -f
  exit 0
fi

# 2. Pull Git Updates
if [ "$DO_PULL" = true ]; then
  log_header "Step 1: Pulling Git Updates"
  if [ -d ".git" ]; then
    CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")"
    log_info "Fetching latest updates from branch: ${CURRENT_BRANCH}..."

    # Check for uncommitted working tree changes
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
      log_warn "Uncommitted local changes detected. Stashing changes..."
      git stash push -m "Auto-stashed by launch.sh on $(date)"
      STASHED=true
    else
      STASHED=false
    fi

    # Pull latest changes
    if git pull origin "$CURRENT_BRANCH"; then
      log_success "Git repository updated successfully."
      LATEST_COMMIT="$(git log -1 --format="%h - %s (%cr) <%an>")"
      log_info "Latest commit: ${LATEST_COMMIT}"
    else
      log_error "Git pull failed. Continuing with existing local files..."
    fi

    # Restore stashed changes if any
    if [ "${STASHED:-false}" = true ]; then
      log_info "Restoring stashed local changes..."
      git stash pop || log_warn "Could not cleanly apply stash; run 'git stash list' to inspect."
    fi
  else
    log_warn "Not a git repository root. Skipping git pull."
  fi
else
  log_info "Skipping git pull (--no-pull specified)."
fi

# 3. Ensure Local Directory Structure & Permissions
log_header "Step 2: Checking Local Directories"
mkdir -p "$REPO_ROOT/navidrome-data"
mkdir -p "$REPO_ROOT/redis-data"
mkdir -p "$REPO_ROOT/my-music"

# Ensure script permissions
chmod +x "$REPO_ROOT/launch.sh" 2>/dev/null || true
if [ -f "$REPO_ROOT/install_requirements.sh" ]; then
  chmod +x "$REPO_ROOT/install_requirements.sh" 2>/dev/null || true
fi
if [ -f "$REPO_ROOT/setup_and_build_apk.sh" ]; then
  chmod +x "$REPO_ROOT/setup_and_build_apk.sh" 2>/dev/null || true
fi
log_success "Directory structure and permissions verified."

# 4. Update Python & Downloader Requirements
log_header "Step 3: Updating Downloader Requirements"
if command -v python3 >/dev/null 2>&1; then
  PIP_CMD=""
  if python3 -m pip --version >/dev/null 2>&1; then
    PIP_CMD="python3 -m pip"
  elif command -v pip3 >/dev/null 2>&1; then
    PIP_CMD="pip3"
  fi

  if [ -n "$PIP_CMD" ]; then
    log_info "Updating Python dependencies (yt-dlp, mutagen, Pillow, syncedlyrics)..."
    # Try with --break-system-packages (for Debian 12+, Ubuntu 23.04+, Arch), fallback without if older
    if [ -f "$REPO_ROOT/requirements.txt" ]; then
      $PIP_CMD install --upgrade --break-system-packages -r "$REPO_ROOT/requirements.txt" 2>/dev/null || \
      $PIP_CMD install --upgrade -r "$REPO_ROOT/requirements.txt" 2>/dev/null || \
      log_warn "Could not update Python dependencies automatically. Run install_requirements.sh manually if needed."
    fi
    log_success "Python environment checked."
  else
    log_warn "pip3 not found. Skipping python package updates."
  fi
else
  log_warn "python3 not found. Skipping python package updates."
fi

# 5. Build and Deploy Docker Services
log_header "Step 4: Building & Deploying Services"
if [ "$DO_BUILD" = true ]; then
  log_info "Building updated container images (Nuxt 4 player, Navidrome, Redis)..."
  $DOCKER_COMPOSE build --pull
fi

# Ensure any stuck or failed redis container from prior failed port bind is cleanly recreated
docker rm -f localspotify-redis >/dev/null 2>&1 || true

log_info "Launching LocalSpotify container stack..."
$DOCKER_COMPOSE up -d --remove-orphans

# Clean up dangling images to save disk space
log_info "Pruning unused/dangling build images..."
docker image prune -f >/dev/null 2>&1 || true

# 6. Verify Service Health
log_header "Step 5: Verifying Service Health"
log_info "Waiting for services to become healthy..."
sleep 4

$DOCKER_COMPOSE ps

# 7. Optional APK Build
if [ "$BUILD_APK" = true ]; then
  log_header "Step 6: Building Android APK"
  if [ -f "$REPO_ROOT/setup_and_build_apk.sh" ]; then
    log_info "Executing setup_and_build_apk.sh..."
    bash "$REPO_ROOT/setup_and_build_apk.sh"
  else
    log_error "setup_and_build_apk.sh not found."
  fi
fi

# 8. Detect Host IP & Show Dashboard
log_header "Step 6: Status & Access URLs"

# Get local IP
HOST_IP="localhost"
if command -v hostname >/dev/null 2>&1; then
  IP_CANDIDATE="$(hostname -I 2>/dev/null | awk '{print $1}')"
  if [ -n "$IP_CANDIDATE" ]; then
    HOST_IP="$IP_CANDIDATE"
  fi
fi

echo ""
echo -e "${GREEN}${BOLD}LocalSpotify stack is up and running!${RESET}"
echo ""
echo -e "  ${BOLD}Navidrome Server:${RESET}      http://localhost:6767  (LAN: http://${HOST_IP}:6767)"
echo -e "  ${BOLD}Subsonic Web Player:${RESET}    http://localhost:6969  (LAN: http://${HOST_IP}:6969)"
echo -e "  ${BOLD}Redis Cache:${RESET}            Internal Docker Network (redis:6379)"
echo ""
echo "Useful Commands:"
echo "  View live logs:         ./launch.sh --logs"
echo "  Check container status: ./launch.sh --status"
echo "  Import Spotify track:   python3 my-music/import_spotify_playlist.py <URL>"
echo "  Download liked songs:   python3 my-music/download_liked_songs.py"
echo "  Stop stack:             $DOCKER_COMPOSE down"
echo ""
echo -e "${CYAN}Done! Your local server is updated and running the latest code.${RESET}"
