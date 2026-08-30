<script setup lang="ts">
import type { LibraryItemData } from '@/components/library/LibraryItemRow.vue';
import PreloadImage from '@/components/media/PreloadImage.vue';
import { PhHeart, PhPushPin } from '@phosphor-icons/vue';

const props = defineProps<{
  item: LibraryItemData;
}>();

async function onItemClick() {
  if (props.item.to) {
    await navigateTo(props.item.to);
  }
}
</script>

<template>
  <div
    :class="$style.libraryCard"
    role="button"
    tabindex="0"
    :title="`Open ${item.title}`"
    @click="onItemClick"
    @keydown.enter="onItemClick"
  >
    <!-- Top Thumbnail -->
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
          :class="[$style.image, { [$style.circleImage]: item.isCircle }]"
          :lazyLoad="true"
        />
        <div v-else :class="[$style.placeholderThumb, { [$style.circleThumb]: item.isCircle }]">
          <span>{{ item.title.charAt(0) }}</span>
        </div>
      </div>
    </div>

    <!-- Metadata (Title + Subtitle) -->
    <div :class="$style.metaContainer">
      <div :class="[$style.titleRow, { [$style.likedTitle]: item.type === 'liked-songs' }]">
        <span :class="$style.titleText">
          {{ item.title }}
        </span>
      </div>

      <div :class="$style.subtitleRow">
        <PhPushPin
          v-if="item.isPinned"
          weight="fill"
          :class="$style.pinIcon"
        />
        <span :class="$style.subtitleText">
          {{ item.subtitle }}
        </span>
      </div>
    </div>
  </div>
</template>

<style module>
.libraryCard {
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 10px;
  border-radius: 8px;
  background-color: #161720;
  border: 1px solid rgba(255, 255, 255, 0.06);
  cursor: pointer;
  touch-action: manipulation;
  -webkit-tap-highlight-color: transparent;
  will-change: background-color, transform;
  transition: background-color 0.15s ease,
    border-color 0.15s ease,
    transform 0.08s cubic-bezier(0.2, 0, 0, 1),
    box-shadow 0.15s ease;
  user-select: none;

  &:hover {
    background-color: #222330;
    border-color: rgba(255, 255, 255, 0.18);
    transform: translateY(-2px);
    box-shadow: 0 8px 20px rgba(0, 0, 0, 0.6);
  }

  &:active {
    transform: scale(0.97);
  }
}

.thumbnailContainer {
  position: relative;
  width: 100%;
  aspect-ratio: 1 / 1;
}

.likedSongsTile {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 100%;
  height: 100%;
  background: linear-gradient(135deg, #450af5 0%, #8e8ee5 50%, #c4efd9 100%);
  border-radius: 8px;
  box-shadow: 0 4px 14px rgba(69, 10, 245, 0.3);
}

.likedHeartIcon {
  width: 36%;
  height: 36%;
  color: #ffffff;
  filter: drop-shadow(0 2px 4px rgba(0, 0, 0, 0.3));
}

.imageWrapper {
  position: relative;
  width: 100%;
  height: 100%;
  background-color: #12131a;
  overflow: hidden;
  border-radius: 8px;
}

.circleAvatar {
  border-radius: 50% !important;
}

.circleImage {
  border-radius: 50% !important;
}

.circleThumb {
  border-radius: 50% !important;
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
  background: #242533;
  color: #22c55e;
  font-weight: 800;
  font-size: 2rem;
}

.metaContainer {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.titleRow {
  display: flex;
  align-items: center;
}

.titleText {
  display: -webkit-box;
  -webkit-line-clamp: 1;
  line-clamp: 1;
  -webkit-box-orient: vertical;
  overflow: hidden;
  font-size: 0.9rem;
  font-weight: 700;
  color: #ffffff;
  letter-spacing: -0.01em;
}

.likedTitle .titleText {
  color: #22c55e;
  font-weight: 800;
}

.subtitleRow {
  display: flex;
  align-items: center;
  gap: 4px;
}

.pinIcon {
  width: 12px;
  height: 12px;
  color: #22c55e;
  flex-shrink: 0;
}

.subtitleText {
  display: -webkit-box;
  -webkit-line-clamp: 1;
  line-clamp: 1;
  -webkit-box-orient: vertical;
  overflow: hidden;
  font-size: 0.76rem;
  font-weight: 500;
  color: #a1a1aa;
}
</style>
