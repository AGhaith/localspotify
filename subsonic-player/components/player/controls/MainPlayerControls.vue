<script setup lang="ts">
import PlayPauseButton from '@/components/player/controls/PlayPauseButton.vue';
import ButtonLink from '@/components/ui/ButtonLink.vue';

const {
  canPlayNext,
  canPlayPrevious,
  fastForwardTrack,
  playNextTrack,
  playPreviousTrack,
  rewindTrack,
} = useAudioPlayer();
const { isPodcastEpisode } = useQueue();
</script>

<template>
  <div :class="['centerAll', $style.mainControls]">
    <ButtonLink
      ref="previousTrack"
      :class="$style.stepButton"
      :disabled="!canPlayPrevious"
      :icon="ICONS.skipBack"
      iconWeight="fill"
      title="Previous track"
      @click="playPreviousTrack"
    >
      Previous track
    </ButtonLink>

    <ButtonLink
      v-if="isPodcastEpisode"
      ref="rewind"
      :class="$style.stepButton"
      :icon="ICONS.rewind"
      :title="REWIND_FAST_FORWARD_TITLES.rewind"
      @click="rewindTrack"
    >
      {{ REWIND_FAST_FORWARD_TITLES.rewind }}
    </ButtonLink>

    <PlayPauseButton />

    <ButtonLink
      v-if="isPodcastEpisode"
      ref="fastForward"
      :class="$style.stepButton"
      :icon="ICONS.fastForward"
      :title="REWIND_FAST_FORWARD_TITLES.fastForward"
      @click="fastForwardTrack"
    >
      {{ REWIND_FAST_FORWARD_TITLES.fastForward }}
    </ButtonLink>

    <ButtonLink
      ref="nextTrack"
      :class="$style.stepButton"
      :disabled="!canPlayNext"
      :icon="ICONS.skipForward"
      iconWeight="fill"
      title="Next track"
      @click="playNextTrack"
    >
      Next track
    </ButtonLink>
  </div>
</template>

<style module>
.mainControls {
  gap: var(--space-12, 12px);
}

.stepButton {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 36px;
  height: 36px;
  min-width: 36px;
  min-height: 36px;
  padding: 0 !important;
  color: var(--body-font-color, #ffffff) !important;
  border-radius: 9999px !important;
  transition: transform 0.12s ease, opacity 0.12s ease !important;

  &:hover:not(:disabled) {
    background-color: rgba(255, 255, 255, 0.1) !important;
    transform: scale(1.1);
  }

  &:active:not(:disabled) {
    transform: scale(0.95);
  }

  &:disabled {
    opacity: 0.35;
  }

  svg {
    width: 20px !important;
    height: 20px !important;
  }
}
</style>
