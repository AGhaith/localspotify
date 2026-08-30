<script setup lang="ts">
import ArtistLinkList from '@/components/artist/ArtistLinkList.vue';
import FavouriteButton from '@/components/favourite/FavouriteButton.vue';
import PreloadImage from '@/components/media/PreloadImage.vue';
import PlaybackRateButton from '@/components/player/controls/PlaybackRateButton.vue';
import PlayPauseButton from '@/components/player/controls/PlayPauseButton.vue';
import RepeatButton from '@/components/player/controls/RepeatButton.vue';
import ShuffleButton from '@/components/player/controls/ShuffleButton.vue';
import TrackSeeker from '@/components/player/controls/TrackSeeker.vue';
import ButtonLink from '@/components/ui/ButtonLink.vue';
import LinkOrText from '@/components/ui/LinkOrText.vue';
import MarqueeScroll from '@/components/ui/MarqueeScroll.vue';

const {
  canPlayNext,
  canPlayPrevious,
  fastForwardTrack,
  isPlaying,
  playNextTrack,
  playPreviousTrack,
  rewindTrack,
} = useAudioPlayer();

const {
  currentTrack,
  isPodcastEpisode,
  isRadioStation,
  isTrack,
  toggleQueueList,
  toggleQueuePlayer,
} = useQueue();
</script>

