<script setup lang="ts">
import SkeletonCard from '@/components/notification/SkeletonCard.vue';
import GridWrapper from '@/components/ui/GridWrapper.vue';

withDefaults(
  defineProps<{
    count?: number;
    isCircle?: boolean;
  }>(),
  {
    count: 10,
    isCircle: false,
  },
);
</script>

<template>
  <div :class="$style.skeletonGridContainer">
    <GridWrapper>
      <SkeletonCard
        v-for="idx in count"
        :key="idx"
        :isCircle="isCircle"
        :style="{ animationDelay: `${(idx % 5) * 0.1}s` }"
      />
    </GridWrapper>
  </div>
</template>

<style module>
.skeletonGridContainer {
  width: 100%;
  padding-bottom: 24px;
}
</style>
