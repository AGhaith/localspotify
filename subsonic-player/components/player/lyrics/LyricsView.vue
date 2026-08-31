<script setup lang="ts">
import PreloadImage from '@/components/media/PreloadImage.vue';
import ButtonLink from '@/components/ui/ButtonLink.vue';

const {
  closeLyrics,
  currentLineIndex,
  error,
  fetchLyrics,
  isLoading,
  isSynced,
  jumpToLyric,
  lyricLines,
  source,
  toggleLyrics,
} = useLyrics();

const { currentTrack, hasCurrentTrack } = useQueue();
const { isPlaying } = useAudioPlayer();

const lineElementsRef = ref<(HTMLElement | null)[]>([]);
const lyricsContainerRef = ref<HTMLElement | null>(null);

function getArtistName(track: PlayableTrack): string {
  if ('artists' in track && track.artists?.length) {
    return track.artists.map((a) => a.name).join(', ');
  }
  if ('author' in track && track.author) {
    return track.author;
  }
  if ('artist' in track && track.artist) {
    return track.artist;
  }
  return 'Unknown Artist';
}

// Auto-scroll the active lyric line to the center of the viewport
watch(currentLineIndex, (newIndex) => {
  if (newIndex < 0 || !lineElementsRef.value[newIndex]) return;

  const targetEl = lineElementsRef.value[newIndex];
  if (targetEl) {
    targetEl.scrollIntoView({
      behavior: 'smooth',
      block: 'center',
    });
  }
});
</script>

<template>
  <section :class="['queueWrapper', $style.lyricsOverlay]">
    <!-- Blurred Album Artwork Background -->
    <div
      v-if="hasCurrentTrack && currentTrack.image"
      aria-hidden="true"
      :class="[
        $style.backgroundImage,
        {
          [$style.backgroundImageActive]: isPlaying,
        },
      ]"
    >
      <PreloadImage
        :class="$style.backgroundPreloadImage"
        :image="currentTrack.image"
        :lazyLoad="false"
      />
    </div>

    <!-- Gradient Darkness Overlay -->
    <div :class="$style.colorOverlay" />

    <div :class="$style.container">
      <!-- Top Header Navigation -->
      <header :class="$style.headerBar">
        <ButtonLink
          :class="$style.closeButton"
          :icon="ICONS.queueClose"
          iconWeight="bold"
          title="Close lyrics"
          @click="toggleLyrics"
        >
          Close
        </ButtonLink>

        <div :class="$style.headerCenter">
          <p :class="$style.trackTitle">
            {{ currentTrack.name || 'Lyrics' }}
          </p>
          <p :class="$style.artistSubtitle">
            {{ getArtistName(currentTrack) }}
          </p>
        </div>

        <div :class="$style.headerRight">
          <span v-if="source" :class="$style.sourceBadge">
            {{ source }}
          </span>
        </div>
      </header>

      <!-- Loading State -->
      <div v-if="isLoading" :class="$style.centerMessage">
        <PhCircleNotch :class="$style.spinner" size="44" />
        <p :class="$style.loadingText">Fetching lyrics...</p>
      </div>

      <!-- Error / Empty State -->
      <div v-else-if="error || !lyricLines.length" :class="$style.centerMessage">
        <PhWaveSine size="48" :class="$style.errorIcon" />
        <p :class="$style.errorHeading">No lyrics found</p>
        <p :class="$style.errorSubtext">
          {{ error || "Couldn't find lyrics for this song." }}
        </p>
        <button
          type="button"
          :class="$style.retryButton"
          @click="fetchLyrics(true)"
        >
          <PhArrowsClockwise size="18" />
          <span>Try again</span>
        </button>
      </div>

      <!-- Lyrics Lines Container -->
      <div
        v-else
        ref="lyricsContainerRef"
        :class="[
          $style.lyricsBody,
          {
            [$style.syncedBody]: isSynced,
          },
        ]"
      >
        <div :class="$style.topPadding" />

        <div
          v-for="(line, index) in lyricLines"
          :key="`${index}-${line.time}`"
          :ref="(el) => { lineElementsRef[index] = el as HTMLElement }"
          :class="[
            $style.lyricLine,
            {
              [$style.activeLine]: isSynced && index === currentLineIndex,
              [$style.pastLine]: isSynced && currentLineIndex !== -1 && index < currentLineIndex,
              [$style.futureLine]: isSynced && currentLineIndex !== -1 && index > currentLineIndex,
              [$style.clickable]: isSynced && line.time !== undefined,
            },
          ]"
          @click="isSynced && line.time !== undefined && jumpToLyric(line.time)"
        >
          <span :class="$style.lineText">{{ line.text || '♪' }}</span>
        </div>

        <div :class="$style.bottomPadding" />
      </div>
    </div>
  </section>
</template>

<style module>
.lyricsOverlay {
  position: fixed;
  inset: 0;
  z-index: 100;
  display: flex;
  flex-direction: column;
  background-color: #0b0b0d !important;
  color: #ffffff;
  overflow: hidden;
}

