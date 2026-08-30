<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref, useTemplateRef, watch } from 'vue';

const props = withDefaults(
  defineProps<{
    disabled?: boolean;
    height?: number;
    hideThumb?: boolean;
    minimized?: boolean;
    noWaves?: boolean;
    showTime?: boolean;
  }>(),
  {
    disabled: false,
    height: undefined,
    hideThumb: false,
    minimized: false,
    noWaves: false,
    showTime: false,
  },
);

const {
  bufferedDuration,
  currentTime,
  fastForwardTrack,
  getFrequencyData,
  isPlaying,
  rewindTrack,
  seekTo,
} = useAudioPlayer();
const { currentTrack } = useQueue();

const containerRef = useTemplateRef<HTMLElement>('containerRef');

const isSeeking = ref(false);
const isHovering = ref(false);
const hoverProgress = ref(0);
const pendingTime = ref(0);
const abortController = ref<AbortController | null>(null);

// High-density line count for rich, connected sound waves
const barCount = computed(() => 72);
const barHeights = ref<number[]>([]);

// High-resolution resting harmonic acoustic wave curve
function getRestingProfile(count: number): number[] {
  const result: number[] = [];
  for (let i = 0; i < count; i++) {
    const norm = i / (count - 1 || 1);
    const wave =
      8 +
      Math.sin(norm * Math.PI) * 46 +
      Math.sin(norm * Math.PI * 2.5) * 16 +
      Math.sin(norm * Math.PI * 5) * 8;
    result.push(Math.max(8, Math.min(90, wave)));
  }
  return result;
}

barHeights.value = getRestingProfile(barCount.value);

let animationFrameId: number | null = null;
const frequencyBuffer = new Uint8Array(32);

function runWaveformLoop() {
  if (props.noWaves || props.minimized) {
    return;
  }

  if (animationFrameId) {
    cancelAnimationFrame(animationFrameId);
    animationFrameId = null;
  }

  function tick() {
    const count = barCount.value;

    if (isPlaying.value) {
      getFrequencyData(frequencyBuffer);

      // Fractional frequency interpolation for high-resolution density
      const rawTargets: number[] = [];
      for (let i = 0; i < count; i++) {
        const binPos = (i / count) * 31;
        const binLow = Math.floor(binPos);
        const binHigh = Math.min(31, Math.ceil(binPos));
        const binFract = binPos - binLow;
        const freq =
          (frequencyBuffer[binLow] || 0) * (1 - binFract) +
          (frequencyBuffer[binHigh] || 0) * binFract;

        const norm = i / (count - 1 || 1);
        const contour =
          Math.sin(norm * Math.PI) * 0.45 + (1 - norm) * 0.35 + 0.25;
        const baseHeight = 8;
        const maxBoost = 85;
        const dynamicBoost = (freq / 255) * maxBoost * contour;

        rawTargets.push(Math.min(96, Math.max(6, baseHeight + dynamicBoost)));
      }

      // 5-point Gaussian spatial smoothing for a seamless fluid wave ribbon
      const smoothedTargets: number[] = [];
      for (let i = 0; i < count; i++) {
        const p2 = rawTargets[Math.max(0, i - 2)];
        const p1 = rawTargets[Math.max(0, i - 1)];
        const curr = rawTargets[i];
        const n1 = rawTargets[Math.min(count - 1, i + 1)];
        const n2 = rawTargets[Math.min(count - 1, i + 2)];
        smoothedTargets.push(
          p2 * 0.08 + p1 * 0.24 + curr * 0.36 + n1 * 0.24 + n2 * 0.08,
        );
      }

      // Spring physics interpolation
      const updatedHeights: number[] = [];
      for (let i = 0; i < count; i++) {
        const current = barHeights.value[i] ?? smoothedTargets[i];
        const target = smoothedTargets[i];
        updatedHeights.push(current + (target - current) * 0.34);
      }

      barHeights.value = updatedHeights;
      animationFrameId = requestAnimationFrame(tick);
    } else {
      const resting = getRestingProfile(count);
      let isAnimating = false;
      const updatedHeights: number[] = [];

      for (let i = 0; i < count; i++) {
        const current = barHeights.value[i] ?? resting[i];
        const diff = resting[i] - current;
        if (Math.abs(diff) > 0.4) {
          isAnimating = true;
        }
        updatedHeights.push(current + diff * 0.18);
      }

      barHeights.value = updatedHeights;

      if (isAnimating) {
        animationFrameId = requestAnimationFrame(tick);
      } else {
        animationFrameId = null;
      }
    }
  }

  animationFrameId = requestAnimationFrame(tick);
}

