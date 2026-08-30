<script setup lang="ts">
import ArtistLinkList from '@/components/artist/ArtistLinkList.vue';
import ImageLink from '@/components/media/ImageLink.vue';
import PreloadImage from '@/components/media/PreloadImage.vue';
import PlayPauseButton from '@/components/player/controls/PlayPauseButton.vue';
import QueueButton from '@/components/player/controls/QueueButton.vue';
import TrackSeeker from '@/components/player/controls/TrackSeeker.vue';
import MarqueeScroll from '@/components/ui/MarqueeScroll.vue';

import PlayerControls from './PlayerControls.vue';
import PlayerOptions from './PlayerOptions.vue';

const { currentTrack } = useQueue();
</script>

<template>
  <div :class="$style.musicPlayerContainer">
    <div :class="['spaceBetween', 'centerItems', $style.dockedBar]">
      <!-- Left Track Details -->
      <div :class="['centerItems', $style.trackDetailsWrapper]">
        <QueueButton :class="['mobileOnly', $style.queueControl]" />

        <div :class="$style.imageContainer">
          <ImageLink
            v-if="'albumId' in currentTrack && currentTrack.albumId"
            ref="albumImageLink"
            :class="$style.image"
            :image="currentTrack.image"
            :title="`Go to album ${currentTrack.album}`"
            :to="{
              name: ROUTE_NAMES.album,
              params: {
                [ROUTE_PARAM_KEYS.album.id]: currentTrack.albumId,
              },
            }"
          />

          <ImageLink
            v-else-if="'podcastId' in currentTrack && currentTrack.podcastId"
            ref="podcastImageLink"
            :class="$style.image"
            :image="currentTrack.image"
            :title="`Go to podcast ${currentTrack.podcastName}`"
            :to="{
              name: ROUTE_NAMES.podcast,
              params: {
                [ROUTE_PARAM_KEYS.podcast.sortBy]:
                  ROUTE_PODCAST_FILTER_PARAMS.All,
                [ROUTE_PARAM_KEYS.podcast.id]: currentTrack.podcastId,
              },
            }"
          />

          <PreloadImage
            v-else
            :class="$style.image"
            :image="currentTrack.image"
          />
        </div>

        <div :class="$style.trackDetails">
          <MarqueeScroll>
            <p :class="$style.trackName">
              {{ currentTrack.name }}
            </p>
          </MarqueeScroll>

          <MarqueeScroll
            v-if="'artists' in currentTrack && currentTrack.artists.length"
            ref="artistsMarqueeScroll"
          >
            <ArtistLinkList :artists="currentTrack.artists" :class="$style.artistLink" />
          </MarqueeScroll>

          <MarqueeScroll
            v-if="'author' in currentTrack && currentTrack.author"
            ref="authorMarqueeScroll"
          >
            <p :class="$style.artistLink">{{ currentTrack.author }}</p>
          </MarqueeScroll>
        </div>
      </div>

      <!-- Center Waveform & Controls (Desktop) -->
      <div :class="['column', 'centerItems', 'desktopOnly', $style.centerSection]">
        <PlayerControls />
        <div :class="$style.waveformContainer">
          <TrackSeeker noWaves showTime />
        </div>
      </div>

      <!-- Right Options (Desktop) -->
      <PlayerOptions :class="['desktopOnly', $style.playerOptions]" />

      <!-- Mobile Right Controls -->
      <div :class="['mobileOnly', 'centerItems', $style.mobileControls]">
        <PlayPauseButton />
      </div>

      <!-- Mobile Interactive Seek Scrubber (With thumb circle & 00:00/00:00 tooltip) -->
      <div :class="['mobileOnly', $style.mobileProgress]">
        <TrackSeeker minimized noWaves />
      </div>
    </div>
  </div>
</template>

<style module>
.musicPlayerContainer {
  position: fixed;
  inset: auto 0 var(--header-height) 0;
  z-index: 18;
  width: 100%;
  pointer-events: none;

  @media (--tablet-up) {
    inset: auto 0 0 0;
    z-index: 20;
    margin-left: var(--sidebar-width);
    width: calc(100% - var(--sidebar-width));
  }
}

.dockedBar {
  position: relative;
  width: 100%;
  min-height: 58px;
  padding: 6px 14px 8px;
  pointer-events: auto;
  background-color: #0e0e12;
  border-top: 1px solid rgba(255, 255, 255, 0.12);
  border-bottom: 1px solid rgba(0, 0, 0, 0.8);
  box-shadow: 0 -4px 18px rgba(0, 0, 0, 0.7);
  backdrop-filter: blur(20px);
  gap: 12px;

  @media (--tablet-up) {
    display: grid;
    grid-template-columns: 28% 44% 28%;
    align-items: center;
    min-height: 84px;
    padding: 8px 24px;
    background-color: #0a0a0d;
    border-top: 1px solid rgba(255, 255, 255, 0.1);
    border-bottom: none;
    box-shadow: 0 -4px 24px rgba(0, 0, 0, 0.8);
    gap: 16px;
  }
}

.trackDetailsWrapper {
  position: relative;
  gap: 12px;
  min-width: 0;
  overflow: hidden;
}

.imageContainer {
  position: relative;
  flex-shrink: 0;
  width: 44px;
  height: 44px;
  overflow: hidden;
  border-radius: 6px;
  background-color: #18181b;
  border: 1px solid rgba(255, 255, 255, 0.1);

  @media (--tablet-up) {
    width: 52px;
    height: 52px;
    border-radius: 8px;
  }
}

.image {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.trackDetails {
  display: flex;
  flex: 1;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
  overflow: hidden;
}

.trackName {
  font-size: 0.92rem;
  font-weight: 700;
  line-height: 1.25;
  color: #ffffff;
  white-space: nowrap;
}

.artistLink {
  font-size: 0.78rem;
  font-weight: 400;
  line-height: 1.25;
  color: #a1a1aa !important;
  white-space: nowrap;
}

.queueControl {
  position: absolute;
  inset: 0;
  z-index: 1;
  opacity: 0;
}

.centerSection {
  width: 100%;
  gap: 4px;
}

.waveformContainer {
  width: 100%;
  max-width: 420px;
}

.playerOptions {
  justify-content: flex-end;
}

.mobileControls {
  flex-shrink: 0;
  gap: 8px;
}

.mobileProgress {
  position: absolute;
  right: 0;
  bottom: 0;
  left: 0;
  z-index: 10;
  height: 18px;
  display: flex;
  align-items: flex-end;
  pointer-events: auto;
}
</style>
