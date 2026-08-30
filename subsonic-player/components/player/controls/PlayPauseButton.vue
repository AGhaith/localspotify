<script setup lang="ts">
import SpinningLoader from '@/components/notification/SpinningLoader.vue';
import ButtonLink from '@/components/ui/ButtonLink.vue';

const { isBuffering, isPlaying, togglePlay } = useAudioPlayer();

const buttonProps = computed(() => ({
  icon: isPlaying.value ? ICONS.pause : ICONS.play,
  text: `${isPlaying.value ? 'Pause' : 'Play'} current track`,
}));
</script>

<template>
  <ButtonLink
    v-if="!isBuffering"
    :class="[
      'centerAll',
      $style.playPauseBtn,
      {
        [$style.isPlaying]: isPlaying,
      },
    ]"
    :icon="buttonProps.icon"
    iconWeight="fill"
    :title="buttonProps.text"
    @click="togglePlay"
  >
    <template #icon>
      <div :class="$style.iconWrapper">
        <PhPlay
          weight="fill"
          :class="[
            $style.icon,
            $style.playIcon,
            {
              [$style.iconVisible]: !isPlaying,
              [$style.iconHidden]: isPlaying,
            },
          ]"
        />
        <PhPause
          weight="fill"
          :class="[
            $style.icon,
            $style.pauseIcon,
            {
              [$style.iconVisible]: isPlaying,
              [$style.iconHidden]: !isPlaying,
            },
          ]"
        />
      </div>
    </template>
    {{ buttonProps.text }}
  </ButtonLink>

  <div v-else :class="['centerAll', $style.loaderWrapper]">
    <SpinningLoader :class="$style.spinningLoader" />
  </div>
</template>

<style module>
.playPauseBtn {
  position: relative;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 52px !important;
  height: 52px !important;
  min-width: 52px !important;
  min-height: 52px !important;
  max-width: 52px !important;
  max-height: 52px !important;
  padding: 0 !important;
  color: #000000 !important;
  cursor: pointer;
  background-color: #ffffff !important;
  border: none !important;
  border-radius: 50% !important;
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.7), 0 0 16px rgba(255, 255, 255, 0.15) !important;
  transition: transform 0.15s cubic-bezier(0.34, 1.56, 0.64, 1),
    box-shadow 0.15s ease,
    background-color 0.15s ease !important;
  overflow: hidden;
  user-select: none;

  &:hover {
    background-color: #f4f4f5 !important;
    box-shadow: 0 6px 20px rgba(0, 0, 0, 0.8), 0 0 22px rgba(255, 255, 255, 0.3) !important;
    transform: scale(1.06);
  }

  &:active {
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.9) !important;
    transform: scale(0.94);
  }
}

.iconWrapper {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 24px;
  height: 24px;
}

.icon {
  position: absolute;
  top: 50%;
  left: 50%;
  width: 24px !important;
  height: 24px !important;
  color: #000000 !important;
  transition: opacity 0.22s cubic-bezier(0.4, 0, 0.2, 1),
    transform 0.22s cubic-bezier(0.4, 0, 0.2, 1);
  pointer-events: none;
}

.playIcon {
  transform: translate(calc(-50% + 1.5px), -50%) scale(1) rotate(0deg);
}

.pauseIcon {
  transform: translate(-50%, -50%) scale(1) rotate(0deg);
}

.playIcon.iconHidden {
  opacity: 0;
  transform: translate(calc(-50% + 1.5px), -50%) scale(0.5) rotate(45deg);
}

.pauseIcon.iconHidden {
  opacity: 0;
  transform: translate(-50%, -50%) scale(0.5) rotate(-45deg);
}

.iconVisible {
  opacity: 1;
}

.loaderWrapper {
  width: 52px;
  height: 52px;
}

.spinningLoader {
  padding: 0;
}
</style>