watch(isPlaying, () => {
  if (!props.noWaves && !props.minimized) {
    runWaveformLoop();
  }
});

const progressPercent = computed(() => {
  const duration = currentTrack.value?.duration || 0;
  if (duration <= 0) return 0;
  const time = isSeeking.value ? pendingTime.value : currentTime.value;
  return Math.min(100, Math.max(0, (time / duration) * 100));
});

const bufferPercent = computed(() => {
  const duration = currentTrack.value?.duration || 0;
  if (duration <= 0 || !bufferedDuration.value) return 0;
  return Math.min(100, Math.max(0, (bufferedDuration.value / duration) * 100));
});

const activeSeekTimeSeconds = computed(() => {
  if (isSeeking.value) {
    return pendingTime.value;
  }
  const duration = currentTrack.value?.duration || 0;
  return (hoverProgress.value / 100) * duration;
});

const tooltipPositionPercent = computed(() => {
  return isSeeking.value ? progressPercent.value : hoverProgress.value;
});

function calculatePosition(event: MouseEvent | TouchEvent): number {
  if (!containerRef.value) return 0;
  const pointer = getPointerEventPosition(event);
  if (!pointer) return 0;

  const rect = containerRef.value.getBoundingClientRect();
  const rawX = pointer.pageX - rect.left;
  const clampedX = Math.max(0, Math.min(rawX, rect.width));
  return rect.width > 0 ? (clampedX / rect.width) * 100 : 0;
}

function onPointerMove(event: MouseEvent | TouchEvent) {
  const percent = calculatePosition(event);
  hoverProgress.value = percent;

  if (isSeeking.value) {
    const duration = currentTrack.value?.duration || 0;
    pendingTime.value = Math.round((percent / 100) * duration);
  }
}

function onPointerUp() {
  if (isSeeking.value) {
    seekTo(pendingTime.value);
  }

  abortController.value?.abort();
  abortController.value = null;
  isSeeking.value = false;
}

function onPointerDown(event: MouseEvent | TouchEvent) {
  if (props.disabled) return;

  const percent = calculatePosition(event);
  hoverProgress.value = percent;
  const duration = currentTrack.value?.duration || 0;
  pendingTime.value = Math.round((percent / 100) * duration);
  isSeeking.value = true;

  abortController.value = new AbortController();
  const { signal } = abortController.value;

  document.addEventListener('mousemove', onPointerMove, { signal });
  document.addEventListener('mouseup', onPointerUp, { signal });
  document.addEventListener('touchmove', onPointerMove, { passive: true, signal });
  document.addEventListener('touchend', onPointerUp, { passive: true, signal });
}

function onMouseEnter() {
  isHovering.value = true;
}

function onMouseLeave() {
  isHovering.value = false;
}

onMounted(() => {
  if (isPlaying.value && !props.noWaves && !props.minimized) {
    runWaveformLoop();
  }
});

onUnmounted(() => {
  if (animationFrameId) {
    cancelAnimationFrame(animationFrameId);
  }
  abortController.value?.abort();
});
</script>

