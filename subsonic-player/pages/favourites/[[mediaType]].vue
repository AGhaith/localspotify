<script setup lang="ts">
import AlbumList from '@/components/album/AlbumList.vue';
import ArtistList from '@/components/artist/ArtistList.vue';
import LikedTrackRow from '@/components/liked/LikedTrackRow.vue';
import PageNavigation from '@/components/navigation/PageNavigation.vue';
import LoadingData from '@/components/notification/LoadingData.vue';
import NoMediaMessage from '@/components/notification/NoMediaMessage.vue';
import HeaderWithAction from '@/components/ui/HeaderWithAction.vue';
import RefreshButton from '@/components/ui/RefreshButton.vue';
import {
  PhArrowCircleDown,
  PhArrowLeft,
  PhArrowsDownUp,
  PhMagnifyingGlass,
  PhPlay,
  PhPlus,
  PhShuffle,
  PhX,
} from '@phosphor-icons/vue';

definePageMeta({
  middleware: [MIDDLEWARE_NAMES.favourites],
});

const router = useRouter();
const route = useRoute();
const { user } = useUser();
const { viewLayout } = useSettings();
const { downloadTrack } = useMediaLibrary();
const { addToPlaylistModal } = usePlaylist();
const { favourites, getFavourites } = useFavourite();
const { openAlbumDetailsModal, openTrackDetailsModal } = useMediaInformation();
const { addTracksToQueue, addTrackToQueue, playTracks, shuffleQueue } = useAudioPlayer();
const { dragStart } = useDragAndDrop();
const { getMediaTracks } = useMediaTracks();

// UI Filters & Sorting
const searchQuery = ref('');
const sortOption = ref<'added' | 'album' | 'artist' | 'duration' | 'title'>('added');
const showSortDropdown = ref(false);

/* istanbul ignore next -- @preserve */
const { refresh, status } = useAsyncData(
  ASYNC_DATA_KEYS.favourites,
  async () => {
    await getFavourites();

    return {
      favourites: favourites.value,
    };
  },
  {
    default: () => ({
      favourites: DEFAULT_ALL_MEDIA,
    }),
    getCachedData: (key, nuxtApp, ctx) => {
      if (ctx.cause === 'refresh:manual') {
        return undefined;
      }

      return nuxtApp.payload.data[key] || nuxtApp.static.data[key];
    },
  },
);

const currentMediaType = computed(() => {
  return (
    (route.params[ROUTE_PARAM_KEYS.favourites.mediaType] as string) ||
    ROUTE_MEDIA_TYPE_PARAMS.Tracks
  );
});

const isTracksView = computed(
  () => currentMediaType.value === ROUTE_MEDIA_TYPE_PARAMS.Tracks,
);
const isAlbumsView = computed(
  () => currentMediaType.value === ROUTE_MEDIA_TYPE_PARAMS.Albums,
);
const isArtistsView = computed(
  () => currentMediaType.value === ROUTE_MEDIA_TYPE_PARAMS.Artists,
);

const pageHeading = computed(() => {
  if (isAlbumsView.value) return 'Liked Albums';
  if (isArtistsView.value) return 'Liked Artists';
  return 'Liked Songs';
});

// Filter & Sort Liked Tracks
const displayedTracks = computed(() => {
  let tracks = [...(favourites.value?.tracks || [])];

  // Search filter
  if (searchQuery.value.trim()) {
    const q = searchQuery.value.toLowerCase().trim();
    tracks = tracks.filter(
      (t) =>
        t.title.toLowerCase().includes(q) ||
        t.artist.toLowerCase().includes(q) ||
        t.album.toLowerCase().includes(q),
    );
  }

  // Sort
  if (sortOption.value === 'title') {
    tracks.sort((a, b) => a.title.localeCompare(b.title));
  } else if (sortOption.value === 'artist') {
    tracks.sort((a, b) => a.artist.localeCompare(b.artist));
  } else if (sortOption.value === 'album') {
    tracks.sort((a, b) => a.album.localeCompare(b.album));
  } else if (sortOption.value === 'duration') {
    tracks.sort((a, b) => (a.duration || 0) - (b.duration || 0));
  }

  return tracks;
});

function setSort(option: 'added' | 'album' | 'artist' | 'duration' | 'title') {
  sortOption.value = option;
  showSortDropdown.value = false;
}

function onPlayAllLiked() {
  if (displayedTracks.value.length) {
    playTracks(displayedTracks.value, 0);
  }
}

function onShuffleLiked() {
  if (displayedTracks.value.length) {
    playTracks(displayedTracks.value, 0);
    shuffleQueue();
  }
}

