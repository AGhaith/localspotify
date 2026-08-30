<script setup lang="ts">
import ButtonLink from '@/components/ui/ButtonLink.vue';

const props = withDefaults(
  defineProps<{
    favourite: boolean;
    id: string;
    showText?: boolean;
    type: MediaType;
  }>(),
  {
    showText: false,
  },
);

const { favouriteIds, setFavouriteId, toggleFavourite } = useFavourite();

const isFavourite = computed(() => !!favouriteIds.value[props.id]);
const isAnimating = ref(false);
const isUnliking = ref(false);

const buttonProps = computed<ButtonProps>(() => ({
  iconColor: isFavourite.value ? 'var(--error-color)' : undefined,
  iconWeight: isFavourite.value ? 'fill' : 'regular',
  text: `${isFavourite.value ? 'Unlike' : 'Like'} ${props.type}`,
}));

function onClick() {
  const willBeFavourite = !isFavourite.value;
  if (willBeFavourite) {
    isAnimating.value = true;
    isUnliking.value = false;
    setTimeout(() => {
      isAnimating.value = false;
    }, 700);
  } else {
    isUnliking.value = true;
    isAnimating.value = false;
    setTimeout(() => {
      isUnliking.value = false;
    }, 350);
  }

  // No need to pass isFavourite.value value, use props directly.
  toggleFavourite(props, isFavourite.value);
}

watch(
  () => props.id || props.favourite,
  () => {
    // Check if id exists as a key, cannot check value as it could be false.
    if (props.id in favouriteIds.value) {
      return;
    }

    if (props.favourite) {
      setFavouriteId(props.id);
    }
  },
  {
    immediate: true,
  },
);
</script>

<template>
  <div :class="$style.wrapper">
    <ButtonLink
      :class="[
        $style.likeBtn,
        {
          [$style.animateLike]: isAnimating,
          [$style.animateUnlike]: isUnliking,
          [$style.isLiked]: isFavourite,
        },
      ]"
      :icon="ICONS.favourite"
      :iconColor="buttonProps.iconColor"
      :iconWeight="buttonProps.iconWeight"
      iconPosition="right"
      :showText
      :title="buttonProps.text"
      @click="onClick"
    >
      {{ buttonProps.text }}
    </ButtonLink>

    <!-- Radiating Sparkle Burst Ring on Like -->
    <span v-if="isAnimating" :class="$style.sparkleRing">
      <i :class="$style.sparkle" style="--angle: 0deg; --dist: 16px;" />
      <i :class="$style.sparkle" style="--angle: 60deg; --dist: 16px;" />
      <i :class="$style.sparkle" style="--angle: 120deg; --dist: 16px;" />
      <i :class="$style.sparkle" style="--angle: 180deg; --dist: 16px;" />
      <i :class="$style.sparkle" style="--angle: 240deg; --dist: 16px;" />
      <i :class="$style.sparkle" style="--angle: 300deg; --dist: 16px;" />
    </span>
  </div>
</template>

<style module>
.wrapper {
  position: relative;
  display: inline-flex;
  align-items: center;
  justify-content: center;
}

.likeBtn {
  position: relative;
  transition: transform 0.16s cubic-bezier(0.34, 1.56, 0.64, 1), color 0.15s ease;

  &:hover {
    transform: scale(1.15);
  }

  &:active {
    transform: scale(0.85);
  }
}

.animateLike {
  animation: heartPop 0.65s cubic-bezier(0.175, 0.885, 0.32, 1.275) forwards;
}

.animateUnlike {
  animation: heartDeflate 0.3s cubic-bezier(0.4, 0, 0.2, 1) forwards;
}

@keyframes heartPop {
  0% {
    transform: scale(1);
  }
  20% {
    transform: scale(0.62);
  }
  45% {
    transform: scale(1.46);
    filter: drop-shadow(0 0 12px rgba(239, 68, 68, 0.85));
  }
  70% {
    transform: scale(0.92);
    filter: drop-shadow(0 0 6px rgba(239, 68, 68, 0.4));
  }
  85% {
    transform: scale(1.08);
  }
  100% {
    transform: scale(1);
    filter: none;
  }
}

@keyframes heartDeflate {
  0% {
    transform: scale(1);
  }
  40% {
    transform: scale(0.78);
  }
  100% {
    transform: scale(1);
  }
}

.sparkleRing {
  position: absolute;
  top: 50%;
  left: 50%;
  width: 1px;
  height: 1px;
  pointer-events: none;
}

.sparkle {
  position: absolute;
  top: 0;
  left: 0;
  width: 4px;
  height: 4px;
  border-radius: 50%;
  background-color: #ef4444;
  box-shadow: 0 0 6px #ef4444, 0 0 10px rgba(239, 68, 68, 0.8);
  transform: translate(-50%, -50%);
  animation: sparkleBurst 0.6s cubic-bezier(0.25, 1, 0.5, 1) forwards;
}

@keyframes sparkleBurst {
  0% {
    opacity: 1;
    transform: translate(-50%, -50%) rotate(var(--angle)) translateY(0px) scale(0.5);
  }
  50% {
    opacity: 1;
    transform: translate(-50%, -50%) rotate(var(--angle)) translateY(calc(-1 * var(--dist))) scale(1.3);
  }
  100% {
    opacity: 0;
    transform: translate(-50%, -50%) rotate(var(--angle)) translateY(calc(-1.5 * var(--dist))) scale(0);
  }
}
</style>
