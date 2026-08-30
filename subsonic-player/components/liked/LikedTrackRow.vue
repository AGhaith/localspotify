<script setup lang="ts">
import DropdownDivider from '@/components/dropdown/DropdownDivider.vue';
import DropdownItem from '@/components/dropdown/DropdownItem.vue';
import DropdownMenu from '@/components/dropdown/DropdownMenu.vue';
import DropdownSubmenu from '@/components/dropdown/DropdownSubmenu.vue';
import FavouriteButton from '@/components/favourite/FavouriteButton.vue';
import PreloadImage from '@/components/media/PreloadImage.vue';
import { PhDotsThreeVertical } from '@phosphor-icons/vue';

const props = defineProps<{
  track: Track;
}>();

const emit = defineEmits<{
  addToPlaylist: [];
  addToQueue: [];
  downloadMedia: [];
  mediaInformation: [];
  playTrack: [];
}>();

const { isCurrentTrack } = useQueue();
const isPlayingThis = computed(() => isCurrentTrack(props.track.id));

const dropdownMenuRef = useTemplateRef('dropdownMenuRef');

function onClick() {
  emit('playTrack');
}

function openDropdown(event: MouseEvent | TouchEvent) {
  event.stopPropagation();
  dropdownMenuRef.value?.openDropdownMenu(event);
}
</script>

<template>
  <div
    :class="[
      $style.trackRow,
      {
        [$style.activePlayingRow]: isPlayingThis,
      },
    ]"
    role="button"
    tabindex="0"
    :title="`Play ${track.title}`"
    @click="onClick"
    @keydown.enter="onClick"
  >
    <!-- Left Cover Art Thumbnail -->
    <div :class="$style.thumbContainer">
      <PreloadImage
        v-if="track.image"
        :image="track.image"
        :class="$style.trackImage"
        :lazyLoad="true"
      />
      <div v-else :class="$style.placeholderImage">
        <span>{{ track.title.charAt(0) }}</span>
      </div>
    </div>

    <!-- Center Info (Title + Artist) -->
    <div :class="$style.trackInfo">
      <span
        :class="[
          $style.trackTitle,
          {
            [$style.greenTitle]: isPlayingThis,
          },
        ]"
      >
        <span v-if="isPlayingThis" :class="$style.playingIndicator">▶ </span>
        {{ track.title }}
      </span>

      <span :class="$style.trackArtist">
        {{ track.artists.map((a) => a.name).join(', ') || track.artist }}
      </span>
    </div>

    <!-- Right Kebab Options Menu -->
    <div :class="$style.optionsWrapper" @click.stop>
      <DropdownMenu ref="dropdownMenuRef">
        <template #icon>
          <button
            type="button"
            :class="$style.kebabBtn"
            title="More options"
            aria-label="More options"
            @click="openDropdown"
          >
            <PhDotsThreeVertical weight="bold" :class="$style.kebabIcon" />
          </button>
        </template>

        <DropdownItem @click="$emit('playTrack')">
          Play track
        </DropdownItem>
        <DropdownItem @click="$emit('addToQueue')">
          Add to queue
        </DropdownItem>
        <DropdownItem @click="$emit('addToPlaylist')">
          Add to playlist
        </DropdownItem>
        <DropdownDivider />
        <DropdownItem
          v-if="track.albumId"
          is="nuxt-link"
          :to="{
            name: ROUTE_NAMES.album,
            params: {
              [ROUTE_PARAM_KEYS.album.id]: track.albumId,
            },
          }"
        >
          Go to album
        </DropdownItem>
        <DropdownSubmenu v-if="track.artists.length" text="Artists">
          <DropdownItem
            is="nuxt-link"
            v-for="artist in track.artists"
            :key="artist.id"
            :to="{
              name: ROUTE_NAMES.artist,
              params: {
                [ROUTE_PARAM_KEYS.artist.id]: artist.id,
              },
            }"
          >
            {{ artist.name }}
          </DropdownItem>
        </DropdownSubmenu>
        <DropdownDivider />
        <DropdownItem @click="$emit('downloadMedia')">
          Download track
        </DropdownItem>
        <DropdownItem @click="$emit('mediaInformation')">
          Media information
        </DropdownItem>
        <DropdownDivider />
        <DropdownItem is="span">
          <FavouriteButton
            :id="track.id"
            class="globalLink"
            :favourite="track.favourite"
            showText
            :type="track.type"
          />
        </DropdownItem>
      </DropdownMenu>
    </div>
  </div>
</template>

<style module>
.trackRow {
  display: flex;
  align-items: center;
  gap: 12px;
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
    background-color: rgba(255, 255, 255, 0.08);
  }

  &:active {
    background-color: rgba(255, 255, 255, 0.14);
    transform: scale(0.99);
  }
}

.activePlayingRow {
  background-color: rgba(34, 197, 94, 0.08) !important;
}

.thumbContainer {
  position: relative;
  width: 48px;
  height: 48px;
  flex-shrink: 0;
  border-radius: 4px;
  overflow: hidden;
  background-color: #1a1b24;
}

.trackImage {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.placeholderImage {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 100%;
  height: 100%;
  background: #252634;
  color: #22c55e;
  font-weight: 800;
  font-size: 1.1rem;
}

.trackInfo {
  display: flex;
  flex-direction: column;
  justify-content: center;
  gap: 3px;
  flex: 1;
  min-width: 0;
}

.trackTitle {
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

.greenTitle {
  color: #22c55e !important;
  font-weight: 800;
}

.playingIndicator {
  font-size: 0.75rem;
  margin-right: 2px;
  color: #22c55e;
}

.trackArtist {
  display: -webkit-box;
  -webkit-line-clamp: 1;
  line-clamp: 1;
  -webkit-box-orient: vertical;
  overflow: hidden;
  font-size: 0.82rem;
  font-weight: 500;
  color: #a1a1aa;
}

.optionsWrapper {
  flex-shrink: 0;
  display: flex;
  align-items: center;
}

.kebabBtn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 32px;
  height: 32px;
  background: transparent;
  border: none;
  color: #a1a1aa;
  cursor: pointer;
  border-radius: 50%;
  transition: color 0.12s ease, background-color 0.12s ease;

  &:hover {
    color: #ffffff;
    background-color: rgba(255, 255, 255, 0.1);
  }
}

.kebabIcon {
  width: 18px;
  height: 18px;
}
</style>