function onPlayTrack(index: number) {
  if (displayedTracks.value.length) {
    playTracks(displayedTracks.value, index);
  }
}

async function addAlbumToQueue(album: Album) {
  const tracks = await getMediaTracks(album);
  if (tracks) {
    addTracksToQueue(tracks);
  }
}

async function onPlayAlbum(album: Album) {
  const tracks = await getMediaTracks(album);
  if (tracks) {
    playTracks(tracks);
  }
}

function onDownloadAll() {
  for (const track of displayedTracks.value.slice(0, 15)) {
    downloadTrack(track);
  }
}

function goBack() {
  if (window.history.length > 1) {
    router.back();
  } else {
    router.push({ name: ROUTE_NAMES.index });
  }
}

useHead({
  title: pageHeading,
});
</script>

<template>
  <div :class="$style.likedContainer">
    <!-- Spotify Liked Songs Mobile/Desktop View (For Tracks) -->
    <template v-if="isTracksView">
      <!-- Top Search & Sort Header -->
      <div :class="$style.topNavRow">
        <button
          type="button"
          :class="$style.backButton"
          title="Go back"
          aria-label="Go back"
          @click="goBack"
        >
          <PhArrowLeft weight="bold" :class="$style.backIcon" />
        </button>

        <!-- Search Input Pill -->
        <div :class="$style.searchPill">
          <PhMagnifyingGlass weight="bold" :class="$style.searchPillIcon" />
          <input
            v-model="searchQuery"
            type="text"
            placeholder="Find in Liked Songs"
            :class="$style.searchPillInput"
          />
          <button
            v-if="searchQuery"
            type="button"
            :class="$style.clearPillBtn"
            @click="searchQuery = ''"
          >
            <PhX weight="bold" :class="$style.clearPillIcon" />
          </button>
        </div>

        <!-- Sort Pill Button -->
        <div :class="$style.sortWrapper">
          <button
            type="button"
            :class="$style.sortPillBtn"
            @click="showSortDropdown = !showSortDropdown"
          >
            <PhArrowsDownUp weight="bold" :class="$style.sortPillIcon" />
            <span>Sort</span>
          </button>

          <!-- Dropdown -->
          <div v-if="showSortDropdown" :class="$style.sortDropdown">
            <button
              type="button"
              :class="[$style.sortItem, { [$style.activeSortItem]: sortOption === 'added' }]"
              @click="setSort('added')"
            >
              Recently added
            </button>
            <button
              type="button"
              :class="[$style.sortItem, { [$style.activeSortItem]: sortOption === 'title' }]"
              @click="setSort('title')"
            >
              Title (A-Z)
            </button>
            <button
              type="button"
              :class="[$style.sortItem, { [$style.activeSortItem]: sortOption === 'artist' }]"
              @click="setSort('artist')"
            >
              Artist
            </button>
            <button
              type="button"
              :class="[$style.sortItem, { [$style.activeSortItem]: sortOption === 'album' }]"
              @click="setSort('album')"
            >
              Album
            </button>
            <button
              type="button"
              :class="[$style.sortItem, { [$style.activeSortItem]: sortOption === 'duration' }]"
              @click="setSort('duration')"
            >
              Duration
            </button>
          </div>
        </div>
      </div>

      <!-- Main Title & Song Count -->
      <div :class="$style.titleSection">
        <h1 :class="$style.mainTitle">Liked Songs</h1>
        <p :class="$style.songCountText">{{ favourites.tracks.length }} songs</p>
      </div>

      <!-- Action Bar (Download, Shuffle, Big Play) -->
      <div :class="$style.actionBar">
        <div :class="$style.leftActions">
          <button
            type="button"
            :class="$style.iconActionBtn"
            title="Download liked songs"
            aria-label="Download liked songs"
            @click="onDownloadAll"
          >
            <PhArrowCircleDown weight="bold" :class="$style.actionIcon" />
          </button>

          <RefreshButton :status @refresh="refresh" />
        </div>

        <div :class="$style.rightActions">
          <!-- Shuffle Button -->
          <button
            type="button"
            :class="$style.shuffleActionBtn"
            title="Shuffle liked songs"
            aria-label="Shuffle liked songs"
            :disabled="!displayedTracks.length"
            @click="onShuffleLiked"
          >
            <PhShuffle weight="bold" :class="$style.shuffleActionIcon" />
          </button>

          <!-- Big Solid Green Play Button -->
          <button
            type="button"
            :class="$style.bigGreenPlayBtn"
            title="Play liked songs"
            aria-label="Play liked songs"
            :disabled="!displayedTracks.length"
            @click="onPlayAllLiked"
          >
            <PhPlay weight="fill" :class="$style.bigPlayIcon" />
          </button>
        </div>
      </div>

      <!-- "Add to this playlist" Button Row -->
      <NuxtLink
        :to="{
          name: ROUTE_NAMES.search,
          params: {
            [ROUTE_PARAM_KEYS.search.mediaType]: ROUTE_MEDIA_TYPE_PARAMS.Tracks,
            [ROUTE_PARAM_KEYS.search.query]: '',
          },
        }"
        :class="$style.addPlaylistRow"
      >
        <div :class="$style.addPlusBox">
          <PhPlus weight="bold" :class="$style.addPlusIcon" />
        </div>
        <span :class="$style.addPlaylistText">Add to this playlist</span>
      </NuxtLink>

      <!-- Tracklist Content -->
      <LoadingData variant="list" :status>
        <div v-if="displayedTracks.length" :class="$style.tracklistWrapper">
          <LikedTrackRow
            v-for="(track, index) in displayedTracks"
            :key="track.id"
            :track
            @addToPlaylist="addToPlaylistModal(track.id)"
            @addToQueue="addTrackToQueue(track)"
            @downloadMedia="downloadTrack(track)"
            @mediaInformation="openTrackDetailsModal(track)"
            @playTrack="onPlayTrack(index)"
          />
        </div>

        <NoMediaMessage
          v-else
          :icon="FALLBACK_ICON_BY_TYPE.track"
          message="No matching liked songs found."
        />
      </LoadingData>
    </template>

    <!-- Standard Views for Liked Albums / Liked Artists -->
    <template v-else>
      <HeaderWithAction>
        <h1>{{ pageHeading }}</h1>

        <template #actions>
          <RefreshButton :status @refresh="refresh" />
        </template>
      </HeaderWithAction>

      <PageNavigation :navigation="FAVOURITES_NAVIGATION" class="mBM" />

      <LoadingData :class="viewLayout" :status>
        <!-- Liked Albums -->
        <template v-if="isAlbumsView">
          <AlbumList
            v-if="favourites.albums.length"
            :albums="favourites.albums"
            @addToQueue="addAlbumToQueue"
            @dragStart="dragStart"
            @mediaInformation="openAlbumDetailsModal"
            @playAlbum="onPlayAlbum"
          />
          <NoMediaMessage
            v-else
            :icon="FALLBACK_ICON_BY_TYPE.noMedia"
            message="No liked albums yet."
          />
        </template>

        <!-- Liked Artists -->
        <template v-else-if="isArtistsView">
          <ArtistList
            v-if="favourites.artists.length"
            :artists="favourites.artists"
          />
          <NoMediaMessage
            v-else
            :icon="FALLBACK_ICON_BY_TYPE.noMedia"
            message="No liked artists yet."
          />
        </template>
      </LoadingData>
    </template>
  </div>
