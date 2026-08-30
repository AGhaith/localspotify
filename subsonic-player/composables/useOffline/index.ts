const DB_NAME = 'subsonic_player_offline_db';
const DB_VERSION = 1;

export interface OfflineDownloadProgress {
  id: string;
  name: string;
  current: number;
  total: number;
  progress: number;
  isDownloading: boolean;
}

export interface OfflinePlaylistRecord {
  id: string;
  name: string;
  trackCount: number;
  duration?: number;
  formattedDuration?: string;
  images: string[];
  trackIds: string[];
  savedAt: number;
}

export interface OfflineAlbumRecord {
  id: string;
  name: string;
  artist: string;
  trackCount: number;
  images: string[];
  trackIds: string[];
  savedAt: number;
}

export function useOffline() {
  const { getImageUrl, getStreamUrl } = useAPI();
  const { addErrorSnack, addInfoSnack, addSuccessSnack } = useSnack();

  const downloadedTrackIds = useState<Set<string>>(
    'offline_downloaded_track_ids',
    () => new Set(),
  );
  const downloadedPlaylistIds = useState<Set<string>>(
    'offline_downloaded_playlist_ids',
    () => new Set(),
  );
  const downloadedAlbumIds = useState<Set<string>>(
    'offline_downloaded_album_ids',
    () => new Set(),
  );
  const activeDownloads = useState<Map<string, OfflineDownloadProgress>>(
    'offline_active_downloads',
    () => new Map(),
  );
  const isOfflineStorageReady = useState<boolean>(
    'offline_storage_ready',
    () => false,
  );

  // Object URL cache to avoid generating duplicate blob URLs and manage memory.
  const blobUrlCache = new Map<string, string>();

  function openDB(): Promise<IDBDatabase> {
    return new Promise((resolve, reject) => {
      if (!import.meta.client) {
        reject(new Error('IndexedDB is only available on client'));
        return;
      }

      const request = indexedDB.open(DB_NAME, DB_VERSION);

      request.onupgradeneeded = (event) => {
        const db = (event.target as IDBOpenDBRequest).result;

        if (!db.objectStoreNames.contains('tracks')) {
          const trackStore = db.createObjectStore('tracks', { keyPath: 'id' });
          trackStore.createIndex('albumId', 'albumId', { unique: false });
        }

        if (!db.objectStoreNames.contains('playlists')) {
          db.createObjectStore('playlists', { keyPath: 'id' });
        }

        if (!db.objectStoreNames.contains('albums')) {
          db.createObjectStore('albums', { keyPath: 'id' });
        }

        if (!db.objectStoreNames.contains('audio_blobs')) {
          db.createObjectStore('audio_blobs', { keyPath: 'id' });
        }

        if (!db.objectStoreNames.contains('cover_blobs')) {
          db.createObjectStore('cover_blobs', { keyPath: 'id' });
        }
      };

      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
  }

  async function syncDownloadedSets() {
    if (!import.meta.client) return;

    try {
      const db = await openDB();

      // Sync tracks
      const trackTx = db.transaction('tracks', 'readonly');
      const trackStore = trackTx.objectStore('tracks');
      const allTrackKeys = await new Promise<string[]>((res, rej) => {
        const req = trackStore.getAllKeys();
        req.onsuccess = () => res(req.result as string[]);
        req.onerror = () => rej(req.error);
      });
      downloadedTrackIds.value = new Set(allTrackKeys);

      // Sync playlists
      const playlistTx = db.transaction('playlists', 'readonly');
      const playlistStore = playlistTx.objectStore('playlists');
      const allPlaylistKeys = await new Promise<string[]>((res, rej) => {
        const req = playlistStore.getAllKeys();
        req.onsuccess = () => res(req.result as string[]);
        req.onerror = () => rej(req.error);
      });
      downloadedPlaylistIds.value = new Set(allPlaylistKeys);

      // Sync albums
      const albumTx = db.transaction('albums', 'readonly');
      const albumStore = albumTx.objectStore('albums');
      const allAlbumKeys = await new Promise<string[]>((res, rej) => {
        const req = albumStore.getAllKeys();
        req.onsuccess = () => res(req.result as string[]);
        req.onerror = () => rej(req.error);
      });
      downloadedAlbumIds.value = new Set(allAlbumKeys);

      isOfflineStorageReady.value = true;
    } catch (err) {
      console.warn('Failed to sync offline storage indices:', err);
    }
  }

  // --- Fetch & Store Helpers ---
  async function saveBlob(
    storeName: 'audio_blobs' | 'cover_blobs',
    id: string,
    blob: Blob,
  ): Promise<void> {
    const db = await openDB();
    return new Promise((resolve, reject) => {
      const tx = db.transaction(storeName, 'readwrite');
      const store = tx.objectStore(storeName);
      const req = store.put({ id, blob, size: blob.size, mimeType: blob.type });
      req.onsuccess = () => resolve();
      req.onerror = () => reject(req.error);
    });
  }

  async function getBlob(
    storeName: 'audio_blobs' | 'cover_blobs',
    id: string,
  ): Promise<Blob | null> {
    const db = await openDB();
    return new Promise((resolve, reject) => {
      const tx = db.transaction(storeName, 'readonly');
      const store = tx.objectStore(storeName);
      const req = store.get(id);
      req.onsuccess = () => {
        if (req.result && req.result.blob) {
          resolve(req.result.blob);
        } else {
          resolve(null);
        }
      };
      req.onerror = () => reject(req.error);
    });
  }

  // --- Track Download ---
  async function downloadTrack(track: PlayableTrack): Promise<boolean> {
    if (!track?.id || !import.meta.client) return false;

    try {
      const streamUrl = getStreamUrl(track.streamUrlId || track.id);
      const audioResponse = await fetch(streamUrl);
      if (!audioResponse.ok) {
        throw new Error(`Failed to fetch audio stream: ${audioResponse.statusText}`);
      }
      const audioBlob = await audioResponse.blob();
      await saveBlob('audio_blobs', track.id, audioBlob);

      // Download Cover Art if available
      if (track.image) {
        try {
          const coverUrl = getImageUrl(track.image, '300');
          const coverResponse = await fetch(coverUrl);
          if (coverResponse.ok) {
            const coverBlob = await coverResponse.blob();
            await saveBlob('cover_blobs', track.image, coverBlob);
          }
        } catch {
          // Non-fatal if cover fails
        }
      }

      // Save Track metadata
      const db = await openDB();
      await new Promise<void>((resolve, reject) => {
        const tx = db.transaction('tracks', 'readwrite');
        const store = tx.objectStore('tracks');
        const req = store.put({
          ...track,
          savedAt: Date.now(),
        });
        req.onsuccess = () => resolve();
        req.onerror = () => reject(req.error);
      });

      const nextSet = new Set(downloadedTrackIds.value);
      nextSet.add(track.id);
      downloadedTrackIds.value = nextSet;

      return true;
    } catch (err) {
      console.error(`Failed to download track "${track.title}":`, err);
      return false;
    }
  }

  // --- Playlist Download ---
  async function downloadPlaylist(playlist: Playlist): Promise<void> {
    if (!playlist || !playlist.tracks?.length || !import.meta.client) {
      addErrorSnack('No tracks found to download.');
      return;
    }

    const playlistId = playlist.id;
    const total = playlist.tracks.length;
    let completed = 0;

    const progress: OfflineDownloadProgress = {
      id: playlistId,
      name: playlist.name,
      current: 0,
      total,
      progress: 0,
      isDownloading: true,
    };

    const nextActive = new Map(activeDownloads.value);
    nextActive.set(playlistId, progress);
    activeDownloads.value = nextActive;

    addInfoSnack(`Downloading "${playlist.name}" (${total} tracks)...`);

    // Download tracks with concurrency pool of 2
    const CONCURRENCY = 2;
    const queue = [...playlist.tracks];
    const trackIds: string[] = [];

    const worker = async () => {
      while (queue.length > 0) {
        const track = queue.shift();
        if (!track) break;

        trackIds.push(track.id);
        const success = await downloadTrack(track);
        if (success) {
          completed++;
        }

        progress.current = completed;
        progress.progress = Math.round((completed / total) * 100);

        const updated = new Map(activeDownloads.value);
        updated.set(playlistId, { ...progress });
        activeDownloads.value = updated;
      }
    };

    const workers = Array.from({ length: Math.min(CONCURRENCY, total) }, () => worker());
    await Promise.all(workers);

    // Save Playlist Record
    try {
      const db = await openDB();
      const playlistRecord: OfflinePlaylistRecord = {
        id: playlistId,
        name: playlist.name,
        trackCount: total,
        duration: playlist.duration,
        formattedDuration: playlist.formattedDuration,
        images: playlist.images || [],
        trackIds,
        savedAt: Date.now(),
      };

      await new Promise<void>((resolve, reject) => {
        const tx = db.transaction('playlists', 'readwrite');
        const store = tx.objectStore('playlists');
        const req = store.put(playlistRecord);
        req.onsuccess = () => resolve();
        req.onerror = () => reject(req.error);
      });

      const nextPSet = new Set(downloadedPlaylistIds.value);
      nextPSet.add(playlistId);
      downloadedPlaylistIds.value = nextPSet;

      addSuccessSnack(`Downloaded "${playlist.name}" for offline playback!`);
    } catch (err) {
      console.error('Failed to save playlist record:', err);
      addErrorSnack(`Error finalizing download for "${playlist.name}".`);
    } finally {
      const finalMap = new Map(activeDownloads.value);
      finalMap.delete(playlistId);
      activeDownloads.value = finalMap;
    }
  }

  // --- Album Download ---
  async function downloadAlbum(album: Album): Promise<void> {
    if (!album || !album.tracks?.length || !import.meta.client) {
      addErrorSnack('No tracks found to download.');
      return;
    }

    const albumId = album.id;
    const total = album.tracks.length;
    let completed = 0;

    const progress: OfflineDownloadProgress = {
      id: albumId,
      name: album.name,
      current: 0,
      total,
      progress: 0,
      isDownloading: true,
    };

    const nextActive = new Map(activeDownloads.value);
    nextActive.set(albumId, progress);
    activeDownloads.value = nextActive;

    addInfoSnack(`Downloading "${album.name}" (${total} tracks)...`);

    const queue = [...album.tracks];
    const trackIds: string[] = [];

    const worker = async () => {
      while (queue.length > 0) {
        const track = queue.shift();
        if (!track) break;

        trackIds.push(track.id);
        const success = await downloadTrack(track);
        if (success) completed++;

        progress.current = completed;
        progress.progress = Math.round((completed / total) * 100);

        const updated = new Map(activeDownloads.value);
        updated.set(albumId, { ...progress });
        activeDownloads.value = updated;
      }
    };

    const workers = Array.from({ length: Math.min(2, total) }, () => worker());
    await Promise.all(workers);

    try {
      const db = await openDB();
      const albumRecord: OfflineAlbumRecord = {
        id: albumId,
        name: album.name,
        artist: album.artist,
        trackCount: total,
        images: album.images || [],
        trackIds,
        savedAt: Date.now(),
      };

      await new Promise<void>((resolve, reject) => {
        const tx = db.transaction('albums', 'readwrite');
        const store = tx.objectStore('albums');
        const req = store.put(albumRecord);
        req.onsuccess = () => resolve();
        req.onerror = () => reject(req.error);
      });

      const nextASet = new Set(downloadedAlbumIds.value);
      nextASet.add(albumId);
      downloadedAlbumIds.value = nextASet;

      addSuccessSnack(`Downloaded "${album.name}" for offline playback!`);
    } catch (err) {
      console.error('Failed to save album record:', err);
    } finally {
      const finalMap = new Map(activeDownloads.value);
      finalMap.delete(albumId);
      activeDownloads.value = finalMap;
    }
  }

  // --- Deletion Handlers ---
  async function removeDownloadedTrack(trackId: string): Promise<void> {
    if (!import.meta.client) return;

    try {
      const db = await openDB();
      const tx = db.transaction(['tracks', 'audio_blobs'], 'readwrite');
      tx.objectStore('tracks').delete(trackId);
      tx.objectStore('audio_blobs').delete(trackId);

      await new Promise<void>((resolve, reject) => {
        tx.oncomplete = () => resolve();
        tx.onerror = () => reject(tx.error);
      });

      // Cleanup blob url cache
      if (blobUrlCache.has(trackId)) {
        URL.revokeObjectURL(blobUrlCache.get(trackId)!);
        blobUrlCache.delete(trackId);
      }

      const nextSet = new Set(downloadedTrackIds.value);
      nextSet.delete(trackId);
      downloadedTrackIds.value = nextSet;

      addInfoSnack('Removed download.');
    } catch (err) {
      console.error(`Failed to remove track ${trackId}:`, err);
    }
  }

  async function removeDownloadedPlaylist(playlistId: string): Promise<void> {
    if (!import.meta.client) return;

    try {
      const db = await openDB();

      // Get playlist to find track IDs
      const pTx = db.transaction('playlists', 'readonly');
      const pStore = pTx.objectStore('playlists');
      const playlistRec = await new Promise<OfflinePlaylistRecord | null>((res) => {
        const req = pStore.get(playlistId);
        req.onsuccess = () => res(req.result || null);
        req.onerror = () => res(null);
      });

      const delTx = db.transaction(['playlists', 'tracks', 'audio_blobs'], 'readwrite');
      delTx.objectStore('playlists').delete(playlistId);

      if (playlistRec?.trackIds) {
        for (const tid of playlistRec.trackIds) {
          delTx.objectStore('tracks').delete(tid);
          delTx.objectStore('audio_blobs').delete(tid);
        }
      }

      await new Promise<void>((resolve, reject) => {
        delTx.oncomplete = () => resolve();
        delTx.onerror = () => reject(delTx.error);
      });

      const nextPSet = new Set(downloadedPlaylistIds.value);
      nextPSet.delete(playlistId);
      downloadedPlaylistIds.value = nextPSet;

      await syncDownloadedSets();
      addInfoSnack('Removed offline playlist.');
    } catch (err) {
      console.error(`Failed to remove playlist ${playlistId}:`, err);
    }
  }

  async function removeDownloadedAlbum(albumId: string): Promise<void> {
    if (!import.meta.client) return;

    try {
      const db = await openDB();
      const aTx = db.transaction('albums', 'readonly');
      const aStore = aTx.objectStore('albums');
      const albumRec = await new Promise<OfflineAlbumRecord | null>((res) => {
        const req = aStore.get(albumId);
        req.onsuccess = () => res(req.result || null);
        req.onerror = () => res(null);
      });

      const delTx = db.transaction(['albums', 'tracks', 'audio_blobs'], 'readwrite');
      delTx.objectStore('albums').delete(albumId);

      if (albumRec?.trackIds) {
        for (const tid of albumRec.trackIds) {
          delTx.objectStore('tracks').delete(tid);
          delTx.objectStore('audio_blobs').delete(tid);
        }
      }

      await new Promise<void>((resolve, reject) => {
        delTx.oncomplete = () => resolve();
        delTx.onerror = () => reject(delTx.error);
      });

      const nextASet = new Set(downloadedAlbumIds.value);
      nextASet.delete(albumId);
      downloadedAlbumIds.value = nextASet;

      await syncDownloadedSets();
      addInfoSnack('Removed offline album.');
    } catch (err) {
      console.error(`Failed to remove album ${albumId}:`, err);
    }
  }

  // --- Retrieval & Playback URL Resolution ---
  async function getTrackAudioBlobUrl(trackId: string): Promise<string | null> {
    if (!import.meta.client) return null;

    if (blobUrlCache.has(trackId)) {
      return blobUrlCache.get(trackId)!;
    }

    try {
      const blob = await getBlob('audio_blobs', trackId);
      if (!blob) return null;

      const url = URL.createObjectURL(blob);
      blobUrlCache.set(trackId, url);
      return url;
    } catch (err) {
      console.warn(`Could not resolve blob URL for track ${trackId}:`, err);
      return null;
    }
  }

  async function getDownloadedTracks(): Promise<PlayableTrack[]> {
    if (!import.meta.client) return [];

    try {
      const db = await openDB();
      const tx = db.transaction('tracks', 'readonly');
      const store = tx.objectStore('tracks');
      return new Promise((resolve, reject) => {
        const req = store.getAll();
        req.onsuccess = () => resolve((req.result as PlayableTrack[]) || []);
        req.onerror = () => reject(req.error);
      });
    } catch (err) {
      console.error('Failed to get downloaded tracks:', err);
      return [];
    }
  }

  async function getDownloadedPlaylists(): Promise<OfflinePlaylistRecord[]> {
    if (!import.meta.client) return [];

    try {
      const db = await openDB();
      const tx = db.transaction('playlists', 'readonly');
      const store = tx.objectStore('playlists');
      return new Promise((resolve, reject) => {
        const req = store.getAll();
        req.onsuccess = () => resolve((req.result as OfflinePlaylistRecord[]) || []);
        req.onerror = () => reject(req.error);
      });
    } catch (err) {
      console.error('Failed to get downloaded playlists:', err);
      return [];
    }
  }

  async function getDownloadedAlbums(): Promise<OfflineAlbumRecord[]> {
    if (!import.meta.client) return [];

    try {
      const db = await openDB();
      const tx = db.transaction('albums', 'readonly');
      const store = tx.objectStore('albums');
      return new Promise((resolve, reject) => {
        const req = store.getAll();
        req.onsuccess = () => resolve((req.result as OfflineAlbumRecord[]) || []);
        req.onerror = () => reject(req.error);
      });
    } catch (err) {
      console.error('Failed to get downloaded albums:', err);
      return [];
    }
  }

  async function getStorageUsage(): Promise<{ bytes: number; formatted: string }> {
    if (!import.meta.client) return { bytes: 0, formatted: '0 MB' };

    try {
      const db = await openDB();
      const tx = db.transaction(['audio_blobs', 'cover_blobs'], 'readonly');

      let totalBytes = 0;

      const audioReq = tx.objectStore('audio_blobs').getAll();
      const coverReq = tx.objectStore('cover_blobs').getAll();

      await new Promise<void>((resolve) => {
        tx.oncomplete = () => resolve();
      });

      const audioBlobs = (audioReq.result || []) as { size?: number }[];
      const coverBlobs = (coverReq.result || []) as { size?: number }[];

      for (const item of audioBlobs) {
        totalBytes += item.size || 0;
      }
      for (const item of coverBlobs) {
        totalBytes += item.size || 0;
      }

      const mb = totalBytes / (1024 * 1024);
      const formatted = mb >= 1000 ? `${(mb / 1024).toFixed(2)} GB` : `${mb.toFixed(1)} MB`;

      return { bytes: totalBytes, formatted };
    } catch (err) {
      console.error('Failed to compute storage usage:', err);
      return { bytes: 0, formatted: '0 MB' };
    }
  }

  async function clearAllDownloads(): Promise<void> {
    if (!import.meta.client) return;

    try {
      const db = await openDB();
      const tx = db.transaction(
        ['tracks', 'playlists', 'albums', 'audio_blobs', 'cover_blobs'],
        'readwrite',
      );
      tx.objectStore('tracks').clear();
      tx.objectStore('playlists').clear();
      tx.objectStore('albums').clear();
      tx.objectStore('audio_blobs').clear();
      tx.objectStore('cover_blobs').clear();

      await new Promise<void>((resolve, reject) => {
        tx.oncomplete = () => resolve();
        tx.onerror = () => reject(tx.error);
      });

      // Clear object URL caches
      for (const url of blobUrlCache.values()) {
        URL.revokeObjectURL(url);
      }
      blobUrlCache.clear();

      downloadedTrackIds.value = new Set();
      downloadedPlaylistIds.value = new Set();
      downloadedAlbumIds.value = new Set();

      addSuccessSnack('All offline downloads cleared.');
    } catch (err) {
      console.error('Failed to clear offline storage:', err);
      addErrorSnack('Failed to clear downloads.');
    }
  }

  // --- Boolean Checks ---
  function isTrackDownloaded(trackId: string): boolean {
    return downloadedTrackIds.value.has(trackId);
  }

  function isPlaylistDownloaded(playlistId: string): boolean {
    return downloadedPlaylistIds.value.has(playlistId);
  }

  function isAlbumDownloaded(albumId: string): boolean {
    return downloadedAlbumIds.value.has(albumId);
  }

  function getPlaylistDownloadProgress(playlistId: string): OfflineDownloadProgress | undefined {
    return activeDownloads.value.get(playlistId);
  }

  function getAlbumDownloadProgress(albumId: string): OfflineDownloadProgress | undefined {
    return activeDownloads.value.get(albumId);
  }

  return {
    activeDownloads,
    clearAllDownloads,
    downloadAlbum,
    downloadPlaylist,
    downloadTrack,
    downloadedAlbumIds,
    downloadedPlaylistIds,
    downloadedTrackIds,
    getAlbumDownloadProgress,
    getDownloadedAlbums,
    getDownloadedPlaylists,
    getDownloadedTracks,
    getPlaylistDownloadProgress,
    getStorageUsage,
    getTrackAudioBlobUrl,
    initOffline: syncDownloadedSets,
    isAlbumDownloaded,
    isOfflineStorageReady,
    isPlaylistDownloaded,
    isTrackDownloaded,
    removeDownloadedAlbum,
    removeDownloadedPlaylist,
    removeDownloadedTrack,
  };
}
