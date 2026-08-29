/**
 * LocalSpotify Audio Player Engine
 * Supports HTML5 Audio, dynamic queue, lock screen MediaSession, and offline playback.
 */

class MusicPlayer {
  constructor() {
    this.audio = new Audio();
    this.queue = [];
    this.currentIndex = -1;
    this.isPlaying = false;
    this.isShuffle = false;
    this.repeatMode = "none"; // "none" | "all" | "one"

    this.initAudioEvents();
    this.initMediaSession();
  }

  initAudioEvents() {
    this.audio.addEventListener("play", () => {
      this.isPlaying = true;
      this.updatePlayStateUI();
    });

    this.audio.addEventListener("pause", () => {
      this.isPlaying = false;
      this.updatePlayStateUI();
    });

    this.audio.addEventListener("timeupdate", () => {
      const current = this.audio.currentTime;
      const duration = this.audio.duration || 0;
      window.dispatchEvent(new CustomEvent("player-timeupdate", { detail: { current, duration } }));
    });

    this.audio.addEventListener("ended", () => {
      if (this.repeatMode === "one") {
        this.audio.currentTime = 0;
        this.audio.play();
      } else {
        this.next();
      }
    });

    this.audio.addEventListener("error", (e) => {
      console.error("[Player] Audio playback error:", e);
    });
  }

  initMediaSession() {
    if ("mediaSession" in navigator) {
      navigator.mediaSession.setActionHandler("play", () => this.resume());
      navigator.mediaSession.setActionHandler("pause", () => this.pause());
      navigator.mediaSession.setActionHandler("previoustrack", () => this.prev());
      navigator.mediaSession.setActionHandler("nexttrack", () => this.next());
      navigator.mediaSession.setActionHandler("seekto", (details) => {
        if (details.seekTime !== undefined) {
          this.seek(details.seekTime);
        }
      });
    }
  }

  setQueue(tracks, startIndex = 0) {
    this.queue = [...tracks];
    this.currentIndex = startIndex;
    if (this.queue.length > 0 && startIndex >= 0 && startIndex < this.queue.length) {
      this.playTrack(this.queue[this.currentIndex]);
    }
  }

  async playTrack(track) {
    if (!track) return;
    const trackId = track.id;

    try {
      const src = await window.offlineManager.getAudioSrc(trackId);
      this.audio.src = src;
      await this.audio.play();

      // Update Native Media Session (Lock Screen & Notification Controls)
      const coverUrl = track.coverBlob
        ? URL.createObjectURL(track.coverBlob)
        : window.api.getCoverArtUrl(track.coverArt || track.albumId, 500);

      if ("mediaSession" in navigator) {
        navigator.mediaSession.metadata = new MediaMetadata({
          title: track.title || "Unknown Title",
          artist: track.artist || "Unknown Artist",
          album: track.album || "LocalSpotify",
          artwork: coverUrl ? [{ src: coverUrl, sizes: "512x512", type: "image/jpeg" }] : []
        });
      }

      window.dispatchEvent(new CustomEvent("player-track-changed", { detail: { track, coverUrl } }));
    } catch (e) {
      console.error("[Player] Failed to play track:", e);
    }
  }

  togglePlay() {
    if (!this.audio.src && this.queue.length > 0) {
      this.playTrack(this.queue[0]);
      return;
    }
    if (this.isPlaying) {
      this.pause();
    } else {
      this.resume();
    }
  }

  resume() {
    this.audio.play().catch(() => {});
  }

  pause() {
    this.audio.pause();
  }

  next() {
    if (this.queue.length === 0) return;

    if (this.isShuffle) {
      this.currentIndex = Math.floor(Math.random() * this.queue.length);
    } else {
      this.currentIndex++;
      if (this.currentIndex >= this.queue.length) {
        if (this.repeatMode === "all") {
          this.currentIndex = 0;
        } else {
          this.currentIndex = this.queue.length - 1;
          this.pause();
          return;
        }
      }
    }
    this.playTrack(this.queue[this.currentIndex]);
  }

  prev() {
    if (this.queue.length === 0) return;
    if (this.audio.currentTime > 3) {
      this.audio.currentTime = 0;
      return;
    }
    this.currentIndex--;
    if (this.currentIndex < 0) {
      this.currentIndex = this.queue.length - 1;
    }
    this.playTrack(this.queue[this.currentIndex]);
  }

  seek(seconds) {
    if (Number.isFinite(seconds)) {
      this.audio.currentTime = seconds;
    }
  }

  setVolume(fraction) {
    this.audio.volume = Math.max(0, Math.min(1, fraction));
  }

  toggleShuffle() {
    this.isShuffle = !this.isShuffle;
    window.dispatchEvent(new CustomEvent("player-shuffle-changed", { detail: { isShuffle: this.isShuffle } }));
    return this.isShuffle;
  }

  toggleRepeat() {
    const modes = ["none", "all", "one"];
    const nextIdx = (modes.indexOf(this.repeatMode) + 1) % modes.length;
    this.repeatMode = modes[nextIdx];
    window.dispatchEvent(new CustomEvent("player-repeat-changed", { detail: { repeatMode: this.repeatMode } }));
    return this.repeatMode;
  }

  updatePlayStateUI() {
    window.dispatchEvent(new CustomEvent("player-state-changed", { detail: { isPlaying: this.isPlaying } }));
  }

  getCurrentTrack() {
    return this.queue[this.currentIndex] || null;
  }
}

window.player = new MusicPlayer();
