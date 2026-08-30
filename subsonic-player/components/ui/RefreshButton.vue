<script setup lang="ts">
import type { AsyncDataRequestStatus } from 'nuxt/app';
import { PhArrowsClockwise } from '@phosphor-icons/vue';

const props = defineProps<{
  status: AsyncDataRequestStatus;
}>();

defineEmits<{
  refresh: [];
}>();

const isPending = computed(() => props.status === 'pending');
</script>

<template>
  <button
    :id="KEYBOARD_SHORTCUT_ELEMENT_IDS.refreshDataButton"
    type="button"
    :class="[
      $style.refreshButton,
      {
        [$style.isRefreshing]: isPending,
      },
    ]"
    :disabled="isPending"
    :title="isPending ? 'Refreshing...' : 'Refresh page data'"
    aria-label="Refresh page data"
    @click="$emit('refresh')"
  >
    <PhArrowsClockwise
      weight="bold"
      :class="[
        $style.refreshIcon,
        {
          [$style.spinning]: isPending,
        },
      ]"
    />
  </button>
</template>

<style module>
.refreshButton {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 36px;
  height: 36px;
  border-radius: 50%;
  background-color: #1a1b24;
  color: #d4d4d8;
  border: 1px solid rgba(255, 255, 255, 0.12);
  box-shadow: 2px 2px 0px #000000;
  cursor: pointer;
  touch-action: manipulation;
  -webkit-tap-highlight-color: transparent;
  will-change: transform, border-color, box-shadow, color;
  transition: transform 0.1s cubic-bezier(0.2, 0, 0, 1),
    border-color 0.15s ease,
    background-color 0.15s ease,
    box-shadow 0.15s ease,
    color 0.15s ease;

  &:hover:not(:disabled) {
    background-color: #262736;
    border-color: #22c55e;
    color: #22c55e;
    transform: scale(1.08) translateY(-1px);
    box-shadow: 3px 3px 0px #000000, 0 0 14px rgba(34, 197, 94, 0.35);

    .refreshIcon:not(.spinning) {
      transform: rotate(180deg);
    }
  }

  &:active:not(:disabled) {
    transform: scale(0.92) translateY(1px);
    box-shadow: 1px 1px 0px #000000;
  }
}

.isRefreshing {
  border-color: #22c55e !important;
  color: #22c55e !important;
  box-shadow: 0 0 12px rgba(34, 197, 94, 0.3) !important;
  cursor: wait;
}

.refreshIcon {
  width: 20px;
  height: 20px;
  will-change: transform;
  transition: transform 0.45s cubic-bezier(0.34, 1.56, 0.64, 1);
}

.spinning {
  animation: spinRefresh 0.75s cubic-bezier(0.4, 0, 0.2, 1) infinite;
}

@keyframes spinRefresh {
  0% {
    transform: rotate(0deg);
  }
  100% {
    transform: rotate(360deg);
  }
}
</style>
