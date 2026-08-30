<script setup lang="ts">
import PreloadImage from '@/components/media/PreloadImage.vue';
import { PhHeart, PhPushPin } from '@phosphor-icons/vue';

export interface LibraryItemData {
  id: string;
  image?: string;
  isCircle?: boolean;
  isPinned?: boolean;
  subtitle: string;
  title: string;
  to: any;
  type: 'album' | 'artist' | 'liked-songs' | 'playlist' | 'podcast';
}

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
    :class="$style.libraryRow"
    role="button"
    tabindex="0"
    :title="`Open ${item.title}`"
    @click="onItemClick"
    @keydown.enter="onItemClick"
  >
    <!-- Left Thumbnail -->
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

    <!-- Metadata Content (Title + Subtitle) -->
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
.libraryRow {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 8px 12px;
  border-radius: 8px;
  cursor: pointer;
  background-color: transparent;
  touch-action: manipulation;
  -webkit-tap-highlight-color: transparent;
  will-change: background-color, transform;
  transition: background-color 0.12s ease, transform 0.08s cubic-bezier(0.2, 0, 0, 1);
  user-select: none;

  &:hover {
    background-color: rgba(255, 255, 255, 0.07);
    transform: translateY(-1px);
  }

  &:active {
    background-color: rgba(255, 255, 255, 0.12);
    transform: scale(0.98);
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
  border-radius: 6px;
  box-shadow: 0 4px 12px rgba(69, 10, 245, 0.25);
}

.likedHeartIcon {
  width: 24px;
  height: 24px;
  color: #ffffff;
  filter: drop-shadow(0 2px 4px rgba(0, 0, 0, 0.3));
}

.imageWrapper {
  position: relative;
  width: 100%;
  height: 100%;
  background-color: #1a1b24;
  overflow: hidden;
  border-radius: 6px;
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
  font-size: 1.25rem;
}

.metaContainer {
  display: flex;
  flex-direction: column;
  justify-content: center;
  gap: 3px;
  flex: 1;
  min-width: 0;
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
  font-size: 0.95rem;
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
  gap: 5px;
}

.pinIcon {
  width: 13px;
  height: 13px;
  color: #22c55e;
  flex-shrink: 0;
}

.subtitleText {
  display: -webkit-box;
  -webkit-line-clamp: 1;
  line-clamp: 1;
  -webkit-box-orient: vertical;
  overflow: hidden;
  font-size: 0.8rem;
  font-weight: 500;
  color: #a1a1aa;
  letter-spacing: -0.01em;
}
</style>
