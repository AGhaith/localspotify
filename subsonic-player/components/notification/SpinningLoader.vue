<script setup lang="ts">
withDefaults(
  defineProps<{
    size?: number;
  }>(),
  {
    size: ICON_SIZE.medium,
  },
);
</script>

<template>
  <span
    :class="['centerItems', $style.waveMiniLoader]"
    :style="{ '--loader-size': `${size}px` }"
    role="status"
    aria-label="Loading..."
  >
    <span :class="$style.miniWave">
      <span :class="[$style.miniBar, $style.mb1]" />
      <span :class="[$style.miniBar, $style.mb2]" />
      <span :class="[$style.miniBar, $style.mb3]" />
      <span :class="[$style.miniBar, $style.mb4]" />
    </span>
    <span class="visuallyHidden">Loading...</span>
  </span>
</template>

<style module>
.waveMiniLoader {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  width: var(--loader-size);
  height: var(--loader-size);
}

.miniWave {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 2.5px;
  height: 100%;
  max-height: 18px;
}

.miniBar {
  width: 2.5px;
  border-radius: 2px;
  background-color: #22c55e;
  box-shadow: 0 0 6px rgba(34, 197, 94, 0.6);
  min-height: 3px;
  will-change: height, opacity;
}

.mb1 {
  height: 6px;
  animation: miniBarBounce 0.8s ease-in-out infinite alternate;
}

.mb2 {
  height: 14px;
  animation: miniBarBounce 0.65s ease-in-out infinite alternate 0.15s;
}

.mb3 {
  height: 10px;
  animation: miniBarBounce 0.75s ease-in-out infinite alternate 0.3s;
}

.mb4 {
  height: 4px;
  animation: miniBarBounce 0.6s ease-in-out infinite alternate 0.1s;
}

@keyframes miniBarBounce {
  0% {
    height: 3px;
    opacity: 0.35;
  }
  100% {
    height: 16px;
    opacity: 1;
    background-color: #4ade80;
  }
}
</style>
