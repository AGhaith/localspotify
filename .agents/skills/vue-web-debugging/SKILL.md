---
name: vue-web-debugging
description: >-
  Systematic debugging workflows for Vue 3, Nuxt 4, Pinia, Web Audio API, and IndexedDB Blob storage.
  Use when troubleshooting reactivity issues, audio playback state, SSR hydration, or offline cache errors.
---

# Vue 3 & Nuxt 4 Web Audio Debugging Guide

## 🛠️ Key Debugging Workflows

### 1. IndexedDB Blob & Cache Debugging
- Inspect `indexedDB` databases directly in browser DevTools under Application > Storage > IndexedDB.
- When saving audio files as Blobs, always verify `blob.type` (e.g. `audio/mp4`, `audio/mpeg`, `audio/flac`) and `blob.size > 0`.
- Release object URLs with `URL.revokeObjectURL(url)` when replacing or unmounting to prevent memory leaks.

### 2. Web Audio API & HTML5 Audio Troubleshooting
- Check `AudioContext.state` (if `'suspended'`, resume on first user interaction: `audioContext.resume()`).
- In crossfade / multi-track switching, ensure previous source nodes are disconnected (`sourceNode.disconnect()`) before creating new ones to avoid stacking audio buffers.
- For offline playback fallback:
  ```ts
  try {
    const blobUrl = await getTrackAudioBlobUrl(track.id);
    if (blobUrl) audio.src = blobUrl;
  } catch (err) {
    console.warn('Offline blob resolution failed, attempting network stream', err);
    audio.src = getStreamUrl(track.id);
  }
  ```

### 3. Nuxt 4 Hydration & Reactive State
- Wrap browser-only APIs (`indexedDB`, `AudioContext`, `localStorage`, `navigator`) inside `if (import.meta.client)` or `onMounted()`.
- Use Vue `shallowRef` for large arrays or binary Blobs to avoid overhead from deep reactivity proxies.