</template>

<style module>
.likedContainer {
  width: 100%;
  padding-bottom: 30px;
}

.topNavRow {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 20px;
  width: 100%;
}

.backButton {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 38px;
  height: 38px;
  background: transparent;
  border: none;
  color: #ffffff;
  cursor: pointer;
  border-radius: 50%;
  touch-action: manipulation;
  -webkit-tap-highlight-color: transparent;
  transition: background-color 0.12s ease, transform 0.08s ease;

  &:hover {
    background-color: rgba(255, 255, 255, 0.1);
  }

  &:active {
    transform: scale(0.92);
  }
}

.backIcon {
  width: 22px;
  height: 22px;
}

.searchPill {
  display: flex;
  align-items: center;
  gap: 8px;
  flex: 1;
  height: 38px;
  padding: 0 12px;
  background-color: rgba(255, 255, 255, 0.12);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 8px;
  backdrop-filter: blur(10px);
}

.searchPillIcon {
  width: 16px;
  height: 16px;
  color: #a1a1aa;
  flex-shrink: 0;
}

.searchPillInput {
  flex: 1;
  background: transparent;
  border: none;
  color: #ffffff;
  font-size: 0.88rem;
  font-weight: 500;
  outline: none;

  &::placeholder {
    color: #a1a1aa;
  }
}

.clearPillBtn {
  display: flex;
  align-items: center;
  justify-content: center;
  background: transparent;
  border: none;
  color: #a1a1aa;
  cursor: pointer;
  padding: 2px;

  &:hover {
    color: #ffffff;
  }
}

.clearPillIcon {
  width: 14px;
  height: 14px;
}

.sortWrapper {
  position: relative;
}

.sortPillBtn {
  display: flex;
  align-items: center;
  gap: 6px;
  height: 38px;
  padding: 0 14px;
  background-color: rgba(255, 255, 255, 0.12);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 8px;
  color: #ffffff;
  font-size: 0.85rem;
  font-weight: 700;
  cursor: pointer;
  touch-action: manipulation;
  -webkit-tap-highlight-color: transparent;
  transition: background-color 0.12s ease;

  &:hover {
    background-color: rgba(255, 255, 255, 0.2);
  }
}

