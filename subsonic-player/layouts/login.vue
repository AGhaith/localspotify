<template>
  <div :class="$style.loginContainer">
    <!-- Neo-Green Ambient Glow Mesh -->
    <div :class="$style.backgroundGlow" aria-hidden="true">
      <div :class="[$style.glowOrb, $style.glowGreenTop]" />
      <div :class="[$style.glowOrb, $style.glowEmeraldBottom]" />
      <div :class="[$style.glowOrb, $style.glowLimeCenter]" />
    </div>

    <!-- Animated Audio Equalizer Wave Spectrum (Bottom) -->
    <div :class="$style.spectrumBars" aria-hidden="true">
      <div
        v-for="bar in 24"
        :key="bar"
        :class="$style.spectrumBar"
        :style="{ '--bar-idx': bar }"
      />
    </div>

    <!-- Geometric Audio Grid Pattern -->
    <div :class="$style.audioGrid" aria-hidden="true" />

    <!-- Floating Neon Green Particles -->
    <div :class="$style.particlesContainer" aria-hidden="true">
      <span
        v-for="p in 14"
        :key="p"
        :class="$style.greenParticle"
        :style="{ '--p-idx': p }"
      />
    </div>

    <!-- Content Slot -->
    <main :class="['centerAll', $style.mainContent]">
      <slot />
    </main>
  </div>
</template>

<style module>
.loginContainer {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 100svh;
  width: 100%;
  overflow: hidden;
  background-color: #000000;
  color: #f4f4f5;
  font-family: inherit;
}

.mainContent {
  position: relative;
  z-index: 10;
  width: 100%;
  padding: 24px 16px;
}

/* Ambient Green Glow */
.backgroundGlow {
  position: fixed;
  inset: 0;
  z-index: 1;
  pointer-events: none;
  overflow: hidden;
}

.glowOrb {
  position: absolute;
  border-radius: 50%;
  filter: blur(100px);
  will-change: transform, opacity;
}

.glowGreenTop {
  top: -10%;
  left: 20%;
  width: 500px;
  height: 500px;
  background: radial-gradient(circle, rgba(34, 197, 94, 0.22) 0%, rgba(34, 197, 94, 0) 70%);
  animation: floatOrbTop 16s ease-in-out infinite alternate;
}

.glowEmeraldBottom {
  bottom: -5%;
  right: 15%;
  width: 460px;
  height: 460px;
  background: radial-gradient(circle, rgba(16, 185, 129, 0.18) 0%, rgba(16, 185, 129, 0) 70%);
  animation: floatOrbBottom 20s ease-in-out infinite alternate;
}

.glowLimeCenter {
  top: 45%;
  left: 50%;
  transform: translate(-50%, -50%);
  width: 380px;
  height: 380px;
  background: radial-gradient(circle, rgba(74, 222, 128, 0.1) 0%, rgba(74, 222, 128, 0) 70%);
  animation: pulseCenter 12s ease-in-out infinite alternate;
}

@keyframes floatOrbTop {
  0% { transform: translate3d(0, 0, 0) scale(1); }
  50% { transform: translate3d(60px, 80px, 0) scale(1.15); }
  100% { transform: translate3d(-50px, 50px, 0) scale(0.9); }
}

@keyframes floatOrbBottom {
  0% { transform: translate3d(0, 0, 0) scale(1); }
  50% { transform: translate3d(-80px, -60px, 0) scale(1.12); }
  100% { transform: translate3d(40px, -70px, 0) scale(0.92); }
}

@keyframes pulseCenter {
  0% { transform: translate(-50%, -50%) scale(0.85); opacity: 0.6; }
  100% { transform: translate(-50%, -50%) scale(1.25); opacity: 1; }
}

/* Audio Spectrum Visualizer (Bottom) */
.spectrumBars {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  z-index: 2;
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  height: 120px;
  padding: 0 20px;
  opacity: 0.18;
  pointer-events: none;
}

.spectrumBar {
  width: calc(100% / 32);
  max-width: 6px;
  height: 60px;
  border-radius: 4px 4px 0 0;
  background: linear-gradient(180deg, #22c55e 0%, rgba(34, 197, 94, 0.1) 100%);
  transform-origin: bottom;
  animation: spectrumBounce 2s ease-in-out infinite alternate;
  animation-delay: calc(var(--bar-idx) * 0.08s);
}

@keyframes spectrumBounce {
  0% {
    transform: scaleY(0.2);
    opacity: 0.3;
  }
  50% {
    transform: scaleY(1);
    opacity: 0.9;
  }
  100% {
    transform: scaleY(0.4);
    opacity: 0.5;
  }
}

/* Subtle Geometric Grid */
.audioGrid {
  position: fixed;
  inset: 0;
  z-index: 2;
  background-image: linear-gradient(to right, rgba(34, 197, 94, 0.03) 1px, transparent 1px),
    linear-gradient(to bottom, rgba(34, 197, 94, 0.03) 1px, transparent 1px);
  background-size: 40px 40px;
  pointer-events: none;
}

/* Floating Particles */
.particlesContainer {
  position: fixed;
  inset: 0;
  z-index: 3;
  pointer-events: none;
}

.greenParticle {
  position: absolute;
  width: 3px;
  height: 3px;
  border-radius: 50%;
  background-color: #22c55e;
  box-shadow: 0 0 8px #22c55e;
  bottom: -20px;
  left: calc(var(--p-idx) * 7.1%);
  animation: particleFloat 12s linear infinite;
  animation-delay: calc(var(--p-idx) * 0.85s);
  opacity: 0;
}

@keyframes particleFloat {
  0% {
    transform: translateY(0) scale(0.5);
    opacity: 0;
  }
  20% {
    opacity: 0.7;
  }
  80% {
    opacity: 0.5;
  }
  100% {
    transform: translateY(-110vh) scale(1.3);
    opacity: 0;
  }
}
</style>
