<script setup lang="ts">
const route = useRoute();

const isAllActive = computed(() => {
  return (
    route.path === '/' ||
    route.path === '/home' ||
    route.name === ROUTE_NAMES.index
  );
});

const isMusicActive = computed(() => {
  return (
    route.path.startsWith('/album') ||
    route.path.startsWith('/artist') ||
    route.path.startsWith('/genre') ||
    route.path.startsWith('/favourite') ||
    route.path.startsWith('/playlist') ||
    route.path === '/library'
  );
});

const isRadioActive = computed(() => {
  return (
    route.path.startsWith('/radio') ||
    route.name === ROUTE_NAMES.radioStations
  );
});
</script>

<template>
  <nav :class="$style.filterNav" aria-label="Media filter">
    <!-- "All" Pill (Instant Prefetch & Memory Cache) -->
    <NuxtLink
      :to="{ name: ROUTE_NAMES.home }"
      :prefetch="true"
      :class="[
        $style.filterPill,
        {
          [$style.activePill]: isAllActive,
        },
      ]"
    >
      All
    </NuxtLink>

    <!-- "Music" Pill (Instant Prefetch & Memory Cache) -->
    <NuxtLink
      :to="{
        name: ROUTE_NAMES.albums,
        params: {
          [ROUTE_PARAM_KEYS.albums.sortBy]:
            ROUTE_ALBUMS_SORT_BY_PARAMS['Recently added'],
        },
      }"
      :prefetch="true"
      :class="[
        $style.filterPill,
        {
          [$style.activePill]: isMusicActive,
        },
      ]"
    >
      Music
    </NuxtLink>

    <!-- "Radio Stations" Pill -->
    <NuxtLink
      :to="{ name: ROUTE_NAMES.radioStations }"
      :prefetch="true"
      :class="[
        $style.filterPill,
        {
          [$style.activePill]: isRadioActive,
        },
      ]"
    >
      Radio Stations
    </NuxtLink>
  </nav>
</template>

<style module>
.filterNav {
  display: flex;
  align-items: center;
  gap: 8px;
  overflow-x: auto;
  scrollbar-width: none;
  -webkit-overflow-scrolling: touch;
  touch-action: manipulation;
  padding: 2px 0;

  &::-webkit-scrollbar {
    display: none;
  }
}

.filterPill {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  height: 34px;
  padding: 0 16px;
  background-color: #24252f;
  color: #ffffff;
  font-size: 0.88rem;
  font-weight: 600;
  letter-spacing: -0.01em;
  border-radius: 9999px;
  border: 1px solid rgba(255, 255, 255, 0.08);
  text-decoration: none;
  white-space: nowrap;
  user-select: none;
  cursor: pointer;
  box-shadow: 2px 2px 0px #000000;
  touch-action: manipulation;
  -webkit-tap-highlight-color: transparent;
  will-change: transform, background-color, box-shadow;
  transition: transform 0.08s cubic-bezier(0.2, 0, 0, 1),
    background-color 0.1s ease,
    border-color 0.1s ease,
    box-shadow 0.1s ease;

  &:hover {
    background-color: #323442;
    border-color: rgba(255, 255, 255, 0.2);
    transform: translateY(-1px);
  }

  &:active {
    transform: scale(0.93) translateY(1px);
    box-shadow: 1px 1px 0px #000000;
  }
}

.activePill {
  background-color: #22c55e !important;
  color: #000000 !important;
  font-weight: 800 !important;
  border-color: #22c55e !important;
  box-shadow: 3px 3px 0px #000000, 0 0 16px rgba(34, 197, 94, 0.35) !important;

  &:hover {
    background-color: #1ed760 !important;
  }

  &:active {
    transform: scale(0.93) translateY(1px) !important;
    box-shadow: 1px 1px 0px #000000 !important;
  }
}
</style>