.sortPillIcon {
  width: 15px;
  height: 15px;
}

.sortDropdown {
  position: absolute;
  top: 100%;
  right: 0;
  z-index: 30;
  margin-top: 6px;
  width: 160px;
  background-color: #1a1b24;
  border: 1px solid rgba(255, 255, 255, 0.14);
  border-radius: 8px;
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.85), 2px 2px 0px #000000;
  overflow: hidden;
}

.sortItem {
  display: flex;
  align-items: center;
  width: 100%;
  padding: 10px 14px;
  background: transparent;
  border: none;
  color: #d4d4d8;
  font-size: 0.85rem;
  font-weight: 600;
  cursor: pointer;
  text-align: left;
  transition: background-color 0.1s ease, color 0.1s ease;

  &:hover {
    background-color: #252636;
    color: #ffffff;
  }
}

.activeSortItem {
  color: #22c55e !important;
  font-weight: 800 !important;
  background-color: rgba(34, 197, 94, 0.08) !important;
}

.titleSection {
  margin-bottom: 16px;
}

.mainTitle {
  font-size: 2.2rem;
  font-weight: 900;
  color: #ffffff;
  letter-spacing: -0.03em;
  line-height: 1.1;
  margin: 0 0 4px;
}

.songCountText {
  font-size: 0.88rem;
  font-weight: 600;
  color: #a1a1aa;
  margin: 0;
}

.actionBar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 20px;
}

.leftActions {
  display: flex;
  align-items: center;
  gap: 12px;
}

.iconActionBtn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 36px;
  height: 36px;
  background: transparent;
  border: none;
  color: #a1a1aa;
  cursor: pointer;
  border-radius: 50%;
  touch-action: manipulation;
  transition: color 0.12s ease, transform 0.08s ease;

  &:hover {
    color: #ffffff;
    transform: scale(1.08);
  }

  &:active {
    transform: scale(0.92);
  }
}

.actionIcon {
  width: 24px;
  height: 24px;
}

.rightActions {
  display: flex;
  align-items: center;
  gap: 16px;
}

.shuffleActionBtn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 36px;
  height: 36px;
  background: transparent;
  border: none;
  color: #a1a1aa;
  cursor: pointer;
  border-radius: 50%;
  touch-action: manipulation;
  transition: color 0.12s ease, transform 0.08s ease;

  &:hover:not(:disabled) {
    color: #22c55e;
    transform: scale(1.08);
  }

  &:active:not(:disabled) {
    transform: scale(0.92);
  }

  &:disabled {
    opacity: 0.35;
    cursor: not-allowed;
  }
}

.shuffleActionIcon {
  width: 24px;
  height: 24px;
}

.bigGreenPlayBtn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 52px;
  height: 52px;
  border-radius: 50%;
  background-color: #22c55e;
  color: #000000;
  border: none;
  box-shadow: 0 8px 20px rgba(34, 197, 94, 0.4), 2px 2px 0px #000000;
  cursor: pointer;
  touch-action: manipulation;
  -webkit-tap-highlight-color: transparent;
  will-change: transform, background-color;
  transition: transform 0.1s cubic-bezier(0.2, 0, 0, 1), background-color 0.12s ease;

  &:hover:not(:disabled) {
    background-color: #1ed760;
    transform: scale(1.08);
  }

  &:active:not(:disabled) {
    transform: scale(0.92);
  }

  &:disabled {
    opacity: 0.35;
    cursor: not-allowed;
  }
}

.bigPlayIcon {
  width: 24px;
  height: 24px;
  margin-left: 3px;
}

.addPlaylistRow {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 10px 12px;
  margin-bottom: 12px;
  border-radius: 8px;
  text-decoration: none;
  cursor: pointer;
  touch-action: manipulation;
  transition: background-color 0.12s ease;

  &:hover {
    background-color: rgba(255, 255, 255, 0.06);
  }

  &:active {
    transform: scale(0.99);
  }
}

.addPlusBox {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 48px;
  height: 48px;
  background-color: #1a1b24;
  border: 1px solid rgba(255, 255, 255, 0.12);
  border-radius: 4px;
  color: #ffffff;
}

.addPlusIcon {
  width: 22px;
  height: 22px;
}

.addPlaylistText {
  font-size: 0.95rem;
  font-weight: 700;
  color: #ffffff;
}

.tracklistWrapper {
  display: flex;
  flex-direction: column;
  gap: 2px;
}
</style>
