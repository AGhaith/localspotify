<script setup lang="ts">
import LyricsView from '@/components/player/lyrics/LyricsView.vue';
import MusicPlayer from '@/components/player/MusicPlayer.vue';
import QueueList from '@/components/player/queue/QueueList.vue';
import QueuePlayer from '@/components/player/queue/QueuePlayer.vue';

const { hasQueueTracks, isQueueListOpened, isQueuePlayerOpened } = useQueue();
const { isLyricsOpened } = useLyrics();
</script>

<template>
  <Transition name="slide-up-down">
    <MusicPlayer v-if="hasQueueTracks && !isQueuePlayerOpened" />
  </Transition>

  <Transition name="slide-up-down">
    <QueuePlayer v-if="isQueuePlayerOpened" />
  </Transition>

  <Transition name="slide-up-down">
    <QueueList v-show="isQueueListOpened" />
  </Transition>

  <Transition name="slide-up-down">
    <LyricsView v-show="isLyricsOpened" />
  </Transition>
</template>
