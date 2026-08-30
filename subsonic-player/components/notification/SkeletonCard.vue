<script setup lang="ts">
withDefaults(
  defineProps<{
    isCircle?: boolean;
  }>(),
  {
    isCircle: false,
  },
);
</script>

<template>
  <div :class="$style.skeletonCard">
    <!-- Media Image Box with Wave Shimmer -->
    <div
      :class="[
        $style.imageBox,
        {
          [$style.circleImage]: isCircle,
        },
      ]"
    >
      <div :class="$style.shimmerWave" />
    </div>

    <!-- Info Lines -->
    <div :class="$style.infoWrapper">
      <div :class="[$style.line, $style.titleLine]">
        <div :class="$style.shimmerWave" />
      </div>
      <div :class="[$style.line, $style.subtitleLine]">
        <div :class="$style.shimmerWave" />
      </div>
    </div>
  </div>
</template>

<style module>
.skeletonCard {
  position: relative;
  display: flex;
  flex-direction: column;
  gap: 12px;
  width: 100%;
  padding: 12px;
  background-color: #0c0d12;
  border: 2px solid rgba(255, 255, 255, 0.08);
  border-radius: 16px;
  box-shadow: 4px 4px 0px #000000;
  overflow: hidden;
}

.imageBox {
  position: relative;
  width: 100%;
  aspect-ratio: 1 / 1;
  background-color: #161722;
  border-radius: 12px;
  overflow: hidden;
}

.circleImage {
  border-radius: 50% !important;
}

.infoWrapper {
  display: flex;
  flex-direction: column;
  gap: 8px;
  width: 100%;
  padding: 2px 4px 4px;
}

.line {
  position: relative;
  height: 12px;
  background-color: #161722;
  border-radius: 6px;
  overflow: hidden;
}

.titleLine {
  width: 75%;
  height: 14px;
}

.subtitleLine {
  width: 50%;
  height: 11px;
  opacity: 0.7;
}

/* Signature Green Wave Shimmer */
.shimmerWave {
  position: absolute;
  inset: 0;
  background: linear-gradient(
    90deg,
    transparent 0%,
    rgba(34, 197, 94, 0.12) 40%,
    rgba(74, 222, 128, 0.22) 50%,
    rgba(34, 197, 94, 0.12) 60%,
    transparent 100%
  );
  transform: translateX(-100%);
  animation: waveSweep 1.8s infinite cubic-bezier(0.4, 0, 0.2, 1);
}

@keyframes waveSweep {
  0% {
    transform: translateX(-100%);
  }
  60%, 100% {
    transform: translateX(100%);
  }
}
</style>
