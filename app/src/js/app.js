/**
 * LocalSpotify Main Application Controller
 * Handles UI interactions, view routing, Subsonic data loading, and event bindings.
 */

document.addEventListener("DOMContentLoaded", () => {
  // --- UI Elements ---
  const views = document.querySelectorAll(".view-page");
  const navItems = document.querySelectorAll(".nav-item");
  const searchInput = document.getElementById("search-input");
  const offlineToggleBtn = document.getElementById("offline-toggle-btn");
  const offlineBadge = document.getElementById("offline-badge");

  // Player Elements
  const npCover = document.getElementById("np-cover");
  const npTitle = document.getElementById("np-title");
  const npArtist = document.getElementById("np-artist");
  const playPauseBtn = document.getElementById("play-pause-btn");
  const prevBtn = document.getElementById("prev-btn");
  const nextBtn = document.getElementById("next-btn");
  const shuffleBtn = document.getElementById("shuffle-btn");
  const repeatBtn = document.getElementById("repeat-btn");
  const seekBar = document.getElementById("seek-bar");
  const currentTimeLabel = document.getElementById("current-time");
  const durationTimeLabel = document.getElementById("duration-time");
  const volumeBar = document.getElementById("volume-bar");

  // Settings Modal Elements
  const settingsModal = document.getElementById("settings-modal");
  const settingsBtn = document.getElementById("settings-btn");
  const closeSettingsBtn = document.getElementById("close-settings-btn");
  const saveSettingsBtn = document.getElementById("save-settings-btn");
  const serverUrlInput = document.getElementById("cfg-server-url");
  const usernameInput = document.getElementById("cfg-username");
  const passwordInput = document.getElementById("cfg-password");

  // Active track lists state
  let currentViewTracks = [];

  // --- Helper: Format Time (mm:ss) ---
  function formatTime(seconds) {
    if (!seconds || isNaN(seconds) || seconds < 0) return "0:00";
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins}:${secs < 10 ? '0' : ''}${secs}`;
  }

  // --- Navigation & Routing ---
  function switchView(viewId) {
    views.forEach(v => v.classList.remove("active"));
    navItems.forEach(n => n.classList.remove("active"));

    const targetView = document.getElementById(viewId);
    const targetNav = document.querySelector(`[data-view="${viewId}"]`);

    if (targetView) targetView.classList.add("active");
    if (targetNav) targetNav.classList.add("active");

    if (viewId === "view-liked") loadLikedSongs();
    else if (viewId === "view-downloads") loadDownloadedSongs();
    else if (viewId === "view-playlists") loadPlaylists();
  }

  navItems.forEach(item => {
    item.addEventListener("click", () => {
      const viewId = item.getAttribute("data-view");
      if (viewId) switchView(viewId);
    });
  });

  // --- Render Track Row ---
  function renderTrackRow(track, index, container) {
    const isDownloaded = window.offlineManager.isDownloaded(track.id);
    const isDownloading = window.offlineManager.isDownloading(track.id);
    const currentPlaying = window.player.getCurrentTrack();
    const isPlayingThis = currentPlaying && currentPlaying.id === track.id;

    const coverUrl = track.coverBlob
      ? URL.createObjectURL(track.coverBlob)
      : window.api.getCoverArtUrl(track.coverArt || track.albumId, 100);

    const row = document.createElement("div");
    row.className = `track-row ${isPlayingThis ? "playing" : ""}`;
    row.setAttribute("data-track-id", track.id);

    row.innerHTML = `
      <div class="track-index">${isPlayingThis ? '🔊' : index + 1}</div>
      <div class="track-info">
        <img class="track-thumb" src="${coverUrl || 'assets/default_cover.png'}" onerror="this.src='data:image/svg+xml;utf8,<svg xmlns=\'http://www.w3.org/2000/svg\' width=\'44\' height=\'44\' viewBox=\'0 0 24 24\' fill=\'%23333\'><rect width=\'24\' height=\'24\' fill=\'%23222\'/><path d=\'M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z\' fill=\'%23666\'/></svg>'">
        <div class="track-details">
          <div class="track-title">${track.title || "Unknown Title"}</div>
          <div class="track-artist">${track.artist || "Unknown Artist"}</div>
        </div>
      </div>
      <div class="track-album">${track.album || ""}</div>
      <div class="track-duration">${formatTime(track.duration)}</div>
      <button class="download-btn ${isDownloaded ? 'downloaded' : ''} ${isDownloading ? 'downloading' : ''}" title="${isDownloaded ? 'Downloaded (Offline Ready)' : 'Download Offline'}">
        ${isDownloaded ? '✔' : isDownloading ? '⏳' : '⬇️'}
      </button>
    `;

    // Click track row to play
    row.addEventListener("click", (e) => {
      if (e.target.closest(".download-btn")) return;
      window.player.setQueue(currentViewTracks, index);
    });

    // Download button action
    const dlBtn = row.querySelector(".download-btn");
    dlBtn.addEventListener("click", (e) => {
      e.stopPropagation();
      if (isDownloaded) {
        if (confirm(`Remove "${track.title}" from offline downloads?`)) {
          window.offlineManager.removeTrack(track.id);
        }
      } else {
        window.offlineManager.downloadTrack(track);
      }
    });

    container.appendChild(row);
  }

  // --- Load Views ---
  async function loadLikedSongs() {
    const list = document.getElementById("liked-track-list");
    list.innerHTML = `<div style="padding:20px; color:var(--text-muted);">Loading your library...</div>`;

    if (window.offlineManager.isOfflineMode) {
      loadDownloadedSongs();
      return;
    }

    try {
      const data = await window.api.getStarred();
      const songs = data?.starred?.song || [];
      currentViewTracks = songs;
      list.innerHTML = "";

      if (songs.length === 0) {
        list.innerHTML = `<div style="padding:20px; color:var(--text-muted);">No songs found. Download tracks using the python script or star songs in Navidrome!</div>`;
        return;
      }

      document.getElementById("liked-count").textContent = `${songs.length} songs`;
      songs.forEach((song, idx) => renderTrackRow(song, idx, list));
    } catch (e) {
      list.innerHTML = `<div style="padding:20px; color:var(--danger);">Failed to load library: ${e.message}. Check your Server URL in settings.</div>`;
    }
  }

  function loadDownloadedSongs() {
    const list = document.getElementById("downloads-track-list");
    list.innerHTML = "";
    const downloaded = window.offlineManager.getOfflineTrackList();
    currentViewTracks = downloaded;

    document.getElementById("downloads-count").textContent = `${downloaded.length} songs downloaded`;

    if (downloaded.length === 0) {
      list.innerHTML = `<div style="padding:30px; text-align:center; color:var(--text-muted);">No downloaded songs yet. Click the ⬇️ icon on any song to save it for offline listening!</div>`;
      return;
    }

    downloaded.forEach((song, idx) => renderTrackRow(song, idx, list));
  }

  async function loadPlaylists() {
    const list = document.getElementById("playlists-track-list");
    list.innerHTML = `<div style="padding:20px; color:var(--text-muted);">Loading playlists...</div>`;

    try {
      const data = await window.api.getPlaylists();
      const playlists = data?.playlists?.playlist || [];
      list.innerHTML = "";

      if (playlists.length === 0) {
        list.innerHTML = `<div style="padding:20px; color:var(--text-muted);">No playlists found on your server.</div>`;
        return;
      }

      playlists.forEach((pl) => {
        const card = document.createElement("div");
        card.className = "track-row";
        card.innerHTML = `
          <div class="track-index">📁</div>
          <div class="track-info">
            <div class="track-details">
              <div class="track-title">${pl.name}</div>
              <div class="track-artist">${pl.songCount || 0} songs • ${formatTime(pl.duration)}</div>
            </div>
          </div>
          <div class="track-album">Playlist</div>
          <div class="track-duration"></div>
          <div></div>
        `;
        card.addEventListener("click", async () => {
          const detail = await window.api.getPlaylist(pl.id);
          const songs = detail?.playlist?.entry || [];
          currentViewTracks = songs;
          list.innerHTML = "";
          songs.forEach((s, idx) => renderTrackRow(s, idx, list));
        });
        list.appendChild(card);
      });
    } catch (e) {
      list.innerHTML = `<div style="padding:20px; color:var(--danger);">Failed to load playlists: ${e.message}</div>`;
    }
  }

  // --- Search Input ---
  let searchTimeout = null;
  searchInput.addEventListener("input", () => {
    clearTimeout(searchTimeout);
    searchTimeout = setTimeout(async () => {
      const q = searchInput.value.trim();
      if (!q) return;

      switchView("view-search");
      const list = document.getElementById("search-track-list");
      list.innerHTML = `<div style="padding:20px; color:var(--text-muted);">Searching for "${q}"...</div>`;

      try {
        const data = await window.api.search3(q);
        const songs = data?.searchResult3?.song || [];
        currentViewTracks = songs;
        list.innerHTML = "";

        if (songs.length === 0) {
          list.innerHTML = `<div style="padding:20px; color:var(--text-muted);">No results found for "${q}"</div>`;
          return;
        }

        songs.forEach((song, idx) => renderTrackRow(song, idx, list));
      } catch (e) {
        list.innerHTML = `<div style="padding:20px; color:var(--danger);">Search error: ${e.message}</div>`;
      }
    }, 300);
  });

  // --- Offline Mode Toggle ---
  offlineToggleBtn.addEventListener("click", () => {
    const isOffline = window.offlineManager.toggleOfflineMode();
    updateOfflineBadge(isOffline);
    if (isOffline) {
      switchView("view-downloads");
    } else {
      switchView("view-liked");
    }
  });

  function updateOfflineBadge(isOffline) {
    if (isOffline) {
      offlineBadge.textContent = "Offline Mode";
      offlineBadge.className = "pill-badge offline";
      offlineToggleBtn.classList.add("offline-active");
    } else {
      offlineBadge.textContent = "Online";
      offlineBadge.className = "pill-badge online";
      offlineToggleBtn.classList.remove("offline-active");
    }
  }
  updateOfflineBadge(window.offlineManager.isOfflineMode);

  // --- Player Event Listeners ---
  playPauseBtn.addEventListener("click", () => window.player.togglePlay());
  prevBtn.addEventListener("click", () => window.player.prev());
  nextBtn.addEventListener("click", () => window.player.next());
  shuffleBtn.addEventListener("click", () => window.player.toggleShuffle());
  repeatBtn.addEventListener("click", () => window.player.toggleRepeat());

  seekBar.addEventListener("input", () => {
    window.player.seek(parseFloat(seekBar.value));
  });

  volumeBar.addEventListener("input", () => {
    window.player.setVolume(parseFloat(volumeBar.value));
  });

  window.addEventListener("player-state-changed", (e) => {
    playPauseBtn.innerHTML = e.detail.isPlaying ? "⏸" : "▶";
  });

  window.addEventListener("player-track-changed", (e) => {
    const { track, coverUrl } = e.detail;
    npTitle.textContent = track.title || "Unknown Title";
    npArtist.textContent = track.artist || "Unknown Artist";
    npCover.src = coverUrl || "assets/default_cover.png";

    // Refresh row highlighted states
    document.querySelectorAll(".track-row").forEach(r => {
      if (r.getAttribute("data-track-id") === String(track.id)) {
        r.classList.add("playing");
      } else {
        r.classList.remove("playing");
      }
    });
  });

  window.addEventListener("player-timeupdate", (e) => {
    const { current, duration } = e.detail;
    if (duration > 0) {
      seekBar.max = duration;
      seekBar.value = current;
      currentTimeLabel.textContent = formatTime(current);
      durationTimeLabel.textContent = formatTime(duration);
    }
  });

  window.addEventListener("player-shuffle-changed", (e) => {
    shuffleBtn.classList.toggle("active", e.detail.isShuffle);
  });

  window.addEventListener("player-repeat-changed", (e) => {
    repeatBtn.classList.toggle("active", e.detail.repeatMode !== "none");
    repeatBtn.title = `Repeat: ${e.detail.repeatMode}`;
  });

  window.addEventListener("track-download-state", () => {
    // Refresh current view tracks download badges
    const currentActiveView = document.querySelector(".view-page.active");
    if (currentActiveView) {
      const activeId = currentActiveView.id;
      if (activeId === "view-downloads") loadDownloadedSongs();
    }
  });

  // --- Settings Modal Handling ---
  settingsBtn.addEventListener("click", () => {
    serverUrlInput.value = window.api.serverUrl;
    usernameInput.value = window.api.username;
    passwordInput.value = window.api.password;
    settingsModal.classList.add("active");
  });

  closeSettingsBtn.addEventListener("click", () => settingsModal.classList.remove("active"));

  saveSettingsBtn.addEventListener("click", async () => {
    const sUrl = serverUrlInput.value.trim();
    const uName = usernameInput.value.trim();
    const pWord = passwordInput.value.trim();

    window.api.saveConfig(sUrl, uName, pWord);
    settingsModal.classList.remove("active");

    try {
      await window.api.ping();
      alert("✔ Successfully connected to LocalSpotify Server!");
      loadLikedSongs();
    } catch (err) {
      alert(`⚠️ Connection test failed: ${err.message}`);
    }
  });

  // Initial Load
  switchView("view-liked");
});