<template>
  <section class="queueWrapper column" :class="$style.queuePlayerScreen">
    <!-- Atmospheric Background Image -->
    <div
      ref="backgroundImage"
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

    <!-- Top Header Navigation -->
    <header :class="$style.topHeader">
      <ButtonLink
        ref="closeQueueMenu"
        :class="$style.closeButton"
        :icon="ICONS.queueClose"
        iconWeight="bold"
        title="Close player"
        @click="toggleQueuePlayer"
      >
        Close
      </ButtonLink>

      <div :class="$style.headerCenter">
        <span :class="$style.headerContextLabel">PLAYING FROM</span>
        <p :class="$style.headerContextTitle">
          {{ ('album' in currentTrack && currentTrack.album) ? currentTrack.album : 'Queue' }}
        </p>
      </div>

      <div :class="$style.headerSpacer" />
    </header>

    <div :class="['column', $style.playerWrapper]">
      <div :class="$style.contentContainer">
        <!-- Album Artwork Section -->
        <div :class="$style.artworkContainer">
          <div :class="$style.imageWrapper">
            <div :class="$style.imageInner">
              <div :class="$style.preloadImageWrapper">
                <button
                  ref="rewindButton"
                  :class="[$style.rewindFastForwardButton, $style.rewindButton]"
                  type="button"
                  @click="doubleClick(rewindTrack)"
                >
                  <span class="visuallyHidden">
                    {{ REWIND_FAST_FORWARD_TITLES.rewind }}
                  </span>
                </button>
                <button
                  ref="fastForwardButton"
                  :class="[
                    $style.rewindFastForwardButton,
                    $style.fastForwardButton,
                  ]"
                  type="button"
                  @click="doubleClick(fastForwardTrack)"
                >
                  <span class="visuallyHidden">
                    {{ REWIND_FAST_FORWARD_TITLES.fastForward }}
                  </span>
                </button>

                <PreloadImage
                  :class="$style.preloadImage"
                  :image="currentTrack.image"
                />
              </div>
            </div>
          </div>
        </div>

        <!-- Player Controls Area -->
        <div :class="$style.controlsArea">
          <!-- 1. Track Info & Like Button Row -->
          <div :class="['spaceBetween', 'centerItems', $style.trackInfoRow]">
            <div :class="$style.trackInfoText">
              <MarqueeScroll inert>
                <h2 :class="$style.songTitle">
                  {{ currentTrack.name }}
                </h2>
              </MarqueeScroll>

              <div :class="$style.artistSubtitle">
                <template v-if="isTrack">
                  <MarqueeScroll
                    v-if="'artists' in currentTrack && currentTrack.artists.length"
                    ref="artistsMarqueeScroll"
                  >
                    <ArtistLinkList :artists="currentTrack.artists" />
                  </MarqueeScroll>

                  <MarqueeScroll
                    v-else-if="'album' in currentTrack && currentTrack.album"
                    ref="albumMarqueeScroll"
                  >
                    <LinkOrText
                      :isLink="!!currentTrack.albumId"
                      :text="currentTrack.album"
                      :to="{
                        name: ROUTE_NAMES.album,
                        params: {
                          [ROUTE_PARAM_KEYS.album.id]: currentTrack.albumId,
                        },
                      }"
                    />
                  </MarqueeScroll>
                </template>

                <template v-else-if="isPodcastEpisode">
                  <MarqueeScroll
                    v-if="'author' in currentTrack && currentTrack.author"
                    ref="authorMarqueeScroll"
                  >
                    <p>{{ currentTrack.author }}</p>
                  </MarqueeScroll>
                </template>
              </div>
            </div>

            <!-- Heart / Like Button (Next to track title) -->
            <FavouriteButton
              v-if="'favourite' in currentTrack"
              :id="currentTrack.id"
              :favourite="currentTrack.favourite"
              :type="currentTrack.type"
              :class="$style.favouriteButton"
            />
          </div>

          <!-- 2. Audio-Reactive Waves Timeline Scrubber -->
          <div :class="$style.timelineContainer">
            <TrackSeeker class="fullWidth" showTime />
          </div>

          <!-- 3. Harmonious 5-Button Hero Controls Row -->
          <div :class="['centerAll', $style.heroControlsRow]">
            <ShuffleButton
              v-if="!isRadioStation"
              :class="$style.secondaryBtn"
            />

            <ButtonLink
              ref="previousTrack"
              :class="$style.stepBtn"
              :disabled="!canPlayPrevious"
              :icon="ICONS.skipBack"
              iconWeight="fill"
              title="Previous track"
              @click="playPreviousTrack"
            >
              Previous track
            </ButtonLink>

            <PlayPauseButton :class="$style.heroPlayPause" />

            <ButtonLink
              ref="nextTrack"
              :class="$style.stepBtn"
              :disabled="!canPlayNext"
              :icon="ICONS.skipForward"
              iconWeight="fill"
              title="Next track"
              @click="playNextTrack"
            >
              Next track
            </ButtonLink>

            <RepeatButton
              v-if="!isRadioStation"
              :class="$style.secondaryBtn"
            />
          </div>

          <!-- 4. Bottom Utility Bar: Podcast Rate & Queue Button -->
          <div :class="['spaceBetween', 'centerItems', $style.bottomUtilityBar]">
            <div :class="$style.leftUtility">
              <PlaybackRateButton v-if="isPodcastEpisode" />
            </div>

            <!-- Sleek Queue Icon Button on the Bottom Right -->
            <ButtonLink
              ref="openQueueList"
              :class="$style.queueIconButton"
              :icon="ICONS.queue"
              iconWeight="bold"
              title="Open queue"
              @click="toggleQueueList"
            >
              Queue
            </ButtonLink>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>

<style module>
.queuePlayerScreen {
  background-color: #000000 !important;
  min-height: 100svh;
}

.topHeader {
  position: relative;
  z-index: 10;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 12px 20px;
}

.closeButton {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 40px;
  height: 40px;
  color: #ffffff !important;
  border-radius: 50%;
  transition: transform 0.15s ease, background-color 0.15s ease;

  &:hover {
    background-color: rgba(255, 255, 255, 0.1);
    transform: scale(1.1);
  }

  &:active {
    transform: scale(0.95);
  }
}

.headerCenter {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 2px;
  max-width: 60%;
  overflow: hidden;
}

.headerContextLabel {
  font-size: 0.65rem;
  font-weight: 800;
  letter-spacing: 0.1em;
  color: #a1a1aa;
}

.headerContextTitle {
  font-size: 0.82rem;
  font-weight: 700;
  color: #ffffff;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  margin: 0;
}

.headerSpacer {
  width: 40px;
}

.playerWrapper {
  flex: 1;
  width: 100%;
  max-width: 540px;
  margin: 0 auto;
  padding: 0 24px 20px;
}

.contentContainer {
  position: relative;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  height: 100%;
  gap: 20px;
}

