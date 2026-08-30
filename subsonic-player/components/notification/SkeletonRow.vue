<script setup lang="ts">
withDefaults(
  defineProps<{
    hasCover?: boolean;
  }>(),
  {
    hasCover: true,
  },
);
</script>

<template>
  <div :class="$style.skeletonRow">
    <!-- Track Number / Play placeholder -->
    <div :class="$style.numberCol">
      <div :class="$style.numberPill">
        <div :class="$style.shimmerWave" />
      </div>
    </div>

    <!-- Cover Image (Optional) -->
    <div v-if="hasCover" :class="$style.coverCol">
      <div :class="$style.coverBox">
        <div :class="$style.shimmerWave" />
      </div>
    </div>

    <!-- Title & Artist -->
    <div :class="$style.titleCol">
      <div :class="[$style.line, $style.titleLine]">
        <div :class="$style.shimmerWave" />
      </div>
      <div :class="[$style.line, $style.artistLine]">
        <div :class="$style.shimmerWave" />
      </div>
    </div>

    <!-- Album / Info (Desktop) -->
    <div :class="[$style.albumCol, 'hideOnMobile']">
      <div :class="[$style.line, $style.albumLine]">
        <div :class="$style.shimmerWave" />
      </div>
    </div>

    <!-- Duration -->
    <div :class="$style.durationCol">
      <div :class="$style.durationPill">
        <div :class="$style.shimmerWave" />
      </div>
    </div>
  </div>
</template>

<style module>
.skeletonRow {
  position: relative;
  display: flex;
  align-items: center;
  gap: 12px;
  width: 100%;
  padding: 10px 14px;
  background-color: #0c0d12;
  border: 1px solid rgba(255, 255, 255, 0.06);
  border-radius: 12px;
  overflow: hidden;
  margin-bottom: 6px;
}

.numberCol {
  width: 24px;
  flex-shrink: 0;
}

.numberPill {
  position: relative;
  width: 16px;
  height: 12px;
  background-color: #161722;
  border-radius: 4px;
  overflow: hidden;
}

.coverCol {
  width: 42px;
  height: 42px;
  flex-shrink: 0;
}

.coverBox {
  position: relative;
  width: 100%;
  height: 100%;
  background-color: #161722;
  border-radius: 8px;
  overflow: hidden;
}

.titleCol {
  display: flex;
  flex-direction: column;
  gap: 6px;
  flex: 1;
  min-width: 0;
}

.albumCol {
  flex: 0.8;
  min-width: 0;
}

.durationCol {
  width: 45px;
  display: flex;
  justify-content: flex-end;
  flex-shrink: 0;
}

.durationPill {
  position: relative;
  width: 36px;
  height: 12px;
  background-color: #161722;
  border-radius: 4px;
  overflow: hidden;
}

.line {
  position: relative;
  height: 12px;
  background-color: #161722;
  border-radius: 6px;
  overflow: hidden;
}

.titleLine {
  width: 60%;
  height: 13px;
}

.artistLine {
  width: 35%;
  height: 10px;
  opacity: 0.7;
}

.albumLine {
  width: 70%;
  height: 11px;
  opacity: 0.6;
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