<template>
  <div
    :class="[
      $style.timelineContainer,
      {
        [$style.minimized]: minimized,
        [$style.noWaves]: noWaves,
        [$style.isSeeking]: isSeeking,
        [$style.isHovering]: isHovering,
        [$style.disabled]: disabled,
      },
    ]"
    role="slider"
    tabindex="0"
    :aria-label="`Seek ${currentTrack?.name || 'track'}`"
    :aria-valuemin="0"
    :aria-valuemax="currentTrack?.duration || 0"
    :aria-valuenow="currentTime"
    :aria-valuetext="`${secondsToHHMMSS(currentTime)} of ${currentTrack?.formattedDuration || '00:00'}`"
    @keydown.arrow-left.prevent="rewindTrack"
    @keydown.arrow-right.prevent="fastForwardTrack"
  >
    <div
      ref="containerRef"
      :class="$style.interactiveArea"
      @mousedown.stop.prevent="onPointerDown"
      @touchstart.stop.passive="onPointerDown"
      @mouseenter="onMouseEnter"
      @mouseleave="onMouseLeave"
      @mousemove="onPointerMove"
    >
      <!-- Sound Wave Rays (Only in Extended View) -->
      <div v-if="!noWaves && !minimized" :class="$style.waveRaysContainer">
        <div
          v-for="(heightPercent, index) in barHeights"
          :key="index"
          :class="[
            $style.waveRay,
            {
              [$style.playedRay]: (index / (barCount - 1 || 1)) * 100 <= progressPercent,
              [$style.bufferedRay]:
                (index / (barCount - 1 || 1)) * 100 > progressPercent &&
                (index / (barCount - 1 || 1)) * 100 <= bufferPercent,
            },
          ]"
          :style="{
            height: `${heightPercent}%`,
          }"
        />
      </div>

      <!-- Solid continuous baseline timeline rail -->
      <div :class="$style.timelineRail">
        <div
          v-if="bufferPercent > 0"
          :class="$style.bufferFill"
          :style="{ width: `${bufferPercent}%` }"
        />
        <div
          :class="$style.progressFill"
          :style="{ width: `${progressPercent}%` }"
        />

        <!-- Tactile Playhead Circle / Scrubber Thumb (Precisely centered on rail) -->
        <div
          v-if="!hideThumb"
          :class="[
            $style.thumb,
            {
              [$style.thumbActive]: isSeeking || isHovering,
            },
          ]"
          :style="{
            left: `${progressPercent}%`,
          }"
        />
      </div>

      <!-- Floating Seek Timestamp Bubble: 00:00 / 00:00 format -->
      <transition name="pop-fade">
        <div
          v-if="isHovering || isSeeking"
          :class="$style.tooltip"
          :style="{
            left: `${tooltipPositionPercent}%`,
          }"
        >
          <span :class="$style.tooltipCurrentTime">
            {{ secondsToHHMMSS(activeSeekTimeSeconds) }}
          </span>
          <span :class="$style.tooltipDivider">/</span>
          <span :class="$style.tooltipTotalTime">
            {{ currentTrack?.formattedDuration || '00:00' }}
          </span>
        </div>
      </transition>
    </div>

    <!-- Compact Timestamps (for desktop / extended views) -->
    <div v-if="showTime && !minimized" :class="$style.timeRow">
      <span :class="$style.timeText">{{ secondsToHHMMSS(currentTime) }}</span>
      <span :class="$style.timeText">{{ currentTrack?.formattedDuration || '00:00' }}</span>
    </div>
  </div>
</template>

<style module>
.timelineContainer {
  position: relative;
  width: 100%;
  padding: 0;
  outline: none;
  user-select: none;
}

.minimized {
  padding: 0;
}

.disabled {
  pointer-events: none;
  opacity: 0.5;
}

/* Expanded touch/mouse interactive area with smooth hit target */
.interactiveArea {
  position: relative;
  display: flex;
  flex-direction: column;
  justify-content: flex-end;
  width: 100%;
  height: 32px;
  cursor: pointer;

  .minimized & {
    height: 18px;
    justify-content: flex-end;
    padding-bottom: 2px;
  }

  .noWaves:not(.minimized) & {
    height: 18px;
    justify-content: center;
  }
}

.waveRaysContainer {
  position: relative;
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  width: 100%;
  height: 24px;
  gap: 1.5px;
  padding-bottom: 2px;
  overflow: hidden;
}

.waveRay {
  flex: 1;
  min-width: 1.5px;
  max-width: 3.5px;
  height: 10%;
  background-color: rgba(255, 255, 255, 0.14);
  border-radius: 2px 2px 0 0;
  transform-origin: bottom;
  transition: height 0.04s ease-out, background 0.12s ease, filter 0.12s ease;
}

.bufferedRay {
  background: rgba(255, 255, 255, 0.38);
}

