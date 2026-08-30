<script setup lang="ts">
import LoginForm from '@/components/auth/LoginForm.vue';

definePageMeta({
  layout: 'login',
});

const route = useRoute();

const { error, isAuthenticated, loading, login } = useAuth();

async function onFormSubmit(fields: AuthData) {
  const { password, server, username } = fields;

  await login({
    password,
    server,
    username,
  });

  await redirectIfAuthenticated();
}

function redirectIfAuthenticated() {
  if (isAuthenticated.value) {
    setLocalStorage(LOCAL_STORAGE_KEYS.login, Date.now().toString());

    const destination = route.query.redirect?.toString() || {
      name: ROUTE_NAMES.index,
    };

    return navigateTo(destination);
  }
}

useHead({
  title: 'Sign In',
});
</script>

<template>
  <div :class="$style.loginWrapper">
    <!-- Main Card Container -->
    <div :class="$style.loginCard">
      <!-- Glow effect inside card top -->
      <div :class="$style.cardGlow" aria-hidden="true" />

      <!-- Minimal Unbranded Header -->
      <header :class="$style.cardHeader">
        <!-- High-Fidelity Animated Audio Wave Visualizer -->
        <div :class="$style.waveVisualizer" aria-hidden="true">
          <span
            v-for="bar in 9"
            :key="bar"
            :class="[$style.waveStick, $style[`stick${bar}`]]"
          />
        </div>

        <h1 :class="$style.title">
          Sign In
        </h1>
      </header>

      <!-- Auth Form -->
      <LoginForm :error :loading @submit="onFormSubmit" />
    </div>
  </div>
</template>

<style module>
.loginWrapper {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  width: 100%;
  max-width: 420px;
  animation: cardEntrance 0.65s cubic-bezier(0.16, 1, 0.3, 1) forwards;
}

@keyframes cardEntrance {
  0% {
    opacity: 0;
    transform: translateY(20px) scale(0.97);
  }
  100% {
    opacity: 1;
    transform: translateY(0) scale(1);
  }
}

/* Neo-Brutalist Black Card with Green Accent */
.loginCard {
  position: relative;
  width: 100%;
  padding: 36px 30px 32px;
  background-color: #0c0d12;
  border: 2px solid rgba(255, 255, 255, 0.14);
  border-radius: 20px;
  box-shadow: 6px 6px 0px #000000, 0 0 30px rgba(34, 197, 94, 0.12);
  overflow: hidden;
  transition: transform 0.2s ease, box-shadow 0.2s ease, border-color 0.2s ease;

  &:hover {
    border-color: rgba(34, 197, 94, 0.4);
    box-shadow: 6px 6px 0px #000000, 0 0 40px rgba(34, 197, 94, 0.2);
  }
}

.cardGlow {
  position: absolute;
  top: -60px;
  left: 50%;
  transform: translateX(-50%);
  width: 220px;
  height: 100px;
  background: radial-gradient(ellipse, rgba(34, 197, 94, 0.25) 0%, rgba(34, 197, 94, 0) 70%);
  filter: blur(35px);
  pointer-events: none;
}

/* Header Section */
.cardHeader {
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
  margin-bottom: 24px;
}

/* Enhanced Animated Audio Wave Visualizer */
.waveVisualizer {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 4px;
  height: 38px;
  padding: 6px 16px;
  background: rgba(34, 197, 94, 0.08);
  border: 1.5px solid rgba(34, 197, 94, 0.3);
  border-radius: 9999px;
  box-shadow: 0 0 16px rgba(34, 197, 94, 0.18), inset 0 0 10px rgba(34, 197, 94, 0.05);
  margin-bottom: 16px;
  transition: transform 0.2s ease, box-shadow 0.2s ease, border-color 0.2s ease;

  .loginCard:hover & {
    transform: scale(1.05);
    border-color: #22c55e;
    box-shadow: 0 0 24px rgba(34, 197, 94, 0.35);
  }
}

.waveStick {
  width: 3.5px;
  border-radius: 9999px;
  background-color: #22c55e;
  box-shadow: 0 0 8px rgba(34, 197, 94, 0.6);
  min-height: 4px;
  will-change: height, opacity;
}

.stick1 {
  height: 8px;
  animation: waveMotion 1.1s ease-in-out infinite alternate;
}

.stick2 {
  height: 16px;
  animation: waveMotion 0.8s ease-in-out infinite alternate 0.12s;
}

.stick3 {
  height: 22px;
  animation: waveMotion 1.25s ease-in-out infinite alternate 0.24s;
}

.stick4 {
  height: 14px;
  animation: waveMotion 0.75s ease-in-out infinite alternate 0.36s;
}

.stick5 {
  height: 26px;
  animation: waveMotion 1.35s ease-in-out infinite alternate 0.1s;
}

.stick6 {
  height: 18px;
  animation: waveMotion 0.9s ease-in-out infinite alternate 0.28s;
}

.stick7 {
  height: 24px;
  animation: waveMotion 1.2s ease-in-out infinite alternate 0.4s;
}

.stick8 {
  height: 12px;
  animation: waveMotion 0.85s ease-in-out infinite alternate 0.18s;
}

.stick9 {
  height: 6px;
  animation: waveMotion 1.05s ease-in-out infinite alternate 0.32s;
}

@keyframes waveMotion {
  0% {
    height: 4px;
    opacity: 0.35;
  }
  50% {
    height: 24px;
    opacity: 1;
    background-color: #4ade80;
    box-shadow: 0 0 12px rgba(74, 222, 128, 0.8);
  }
  100% {
    height: 8px;
    opacity: 0.55;
  }
}

.title {
  font-size: 1.65rem;
  font-weight: 800;
  letter-spacing: -0.02em;
  color: #ffffff;
  margin: 0;
}
</style>
