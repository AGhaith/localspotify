<script setup lang="ts">
import type { AsyncDataRequestStatus } from 'nuxt/app';

import MainLoader from '@/components/notification/MainLoader.vue';
import SkeletonGrid from '@/components/notification/SkeletonGrid.vue';
import SkeletonList from '@/components/notification/SkeletonList.vue';

const props = withDefaults(
  defineProps<{
    count?: number;
    status: AsyncDataRequestStatus;
    variant?: 'circle-grid' | 'grid' | 'list' | 'wave';
  }>(),
  {
    count: 10,
    variant: 'wave',
  },
);

const showLoader = computed(
  () => props.status === 'pending' || props.status === 'idle',
);
</script>

<template>
  <div
    v-if="showLoader"
    ref="mainLoader"
    :class="[
      $style.loadingData,
      {
        [$style.centeredLoader]: variant === 'wave',
        [$style.skeletonContainer]: variant !== 'wave',
      },
    ]"
  >
    <!-- Skeleton Grid Variant -->
    <SkeletonGrid
      v-if="variant === 'grid' || variant === 'circle-grid'"
      :count="count"
      :isCircle="variant === 'circle-grid'"
    />

    <!-- Skeleton List / Tracklist Variant -->
    <SkeletonList
      v-else-if="variant === 'list'"
      :count="count"
    />

    <!-- Signature Wave Visualizer Loader -->
    <MainLoader v-else />
  </div>

  <div
    v-show="!showLoader"
    ref="mainContent"
    class="mainContent"
    v-bind="$attrs"
  >
    <slot />
  </div>
</template>

<style module>
.loadingData {
  position: relative;
  width: 100%;
  flex: 1;
}

.centeredLoader {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: 260px;
}

.skeletonContainer {
  display: block;
  width: 100%;
  animation: fadeIn 0.3s ease;
}

@keyframes fadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}
</style>
