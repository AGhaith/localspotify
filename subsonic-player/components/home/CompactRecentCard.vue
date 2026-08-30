<script setup lang="ts">
import PreloadImage from '@/components/media/PreloadImage.vue';
import { PhHeart } from '@phosphor-icons/vue';

export interface RecentItem {
  id: string;
  image?: string;
  isCircle?: boolean;
  title: string;
  to: any;
  type: 'album' | 'artist' | 'liked-songs' | 'playlist' | 'track';
  tracks?: Track[];
}

const props = defineProps<{
  item: RecentItem;
}>();

const emit = defineEmits<{
  play: [item: RecentItem];
}>();

async function onItemClick() {
  if (props.item.to) {
    await navigateTo(props.item.to);
  }
}
</script>

<template>
  <div
    :class="$style.compactCard"
    role="button"
    tabindex="0"
    :title="`Open ${item.title}`"
    @click="onItemClick"
    @keydown.enter="onItemClick"
  >
    <!-- Left Thumbnail Box -->
    <div :class="$style.thumbnailContainer">
      <!-- Liked Songs Gradient Tile -->
      <div v-if="item.type === 'liked-songs'" :class="$style.likedSongsTile">
        <PhHeart weight="fill" :class="$style.likedHeartIcon" />
      </div>

      <!-- Media Image / Avatar -->
      <div
        v-else
        :class="[
          $style.imageWrapper,
          {
            [$style.circleAvatar]: item.isCircle,
          },
        ]"
      >
        <PreloadImage
          v-if="item.image"
          :image="item.image"
          :class="$style.image"
          :lazyLoad="true"
        />
        <div v-else :class="$style.placeholderThumb">
          <span>{{ item.title.charAt(0) }}</span>
        </div>
      </div>
    </div>

    <!-- Title Label -->
    <div :class="$style.titleWrapper">
      <span :class="$style.titleText">
        {{ item.title }}
      </span>
    </div>
  </div>
</template>

<style module>
.compactCard {
  position: relative;
  display: flex;
  align-items: center;
  gap: 12px;
  height: 58px;
  background-color: #1a1b24;
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 8px;
  overflow: hidden;
  cursor: pointer;
  box-shadow: 2px 2px 0px #000000;
  touch-action: manipulation;
  -webkit-tap-highlight-color: transparent;
  will-change: transform, background-color, border-color;
  transition: background-color 0.12s ease,
    border-color 0.12s ease,
    transform 0.08s cubic-bezier(0.2, 0, 0, 1),
    box-shadow 0.12s ease;
  user-select: none;

  &:hover {
    background-color: #262734;
    border-color: rgba(255, 255, 255, 0.22);
    transform: translateY(-1px);
    box-shadow: 3px 3px 0px #000000, 0 0 16px rgba(34, 197, 94, 0.12);
  }

  &:active {
    transform: scale(0.96) translateY(1px);
    box-shadow: 1px 1px 0px #000000;
  }
}

.thumbnailContainer {
  position: relative;
  width: 58px;
  height: 58px;
  flex-shrink: 0;
}

.likedSongsTile {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 100%;
  height: 100%;
  background: linear-gradient(135deg, #450af5 0%, #8e8ee5 50%, #c4efd9 100%);
  border-radius: 6px 0 0 6px;
}

.likedHeartIcon {
  width: 26px;
  height: 26px;
  color: #ffffff;
  filter: drop-shadow(0 2px 4px rgba(0, 0, 0, 0.3));
}

.imageWrapper {
  position: relative;
  width: 100%;
  height: 100%;
  background-color: #12131a;
  overflow: hidden;
  border-radius: 6px 0 0 6px;
}

.circleAvatar {
  padding: 4px;

  .image {
    border-radius: 50% !important;
  }
}

.image {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.placeholderThumb {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 100%;
  height: 100%;
  background: #252634;
  color: #22c55e;
  font-weight: 800;
  font-size: 1.2rem;
}

.titleWrapper {
  flex: 1;
  min-width: 0;
  padding-right: 12px;
}

.titleText {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  font-size: 0.88rem;
  font-weight: 700;
  color: #ffffff;
  line-height: 1.25;
  letter-spacing: -0.01em;
}
</style>
