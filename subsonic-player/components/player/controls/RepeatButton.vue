<script setup lang="ts">
import ButtonLink from '@/components/ui/ButtonLink.vue';

const { cycleRepeat, repeat } = useAudioPlayer();

const isSpinning = ref(false);
let spinTimeout: ReturnType<typeof setTimeout> | null = null;

const buttonProps = computed<ButtonProps>(() => {
  const noRepeat = repeat.value === REPEAT_MODE.off;

  return {
    icon: repeat.value === REPEAT_MODE.one ? ICONS.repeatOnce : ICONS.repeat,
    iconColor: noRepeat ? 'currentColor' : 'var(--theme-color)',
    iconWeight: noRepeat ? 'regular' : 'fill',
  };
});

const title = computed(() => {
  switch (repeat.value) {
    case REPEAT_MODE.all:
      return 'Turn on repeat one';
    case REPEAT_MODE.off:
      return 'Turn on repeat all';
    default:
      return 'Turn repeat off';
  }
});

function onClick() {
  if (spinTimeout) {
    clearTimeout(spinTimeout);
  }
  isSpinning.value = true;
  spinTimeout = setTimeout(() => {
    isSpinning.value = false;
  }, 500);

  cycleRepeat();
}
</script>

<template>
  <ButtonLink
    :class="[
      $style.repeatButton,
      {
        [$style.isSpinning]: isSpinning,
      },
    ]"
    :icon="buttonProps.icon"
    :iconColor="buttonProps.iconColor"
    :iconWeight="buttonProps.iconWeight"
    :title
    @click="onClick"
  >
    {{ title }}
  </ButtonLink>
</template>

<style module>
.repeatButton {
  position: relative;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  transition: transform 0.15s cubic-bezier(0.34, 1.56, 0.64, 1), color 0.15s ease !important;

  &:hover {
    transform: scale(1.15);
  }

  &:active {
    transform: scale(0.9);
  }
}

.isSpinning {
  animation: repeatSpin 0.5s cubic-bezier(0.34, 1.56, 0.64, 1) forwards;
}

@keyframes repeatSpin {
  0% {
    transform: rotate(0deg) scale(0.85);
  }
  50% {
    transform: rotate(190deg) scale(1.25);
  }
  100% {
    transform: rotate(360deg) scale(1);
  }
}
</style>
