<script setup lang="ts">
import ButtonLink from '@/components/ui/ButtonLink.vue';

const { isLyricsOpened, toggleLyrics } = useLyrics();
</script>

<template>
  <ButtonLink
    :class="[
      $style.lyricsButton,
      {
        [$style.active]: isLyricsOpened,
      },
    ]"
    :icon="ICONS.lyrics"
    title="Lyrics"
    @click="toggleLyrics"
  >
    Lyrics
  </ButtonLink>
</template>

<style module>
.lyricsButton {
  transition: color 0.15s ease, transform 0.12s ease;
}

.active {
  color: #22c55e !important;
}
</style>