.playedRay {
  background: linear-gradient(180deg, #4ade80 0%, #22c55e 100%);
  filter: drop-shadow(0 -1px 2px rgba(34, 197, 94, 0.5));
}

/* Baseline timeline rail */
.timelineRail {
  position: relative;
  width: 100%;
  height: 3.5px;
  background-color: rgba(255, 255, 255, 0.2);
  border-radius: 9999px;
  transition: height 0.18s cubic-bezier(0.2, 0.8, 0.2, 1), background-color 0.18s ease;

  .isHovering &,
  .isSeeking & {
    height: 5.5px;
    background-color: rgba(255, 255, 255, 0.35);
  }

  .minimized & {
    height: 3px;
    border-radius: 0;
  }

  .minimized.isHovering &,
  .minimized.isSeeking & {
    height: 5px;
  }
}

.progressFill {
  position: absolute;
  top: 0;
  left: 0;
  height: 100%;
  background-color: #22c55e;
  border-radius: 9999px;
  box-shadow: 0 0 6px rgba(34, 197, 94, 0.6);
  transition: box-shadow 0.18s ease;

  .isHovering &,
  .isSeeking & {
    box-shadow: 0 0 12px rgba(34, 197, 94, 0.95);
  }

  .minimized & {
    border-radius: 0;
  }
}

.bufferFill {
  position: absolute;
  top: 0;
  left: 0;
  height: 100%;
  background-color: rgba(255, 255, 255, 0.45);
  border-radius: 9999px;

  .minimized & {
    border-radius: 0;
  }
}

/* Scrubber Circle (Playhead Thumb) - Precisely Centered on Rail */
.thumb {
  position: absolute;
  top: 50%;
  z-index: 20;
  width: 12px;
  height: 12px;
  pointer-events: none;
  background-color: #ffffff;
  border: 2px solid #000000;
  border-radius: 50%;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.9), 0 0 6px rgba(255, 255, 255, 0.6);
  transform: translate(-50%, -50%) scale(1);
  transition: transform 0.16s cubic-bezier(0.34, 1.56, 0.64, 1), box-shadow 0.16s ease, background-color 0.16s ease, width 0.16s ease, height 0.16s ease;

  .minimized & {
    width: 10px;
    height: 10px;
    background-color: #ffffff;
    border: 1.5px solid #000000;
    transform: translate(-50%, -50%) scale(1);
  }
}

.thumbActive {
  width: 16px !important;
  height: 16px !important;
  background-color: #22c55e !important;
  border: 2.5px solid #ffffff !important;
  box-shadow: 0 0 16px rgba(34, 197, 94, 1), 0 2px 8px rgba(0, 0, 0, 0.95) !important;
  transform: translate(-50%, -50%) scale(1.15) !important;

  .minimized & {
    width: 14px !important;
    height: 14px !important;
    transform: translate(-50%, -50%) scale(1.2) !important;
  }
}

/* Floating Seek Timestamp Pill: 00:00 / 00:00 */
.tooltip {
  position: absolute;
  bottom: calc(100% + 10px);
  z-index: 30;
  display: flex;
  align-items: center;
  gap: 5px;
  padding: 4px 10px;
  font-family: var(--font-family);
  font-size: 0.78rem;
  font-weight: 700;
  color: #ffffff;
  pointer-events: none;
  white-space: nowrap;
  background-color: #0c0c10;
  border: 1px solid rgba(255, 255, 255, 0.18);
  border-radius: 9999px;
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.85), 0 2px 6px rgba(0, 0, 0, 0.6);
  backdrop-filter: blur(16px);
  transform: translateX(-50%);
  animation: tooltipPop 0.18s cubic-bezier(0.34, 1.56, 0.64, 1) forwards;

  /* Arrow pointer */
  &::after {
    content: '';
    position: absolute;
    top: 100%;
    left: 50%;
    transform: translateX(-50%);
    border-width: 5px 5px 0 5px;
    border-style: solid;
    border-color: #0c0c10 transparent transparent transparent;
  }
}

@keyframes tooltipPop {
  0% {
    opacity: 0;
    transform: translateX(-50%) translateY(4px) scale(0.92);
  }
  100% {
    opacity: 1;
    transform: translateX(-50%) translateY(0) scale(1);
  }
}

.tooltipCurrentTime {
  color: #22c55e;
  font-variant-numeric: tabular-nums;
  font-weight: 800;
}

.tooltipDivider {
  color: #71717a;
  font-weight: 500;
}

.tooltipTotalTime {
  color: #a1a1aa;
  font-variant-numeric: tabular-nums;
  font-weight: 600;
}

.timeRow {
  display: flex;
  justify-content: space-between;
  margin-top: 4px;
  font-size: 0.75rem;
  font-weight: 600;
  color: #a1a1aa;
}

.timeText {
  font-variant-numeric: tabular-nums;
}
</style>
