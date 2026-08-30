<script setup lang="ts">
import SkeletonRow from '@/components/notification/SkeletonRow.vue';

withDefaults(
  defineProps<{
    count?: number;
    hasCover?: boolean;
  }>(),
  {
    count: 8,
    hasCover: true,
  },
);
</script>

<template>
  <div :class="$style.skeletonListContainer">
    <SkeletonRow
      v-for="idx in count"
      :key="idx"
      :hasCover="hasCover"
      :style="{ animationDelay: `${(idx % 6) * 0.08}s` }"
    />
  </div>
</template>

<style module>
.skeletonListContainer {
  display: flex;
  flex-direction: column;
  gap: 4px;
  width: 100%;
  padding-bottom: 24px;
}
</style>
