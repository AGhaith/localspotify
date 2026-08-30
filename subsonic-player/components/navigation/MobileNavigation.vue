<script setup lang="ts">
import ButtonLink from '@/components/ui/ButtonLink.vue';

defineProps<{
  navigation?: NavigationItem[];
}>();
</script>

<template>
  <nav aria-label="Mobile">
    <ul
      :class="['inner', 'centerAll', 'spaceBetween', $style.mobileNavigation]"
    >
      <li
        v-for="item in navigation"
        :key="`navigation-${item.title}`"
        :class="$style.item"
      >
        <ButtonLink
          is="nuxt-link"
          v-if="item.icon"
          :class="['link smallFont column centerAll', $style.navLink]"
          :icon="item.icon"
          showText
          :title="item.title"
          :to="item.to"
        >
          {{ item.title }}
        </ButtonLink>
      </li>
    </ul>
  </nav>
</template>

<style module>
.mobileNavigation {
  position: fixed;
  inset: auto 0 0;
  z-index: 15;
  width: var(--width-height-100);
  height: var(--header-height);
  padding: 6px 12px;
  background-color: #000000;
  border-top: 1px solid rgba(255, 255, 255, 0.1);
}

.item {
  flex: 1;
  display: flex;
  justify-content: center;
}

.navLink {
  gap: 3px !important;
  padding: 4px 8px !important;
  color: #71717a !important;
  font-size: 0.72rem !important;
  font-weight: 600 !important;
  letter-spacing: 0.01em;
  transition: color 0.15s ease, transform 0.1s ease;

  &:global(.router-link-active) {
    color: #22c55e !important;
    font-weight: 800 !important;
  }
}
</style>
