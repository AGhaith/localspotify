<script setup lang="ts">
import FavouriteButton from '@/components/favourite/FavouriteButton.vue';
import LyricsButton from '@/components/player/controls/LyricsButton.vue';
import MediaInformation from '@/components/player/controls/MediaInformation.vue';
import PlaybackRateButton from '@/components/player/controls/PlaybackRateButton.vue';
import QueueButton from '@/components/player/controls/QueueButton.vue';
import VolumeControl from '@/components/player/controls/VolumeControl.vue';

const { currentTrack, isPodcastEpisode, isRadioStation, isTrack } = useQueue();
</script>

<template>
  <div :class="['centerItems', $style.playerOptions]">
    <VolumeControl />

    <PlaybackRateButton v-if="isPodcastEpisode" />

    <LyricsButton v-if="isTrack" />

    <MediaInformation v-if="!isRadioStation" />

    <FavouriteButton
      v-if="'favourite' in currentTrack"
      :id="currentTrack.id"
      :favourite="currentTrack.favourite"
      :type="currentTrack.type"
    />

    <QueueButton />
  </div>
</template>

<style module>
.playerOptions {
  gap: var(--space-12, 12px);
  justify-content: flex-end;
}
</style>
