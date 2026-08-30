<template>
  <div :class="$style.mainLoaderWrapper" role="status" aria-label="Loading content">
    <!-- Ambient Green Pulse Backdrop -->
    <div :class="$style.loaderGlow" aria-hidden="true" />

    <!-- Signature Audio Wave Pill -->
    <div :class="$style.wavePill" aria-hidden="true">
      <span
        v-for="bar in 11"
        :key="bar"
        :class="[$style.waveBar, $style[`bar${bar}`]]"
      />
    </div>

    <output class="visuallyHidden">Loading content...</output>
  </div>
</template>

<style module>
.mainLoaderWrapper {
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 32px 20px;
}

.loaderGlow {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  width: 140px;
  height: 90px;
  background: radial-gradient(ellipse, rgba(34, 197, 94, 0.35) 0%, rgba(34, 197, 94, 0) 70%);
  filter: blur(28px);
  pointer-events: none;
  animation: glowPulse 2s ease-in-out infinite alternate;
}

@keyframes glowPulse {
  0% { transform: translate(-50%, -50%) scale(0.85); opacity: 0.5; }
  100% { transform: translate(-50%, -50%) scale(1.25); opacity: 1; }
}

.wavePill {
  position: relative;
  z-index: 2;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 5px;
  height: 48px;
  padding: 0 20px;
  background-color: #0c0d12;
  border: 2px solid #22c55e;
  border-radius: 9999px;
  box-shadow: 4px 4px 0px #000000, 0 0 20px rgba(34, 197, 94, 0.3);
}

.waveBar {
  width: 4px;
  border-radius: 9999px;
  background-color: #22c55e;
  box-shadow: 0 0 8px rgba(34, 197, 94, 0.7);
  min-height: 4px;
  transform-origin: center;
  will-change: height, opacity;
}

.bar1 { height: 10px; animation: barWave 1.1s ease-in-out infinite alternate; }
.bar2 { height: 18px; animation: barWave 0.85s ease-in-out infinite alternate 0.1s; }
.bar3 { height: 26px; animation: barWave 1.25s ease-in-out infinite alternate 0.22s; }
.bar4 { height: 16px; animation: barWave 0.75s ease-in-out infinite alternate 0.35s; }
.bar5 { height: 32px; animation: barWave 1.35s ease-in-out infinite alternate 0.08s; }
.bar6 { height: 22px; animation: barWave 0.95s ease-in-out infinite alternate 0.28s; }
.bar7 { height: 30px; animation: barWave 1.2s ease-in-out infinite alternate 0.4s; }
.bar8 { height: 18px; animation: barWave 0.8s ease-in-out infinite alternate 0.18s; }
.bar9 { height: 24px; animation: barWave 1.15s ease-in-out infinite alternate 0.3s; }
.bar10 { height: 14px; animation: barWave 0.9s ease-in-out infinite alternate 0.12s; }
.bar11 { height: 8px; animation: barWave 1.05s ease-in-out infinite alternate 0.25s; }

@keyframes barWave {
  0% {
    height: 6px;
    opacity: 0.4;
    background-color: #16a34a;
  }
  50% {
    height: 34px;
    opacity: 1;
    background-color: #4ade80;
    box-shadow: 0 0 14px rgba(74, 222, 128, 0.9);
  }
  100% {
    height: 10px;
    opacity: 0.6;
    background-color: #22c55e;
  }
}
</style>
