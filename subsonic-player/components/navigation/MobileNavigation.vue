<script setup lang="ts">
import {
  PhArrowCircleDown,
  PhBooks,
  PhHouse,
  PhMagnifyingGlass,
} from '@phosphor-icons/vue';

defineProps<{
  navigation?: NavigationItem[];
}>();

function getIconForTitle(title: string) {
  switch (title.toLowerCase()) {
    case 'home':
      return PhHouse;
    case 'search':
      return PhMagnifyingGlass;
    case 'library':
      return PhBooks;
    case 'offline':
    case 'downloads':
      return PhArrowCircleDown;
    default:
      return null;
  }
}
</script>

<template>
  <nav aria-label="Mobile navigation" :class="$style.mobileNavWrapper">
    <ul :class="['inner', 'centerAll', 'spaceBetween', $style.mobileNavigation]">
      <li
        v-for="item in navigation"
        :key="`navigation-${item.title}`"
        :class="$style.item"
      >
        <NuxtLink
          :to="item.to"
          :class="$style.navLink"
          v-slot="{ isActive }"
        >
          <div :class="[$style.iconWrapper, { [$style.activeIcon]: isActive }]">
            <component
              :is="getIconForTitle(item.title) || item.icon"
              :weight="isActive ? 'fill' : 'bold'"
              :class="$style.navIcon"
            />
          </div>
          <span :class="[$style.navLabel, { [$style.activeLabel]: isActive }]">
            {{ item.title }}
          </span>
        </NuxtLink>
      </li>
    </ul>
  </nav>
</template>

<style module>
.mobileNavWrapper {
  position: fixed;
  inset: auto 0 0;
  z-index: 25;
  width: 100%;
  height: 62px;
  background: linear-gradient(180deg, rgba(0, 0, 0, 0.85) 0%, #000000 35%);
  backdrop-filter: blur(16px);
  -webkit-backdrop-filter: blur(16px);
  border-top: 1px solid rgba(255, 255, 255, 0.08);
}

.mobileNavigation {
  width: 100%;
  height: 100%;
  padding: 0 12px;
  margin: 0 auto;
  display: flex;
  align-items: center;
  justify-content: space-around;
  list-style: none;
}

.item {
  flex: 1;
  display: flex;
  justify-content: center;
  height: 100%;
}

.navLink {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 3px;
  width: 100%;
  height: 100%;
  padding: 4px 6px;
  text-decoration: none;
  user-select: none;
  touch-action: manipulation;
  -webkit-tap-highlight-color: transparent;
  will-change: transform;
  transition: transform 0.08s cubic-bezier(0.2, 0, 0, 1);

  &:active {
    transform: scale(0.92);
  }
}

.iconWrapper {
  display: flex;
  align-items: center;
  justify-content: center;
  color: #71717a;
  transition: color 0.15s ease, transform 0.15s cubic-bezier(0.34, 1.56, 0.64, 1);
}

.activeIcon {
  color: #22c55e !important;
  transform: translateY(-1px);
}

.navIcon {
  width: 22px;
  height: 22px;
}

.navLabel {
  font-size: 0.68rem;
  font-weight: 600;
  color: #71717a;
  letter-spacing: -0.01em;
  line-height: 1;
  transition: color 0.15s ease;
}

.activeLabel {
  color: #22c55e !important;
  font-weight: 800 !important;
  text-shadow: 0 0 8px rgba(34, 197, 94, 0.4);
}
</style>