.backgroundImage {
  position: absolute;
  inset: -20%;
  width: 140%;
  height: 140%;
  opacity: 0.45;
  filter: blur(60px) saturate(1.8) brightness(0.6);
  pointer-events: none;
  transition: transform 1.2s ease, opacity 0.5s ease;
  z-index: 1;
}

.backgroundImageActive {
  transform: scale(1.05);
}

.backgroundPreloadImage {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.colorOverlay {
  position: absolute;
  inset: 0;
  background: radial-gradient(circle at 50% 30%, rgba(0, 0, 0, 0.4) 0%, rgba(0, 0, 0, 0.85) 100%);
  pointer-events: none;
  z-index: 2;
}

.container {
  position: relative;
  z-index: 3;
  display: flex;
  flex-direction: column;
  width: 100%;
  max-width: 760px;
  height: 100svh;
  margin: 0 auto;
  padding: 16px 20px 0;
  box-sizing: border-box;
}

.headerBar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  padding-bottom: 12px;
  border-bottom: 1px solid rgba(255, 255, 255, 0.08);
  flex-shrink: 0;
}

.closeButton {
  font-size: 0.95rem;
  font-weight: 700;
  color: #e4e4e7 !important;
}

.headerCenter {
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
  min-width: 0;
  flex: 1;
}

.trackTitle {
  font-size: 1.05rem;
  font-weight: 800;
  color: #ffffff;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  max-width: 100%;
  margin: 0;
}

.artistSubtitle {
  font-size: 0.82rem;
  font-weight: 500;
  color: #a1a1aa;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  max-width: 100%;
  margin: 2px 0 0;
}

.headerRight {
  display: flex;
  justify-content: flex-end;
  min-width: 60px;
}

.sourceBadge {
  font-size: 0.72rem;
  font-weight: 600;
  color: #22c55e;
  background: rgba(34, 197, 94, 0.12);
  border: 1px solid rgba(34, 197, 94, 0.25);
  padding: 3px 8px;
  border-radius: 9999px;
  text-transform: uppercase;
  letter-spacing: 0.04em;
}

.centerMessage {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  flex: 1;
  gap: 14px;
  text-align: center;
  padding: 40px 20px;
}

.spinner {
  animation: spin 1s linear infinite;
  color: #22c55e;
}

@keyframes spin {
  from {
    transform: rotate(0deg);
  }
  to {
    transform: rotate(360deg);
  }
}

.loadingText {
  font-size: 1.1rem;
  font-weight: 600;
  color: #d4d4d8;
}

.errorIcon {
  color: #71717a;
  opacity: 0.7;
}

.errorHeading {
  font-size: 1.3rem;
  font-weight: 700;
  color: #ffffff;
  margin: 0;
}

.errorSubtext {
  font-size: 0.95rem;
  color: #a1a1aa;
  margin: 0;
}

.retryButton {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  margin-top: 8px;
  padding: 8px 18px;
  background-color: #27272a;
  color: #ffffff;
  border: 1px solid rgba(255, 255, 255, 0.15);
  border-radius: 20px;
  font-size: 0.9rem;
  font-weight: 600;
  cursor: pointer;
  transition: background-color 0.15s ease, transform 0.1s ease;

  &:hover {
    background-color: #3f3f46;
    transform: scale(1.03);
  }

  &:active {
    transform: scale(0.97);
  }
}

.lyricsBody {
  flex: 1;
  overflow-y: auto;
  overflow-x: hidden;
  padding: 20px 8px;
  scroll-behavior: smooth;
  -webkit-overflow-scrolling: touch;
}

.syncedBody {
  text-align: left;
}

.topPadding {
  height: 25vh;
}

.bottomPadding {
  height: 35vh;
}

.lyricLine {
  position: relative;
  padding: 12px 14px;
  border-radius: 8px;
  font-size: 1.45rem;
  font-weight: 700;
  line-height: 1.4;
  letter-spacing: -0.02em;
  color: rgba(255, 255, 255, 0.4);
  transition: color 0.25s cubic-bezier(0.2, 0.9, 0.3, 1),
              transform 0.25s cubic-bezier(0.2, 0.9, 0.3, 1),
              opacity 0.25s ease;
  user-select: none;

  @media (max-width: 640px) {
    font-size: 1.25rem;
    padding: 10px 10px;
  }
}

.clickable {
  cursor: pointer;

  &:hover {
    color: rgba(255, 255, 255, 0.85);
    background-color: rgba(255, 255, 255, 0.05);
  }
}

.activeLine {
  color: #ffffff !important;
  font-weight: 800;
  transform: scale(1.03);
  transform-origin: left center;
  text-shadow: 0 0 20px rgba(255, 255, 255, 0.4);

  .lineText {
    color: #ffffff;
  }
}

.pastLine {
  color: rgba(255, 255, 255, 0.45);
}

.futureLine {
  color: rgba(255, 255, 255, 0.3);
}

.lineText {
  display: inline-block;
  transition: color 0.2s ease;
}
</style>
