/**
 * Offline Manager for LocalSpotify
 * Supports Native Tauri 2.0 Rust app sandbox caching and Web IndexedDB fallback.
 */

class OfflineManager {
  constructor() {
    this.isTauri = typeof window.__TAURI__ !== "undefined";
    this.downloadedTracks = new Map(); // id -> metadata
    this.downloadingSet = new Set();
    this.isOfflineMode = localStorage.getItem("ls_offline_mode") === "true";
    this.db = null;
    this.initDB();
  }

  async initDB() {
    if (this.isTauri) {
      await this.loadTauriOfflineTracks();
    } else {
      await this.loadIndexedDBTracks();
    }
  }

  // --- Tauri Native Rust Backend Integration ---
  async loadTauriOfflineTracks() {
    try {
      const tracks = await window.__TAURI__.core.invoke("get_offline_tracks");
      if (Array.isArray(tracks)) {
        this.downloadedTracks.clear();
        tracks.forEach(t => this.downloadedTracks.set(t.id, t));
      }
    } catch (e) {
      console.warn("[OfflineManager] Failed to load Tauri offline tracks:", e);
    }
  }

  // --- Browser IndexedDB Fallback ---
  async loadIndexedDBTracks() {
    return new Promise((resolve) => {
      const request = indexedDB.open("LocalSpotifyDB", 1);
      request.onupgradeneeded = (e) => {
        const db = e.target.result;
        if (!db.objectStoreNames.contains("offline_tracks")) {
          db.createObjectStore("offline_tracks", { keyPath: "id" });
        }
      };
      request.onsuccess = (e) => {
        this.db = e.target.result;
        const tx = this.db.transaction("offline_tracks", "readonly");
        const store = tx.objectStore("offline_tracks");
        const getAllReq = store.getAll();
        getAllReq.onsuccess = () => {
          (getAllReq.result || []).forEach(t => this.downloadedTracks.set(t.id, t));
          resolve();
        };
      };
      request.onerror = () => resolve();
    });
  }

  isDownloaded(trackId) {
    return this.downloadedTracks.has(String(trackId));
  }

  isDownloading(trackId) {
    return this.downloadingSet.has(String(trackId));
  }

  async downloadTrack(track) {
    const id = String(track.id);
    if (this.isDownloaded(id) || this.isDownloading(id)) return;

    this.downloadingSet.add(id);
    window.dispatchEvent(new CustomEvent("track-download-state", { detail: { id, state: "downloading" } }));

    const streamUrl = window.api.getStreamUrl(id);
    const coverUrl = window.api.getCoverArtUrl(track.coverArt || track.albumId, 300);

    try {
      if (this.isTauri) {
        // Native Tauri Rust Download (stores in app private sandbox)
        const payload = {
          trackId: id,
          streamUrl: streamUrl,
          coverUrl: coverUrl,
          title: track.title || "",
          artist: track.artist || "",
          album: track.album || "",
          duration: track.duration || 0
        };
        const savedTrack = await window.__TAURI__.core.invoke("save_offline_track", payload);
        this.downloadedTracks.set(id, savedTrack);
      } else {
        // IndexedDB Blob Download for Web/PWA
        const [audioBlob, coverBlob] = await Promise.all([
          fetch(streamUrl).then(r => r.blob()),
          coverUrl ? fetch(coverUrl).then(r => r.blob()).catch(() => null) : null
        ]);

        const record = {
          id: id,
          title: track.title,
          artist: track.artist,
          album: track.album,
          duration: track.duration,
          audioBlob: audioBlob,
          coverBlob: coverBlob,
          savedAt: Date.now()
        };

        await new Promise((resolve, reject) => {
          const tx = this.db.transaction("offline_tracks", "readwrite");
          const store = tx.objectStore("offline_tracks");
          const req = store.put(record);
          req.onsuccess = () => resolve();
          req.onerror = reject;
        });

        this.downloadedTracks.set(id, record);
      }

      this.downloadingSet.delete(id);
      window.dispatchEvent(new CustomEvent("track-download-state", { detail: { id, state: "downloaded" } }));
      console.log(`[OfflineManager] Downloaded & saved track: ${track.title}`);
    } catch (err) {
      console.error(`[OfflineManager] Failed to download ${track.title}:`, err);
      this.downloadingSet.delete(id);
      window.dispatchEvent(new CustomEvent("track-download-state", { detail: { id, state: "error" } }));
    }
  }

  async removeTrack(trackId) {
    const id = String(trackId);
    if (!this.isDownloaded(id)) return;

    if (this.isTauri) {
      await window.__TAURI__.core.invoke("delete_offline_track", { trackId: id });
    } else if (this.db) {
      await new Promise((resolve) => {
        const tx = this.db.transaction("offline_tracks", "readwrite");
        const store = tx.objectStore("offline_tracks");
        const req = store.delete(id);
        req.onsuccess = () => resolve();
      });
    }

    this.downloadedTracks.delete(id);
    window.dispatchEvent(new CustomEvent("track-download-state", { detail: { id, state: "removed" } }));
  }

  async getAudioSrc(trackId) {
    const id = String(trackId);
    if (this.isTauri && this.isDownloaded(id)) {
      // Return custom Tauri asset protocol URI or file stream
      return await window.__TAURI__.core.invoke("get_offline_audio_url", { trackId: id });
    } else if (this.downloadedTracks.has(id)) {
      const record = this.downloadedTracks.get(id);
      if (record.audioBlob) {
        return URL.createObjectURL(record.audioBlob);
      }
    }
    // Fallback to online streaming
    return window.api.getStreamUrl(id);
  }

  getOfflineTrackList() {
    return Array.from(this.downloadedTracks.values());
  }

  toggleOfflineMode() {
    this.isOfflineMode = !this.isOfflineMode;
    localStorage.setItem("ls_offline_mode", String(this.isOfflineMode));
    window.dispatchEvent(new CustomEvent("offline-mode-changed", { detail: { isOffline: this.isOfflineMode } }));
    return this.isOfflineMode;
  }
}

window.offlineManager = new OfflineManager();