.artworkContainer {
  position: relative;
  z-index: 1;
  width: 100%;
  max-width: 360px;
  margin: auto auto 10px;
}

.imageWrapper {
  display: flex;
  width: 100%;
  aspect-ratio: 1;
  margin: auto;
  border-radius: 12px;
  overflow: hidden;
  box-shadow: 0 20px 48px rgba(0, 0, 0, 0.9), 0 4px 16px rgba(0, 0, 0, 0.6);
}

.imageInner {
  position: relative;
  width: 100%;
  height: 100%;
  aspect-ratio: 1;
}

.preloadImageWrapper {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
}

.preloadImage {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.rewindFastForwardButton {
  position: absolute;
  top: 0;
  bottom: 0;
  z-index: 2;
  width: 50%;
  background: transparent;
  border: none;
}

.rewindButton {
  left: 0;
}

.fastForwardButton {
  right: 0;
}

.controlsArea {
  position: relative;
  z-index: 2;
  display: flex;
  flex-direction: column;
  gap: 16px;
  width: 100%;
}

/* Track title + Like button row */
.trackInfoRow {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
}

.trackInfoText {
  display: flex;
  flex: 1;
  flex-direction: column;
  gap: 4px;
  min-width: 0;
}

.songTitle {
  font-size: 1.35rem;
  font-weight: 800;
  letter-spacing: -0.02em;
  line-height: 1.2;
  color: #ffffff;
  margin: 0;
}

.artistSubtitle {
  font-size: 0.92rem;
  font-weight: 500;
  color: #a1a1aa;
  margin: 0;

  a, p {
    color: #a1a1aa !important;
    text-decoration: none;

    &:hover {
      color: #ffffff !important;
    }
  }
}

.favouriteButton {
  flex-shrink: 0;
}

/* Timeline scrubber */
.timelineContainer {
  width: 100%;
}

/* 5-Button Hero Controls Row */
.heroControlsRow {
  display: flex;
  align-items: center;
  justify-content: space-between;
  width: 100%;
  padding: 4px 6px;
}

.secondaryBtn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 40px;
  height: 40px;
  color: #a1a1aa !important;
  border-radius: 50% !important;
  transition: transform 0.15s ease, color 0.15s ease !important;

  &:hover {
    color: #ffffff !important;
    transform: scale(1.15);
  }

  &:active {
    transform: scale(0.9);
  }
}

.stepBtn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 44px;
  height: 44px;
  color: #ffffff !important;
  border-radius: 50% !important;
  transition: transform 0.15s ease !important;

  &:hover:not(:disabled) {
    transform: scale(1.15);
  }

  &:active:not(:disabled) {
    transform: scale(0.9);
  }

  &:disabled {
    opacity: 0.35;
  }
}

.heroPlayPause {
  transform: scale(1.15);
}

/* Bottom utility bar */
.bottomUtilityBar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding-top: 4px;
}

.leftUtility {
  display: flex;
  align-items: center;
}

.queueIconButton {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 40px;
  height: 40px;
  color: #a1a1aa !important;
  border-radius: 50% !important;
  transition: transform 0.15s ease, color 0.15s ease, background-color 0.15s ease !important;

  &:hover {
    color: #22c55e !important;
    background-color: rgba(255, 255, 255, 0.08) !important;
    transform: scale(1.12);
  }

  &:active {
    transform: scale(0.92);
  }
}

/* Atmospheric blurred background */
.backgroundImage {
  --queue-player-animation-play-state: paused;

  position: fixed;
  inset: 0;
  z-index: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
  opacity: 0.22;
}

.backgroundImageActive {
  --queue-player-animation-play-state: running;
}

.backgroundPreloadImage {
  width: 100%;
  height: 100%;
  aspect-ratio: unset;
  filter: blur(28px);
  transform-origin: center;
  animation: background-drift 12s ease-in-out infinite;
  animation-play-state: var(--queue-player-animation-play-state);

  @media (--tablet-up) {
    filter: blur(60px);
  }
}

@keyframes background-drift {
  0%,
  100% {
    transform: scale(1.3) translate(-8%, 0);
  }

  50% {
    transform: scale(1.3) translate(8%, 0);
  }
}
</style>
