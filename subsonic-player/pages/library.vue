<script setup lang="ts">
import LibraryItemCard from '@/components/library/LibraryItemCard.vue';
import LibraryItemRow, { type LibraryItemData } from '@/components/library/LibraryItemRow.vue';
import LoadingData from '@/components/notification/LoadingData.vue';
import NoMediaMessage from '@/components/notification/NoMediaMessage.vue';
import RefreshButton from '@/components/ui/RefreshButton.vue';
import {
  PhArrowsDownUp,
  PhGridFour,
  PhMagnifyingGlass,
  PhPlus,
  PhRows,
  PhX,
} from '@phosphor-icons/vue';

const { user } = useUser();
const { addPlaylistModal, getPlaylists, playlists } = usePlaylist();
const { getArtists } = useArtist();
const { getRandomAlbums } = useAlbum();
const { favourites, getFavourites } = useFavourite();
const { getPodcasts, podcasts } = usePodcast();
const { showPodcasts } = useSettings();

// UI States
const activeFilter = ref<'album' | 'all' | 'artist' | 'playlist' | 'podcast'>('all');
const sortOption = ref<'added' | 'alphabetical' | 'creator' | 'recents'>('recents');
const showSortMenu = ref(false);
const isGridView = ref(false);
const searchQuery = ref('');
const isSearchOpen = ref(false);

/* istanbul ignore next -- @preserve */
const { data: libraryData, refresh, status } = useAsyncData(
  ASYNC_DATA_KEYS.library,
  async () => {
    const promises: Promise<any>[] = [
      getPlaylists(),
      getArtists(),
      getRandomAlbums(),
      getFavourites(),
    ];

    if (showPodcasts.value) {
      promises.push(getPodcasts());
    }

    const [, artists, randomAlbums, favouritesData] = await Promise.all(promises);

    return {
      artists: artists || [],
      favourites: favouritesData?.value || { albums: [], artists: [], tracks: [] },
      podcasts: podcasts.value || [],
      randomAlbums: randomAlbums || [],
    };
  },
  {
    default: () => ({
      artists: [],
      favourites: { albums: [], artists: [], tracks: [] },
      podcasts: [],
      randomAlbums: [],
    }),
    getCachedData: (key, nuxtApp, ctx) => {
      if (ctx.cause === 'refresh:manual') {
        return undefined;
      }
      return nuxtApp.payload.data[key] || nuxtApp.static.data[key];
    },
  },
);

const username = computed(() => user.value?.username || 'You');

// Build unified library items
const allLibraryItems = computed<LibraryItemData[]>(() => {
  const items: LibraryItemData[] = [];

  // 1. Liked Songs (Always top pinned)
  const trackCount = favourites.value?.tracks?.length || libraryData.value.favourites?.tracks?.length || 0;
  items.push({
    id: 'liked-songs',
    isPinned: true,
    subtitle: `Playlist • ${username.value}`,
    title: 'Liked Songs',
    to: {
      name: ROUTE_NAMES.favourites,
      params: {
        [ROUTE_PARAM_KEYS.favourites.mediaType]: ROUTE_MEDIA_TYPE_PARAMS.Tracks,
      },
    },
    type: 'liked-songs',
  });

  // 2. Playlists
  if (playlists.value?.length) {
    for (const pl of playlists.value) {
      if (pl.id === RANDOM_PLAYLIST.id) continue;
      items.push({
        id: `playlist-${pl.id}`,
        image: pl.images?.[0] || undefined,
        isPinned: pl.name.toLowerCase().includes('pinned') || false,
        subtitle: `Playlist • ${pl.owner || username.value}`,
        title: pl.name,
        to: {
          name: ROUTE_NAMES.playlist,
          params: {
            [ROUTE_PARAM_KEYS.playlist.id]: pl.id,
          },
        },
        type: 'playlist',
      });
    }
  }

  // 3. Artists
  const artistList = libraryData.value.artists || [];
  for (const art of artistList) {
    items.push({
      id: `artist-${art.id}`,
      image: art.image || undefined,
      isCircle: true,
      subtitle: 'Artist',
      title: art.name,
      to: {
        name: ROUTE_NAMES.artist,
        params: {
          [ROUTE_PARAM_KEYS.artist.id]: art.id,
        },
      },
      type: 'artist',
    });
  }

  // 4. Albums
  const albumList = libraryData.value.randomAlbums || [];
  for (const alb of albumList) {
    items.push({
      id: `album-${alb.id}`,
      image: alb.image || undefined,
      subtitle: `Album • ${alb.artist || 'Various'}`,
      title: alb.name,
      to: {
        name: ROUTE_NAMES.album,
        params: {
          [ROUTE_PARAM_KEYS.album.id]: alb.id,
        },
      },
      type: 'album',
    });
  }

  // 5. Podcasts (if available)
  if (showPodcasts.value && podcasts.value?.length) {
    for (const pod of podcasts.value) {
      items.push({
        id: `podcast-${pod.id}`,
        image: pod.image || undefined,
        subtitle: `Podcast • ${pod.channel || 'Show'}`,
        title: pod.title,
        to: {
          name: ROUTE_NAMES.podcast,
          params: {
            [ROUTE_PARAM_KEYS.podcast.id]: pod.id,
          },
        },
        type: 'podcast',
      });
    }
  }

  return items;
});

// Filter & Sort Items
const filteredItems = computed(() => {
  let list = allLibraryItems.value;

  // Type filter
  if (activeFilter.value === 'playlist') {
    list = list.filter((i) => i.type === 'playlist' || i.type === 'liked-songs');
  } else if (activeFilter.value === 'album') {
    list = list.filter((i) => i.type === 'album');
  } else if (activeFilter.value === 'artist') {
    list = list.filter((i) => i.type === 'artist');
  } else if (activeFilter.value === 'podcast') {
    list = list.filter((i) => i.type === 'podcast');
  }

  // Search filter
  if (searchQuery.value.trim()) {
    const q = searchQuery.value.toLowerCase().trim();
    list = list.filter(
      (i) => i.title.toLowerCase().includes(q) || i.subtitle.toLowerCase().includes(q),
    );
  }

  // Sort
  if (sortOption.value === 'alphabetical') {
    list = [...list].sort((a, b) => a.title.localeCompare(b.title));
  } else if (sortOption.value === 'creator') {
    list = [...list].sort((a, b) => a.subtitle.localeCompare(b.subtitle));
  }

  return list;
});

function toggleFilter(filter: 'album' | 'artist' | 'playlist' | 'podcast') {
  if (activeFilter.value === filter) {
    activeFilter.value = 'all';
  } else {
    activeFilter.value = filter;
  }
}

function setSort(option: 'added' | 'alphabetical' | 'creator' | 'recents') {
  sortOption.value = option;
  showSortMenu.value = false;
}

function toggleSearch() {
  isSearchOpen.value = !isSearchOpen.value;
  if (!isSearchOpen.value) {
    searchQuery.value = '';
  }
}

useHead({
  title: 'Your Library',
});
</script>

<template>
  <div :class="$style.libraryContainer">
    <!-- Header -->
    <header :class="$style.libraryHeader">
      <div :class="$style.headerLeft">
        <h1 :class="$style.libraryTitle">Your Library</h1>
      </div>

      <div :class="$style.headerActions">
        <!-- Search Toggle -->
        <button
          type="button"
          :class="[$style.actionBtn, { [$style.activeActionBtn]: isSearchOpen }]"
          title="Search in Your Library"
          aria-label="Search in Your Library"
          @click="toggleSearch"
        >
          <PhMagnifyingGlass weight="bold" :class="$style.actionIcon" />
        </button>

        <!-- Create Playlist -->
        <button
          type="button"
          :class="$style.actionBtn"
          title="Create Playlist"
          aria-label="Create Playlist"
          @click="addPlaylistModal"
        >
          <PhPlus weight="bold" :class="$style.actionIcon" />
        </button>

        <!-- Refresh Data -->
        <RefreshButton :status @refresh="refresh" />
      </div>
    </header>

    <!-- Search Input (When Opened) -->
    <div v-if="isSearchOpen" :class="$style.searchBarWrapper">
      <PhMagnifyingGlass weight="bold" :class="$style.searchIcon" />
      <input
        v-model="searchQuery"
        type="text"
        placeholder="Search in Your Library"
        :class="$style.searchInput"
        autofocus
      />
      <button
        v-if="searchQuery"
        type="button"
        :class="$style.clearSearchBtn"
        @click="searchQuery = ''"
      >
        <PhX weight="bold" :class="$style.clearIcon" />
      </button>
    </div>

    <!-- Filter Chips Row -->
    <nav :class="$style.filterRow" aria-label="Library filter categories">
      <button
        type="button"
        :class="[
          $style.filterChip,
          {
            [$style.activeChip]: activeFilter === 'playlist',
          },
        ]"
        @click="toggleFilter('playlist')"
      >
        Playlists
      </button>

      <button
        v-if="showPodcasts"
        type="button"
        :class="[
          $style.filterChip,
          {
            [$style.activeChip]: activeFilter === 'podcast',
          },
        ]"
        @click="toggleFilter('podcast')"
      >
        Podcasts
      </button>

      <button
        type="button"
        :class="[
          $style.filterChip,
          {
            [$style.activeChip]: activeFilter === 'album',
          },
        ]"
        @click="toggleFilter('album')"
      >
        Albums
      </button>

      <button
        type="button"
        :class="[
          $style.filterChip,
          {
            [$style.activeChip]: activeFilter === 'artist',
          },
        ]"
        @click="toggleFilter('artist')"
      >
        Artists
      </button>
    </nav>

    <!-- Subheader Controls (Sort & View Toggle) -->
    <div :class="$style.controlsBar">
      <!-- Sort By Button -->
      <div :class="$style.sortWrapper">
        <button
          type="button"
          :class="$style.sortBtn"
          @click="showSortMenu = !showSortMenu"
        >
          <PhArrowsDownUp weight="bold" :class="$style.sortIcon" />
          <span>
            {{
              sortOption === 'recents'
                ? 'Recents'
                : sortOption === 'alphabetical'
                  ? 'Alphabetical'
                  : sortOption === 'creator'
                    ? 'Creator'
                    : 'Recently added'
            }}
          </span>
        </button>

        <!-- Sort Menu Dropdown -->
        <div v-if="showSortMenu" :class="$style.sortDropdown">
          <button
            type="button"
            :class="[$style.sortOption, { [$style.activeSortOption]: sortOption === 'recents' }]"
            @click="setSort('recents')"
          >
            Recents
          </button>
          <button
            type="button"
            :class="[$style.sortOption, { [$style.activeSortOption]: sortOption === 'added' }]"
            @click="setSort('added')"
          >
            Recently added
          </button>
          <button
            type="button"
            :class="[$style.sortOption, { [$style.activeSortOption]: sortOption === 'alphabetical' }]"
            @click="setSort('alphabetical')"
          >
            Alphabetical
          </button>
          <button
            type="button"
            :class="[$style.sortOption, { [$style.activeSortOption]: sortOption === 'creator' }]"
            @click="setSort('creator')"
          >
            Creator
          </button>
        </div>
      </div>

      <!-- View Switcher (List vs Grid) -->
      <button
        type="button"
        :class="$style.viewToggleBtn"
        :title="isGridView ? 'Switch to List view' : 'Switch to Grid view'"
        aria-label="Toggle layout view"
        @click="isGridView = !isGridView"
      >
        <PhRows v-if="isGridView" weight="bold" :class="$style.viewIcon" />
        <PhGridFour v-else weight="bold" :class="$style.viewIcon" />
      </button>
    </div>

    <!-- Main Content List / Grid -->
    <LoadingData :variant="isGridView ? 'grid' : 'list'" :status>
      <template v-if="filteredItems.length">
        <!-- List View -->
        <div v-if="!isGridView" :class="$style.itemsList">
          <LibraryItemRow
            v-for="item in filteredItems"
            :key="item.id"
            :item
          />
        </div>

        <!-- Grid View -->
        <div v-else :class="$style.itemsGrid">
          <LibraryItemCard
            v-for="item in filteredItems"
            :key="item.id"
            :item
          />
        </div>
      </template>

      <NoMediaMessage
        v-else
        :icon="FALLBACK_ICON_BY_TYPE.noMedia"
        message="No items found in your library."
      />
    </LoadingData>
  </div>
</template>

<style module>
.libraryContainer {
  width: 100%;
  padding-bottom: 24px;
}

.libraryHeader {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  margin-bottom: 18px;
}

.headerLeft {
  display: flex;
  align-items: center;
}

.libraryTitle {
  font-size: 1.55rem;
  font-weight: 800;
  color: #ffffff;
  letter-spacing: -0.02em;
  margin: 0;
}

.headerActions {
  display: flex;
  align-items: center;
  gap: 10px;
}

.actionBtn {
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
  will-change: transform, border-color, color;
  transition: transform 0.08s cubic-bezier(0.2, 0, 0, 1),
    border-color 0.12s ease,
    background-color 0.12s ease,
    color 0.12s ease;

  &:hover {
    background-color: #262736;
    border-color: #22c55e;
    color: #22c55e;
    transform: scale(1.08) translateY(-1px);
    box-shadow: 3px 3px 0px #000000, 0 0 12px rgba(34, 197, 94, 0.3);
  }

  &:active {
    transform: scale(0.92) translateY(1px);
    box-shadow: 1px 1px 0px #000000;
  }
}

.activeActionBtn {
  border-color: #22c55e !important;
  color: #22c55e !important;
  background-color: #1f2a24 !important;
}

.actionIcon {
  width: 18px;
  height: 18px;
}

.searchBarWrapper {
  display: flex;
  align-items: center;
  gap: 10px;
  height: 42px;
  padding: 0 14px;
  margin-bottom: 16px;
  background-color: #1a1b24;
  border: 1px solid rgba(255, 255, 255, 0.16);
  border-radius: 8px;
  box-shadow: 2px 2px 0px #000000;
}

.searchIcon {
  width: 18px;
  height: 18px;
  color: #71717a;
  flex-shrink: 0;
}

.searchInput {
  flex: 1;
  background: transparent;
  border: none;
  color: #ffffff;
  font-size: 0.9rem;
  font-weight: 500;
  outline: none;

  &::placeholder {
    color: #71717a;
  }
}

.clearSearchBtn {
  display: flex;
  align-items: center;
  justify-content: center;
  background: transparent;
  border: none;
  color: #71717a;
  cursor: pointer;
  padding: 4px;

  &:hover {
    color: #ffffff;
  }
}

.clearIcon {
  width: 14px;
  height: 14px;
}

.filterRow {
  display: flex;
  align-items: center;
  gap: 8px;
  overflow-x: auto;
  scrollbar-width: none;
  -webkit-overflow-scrolling: touch;
  padding: 2px 0 14px;
  touch-action: manipulation;

  &::-webkit-scrollbar {
    display: none;
  }
}

.filterChip {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  height: 32px;
  padding: 0 14px;
  background-color: #24252f;
  color: #ffffff;
  font-size: 0.85rem;
  font-weight: 600;
  letter-spacing: -0.01em;
  border-radius: 9999px;
  border: 1px solid rgba(255, 255, 255, 0.08);
  cursor: pointer;
  user-select: none;
  touch-action: manipulation;
  -webkit-tap-highlight-color: transparent;
  box-shadow: 2px 2px 0px #000000;
  transition: transform 0.08s cubic-bezier(0.2, 0, 0, 1),
    background-color 0.1s ease,
    border-color 0.1s ease,
    box-shadow 0.1s ease;

  &:hover {
    background-color: #323442;
    border-color: rgba(255, 255, 255, 0.2);
    transform: translateY(-1px);
  }

  &:active {
    transform: scale(0.93) translateY(1px);
    box-shadow: 1px 1px 0px #000000;
  }
}

.activeChip {
  background-color: #22c55e !important;
  color: #000000 !important;
  font-weight: 800 !important;
  border-color: #22c55e !important;
  box-shadow: 3px 3px 0px #000000, 0 0 14px rgba(34, 197, 94, 0.35) !important;

  &:hover {
    background-color: #1ed760 !important;
  }
}

.controlsBar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 12px;
  padding: 4px 2px;
}

.sortWrapper {
  position: relative;
}

.sortBtn {
  display: flex;
  align-items: center;
  gap: 6px;
  background: transparent;
  border: none;
  color: #ffffff;
  font-size: 0.85rem;
  font-weight: 700;
  letter-spacing: -0.01em;
  cursor: pointer;
  padding: 4px 6px;
  border-radius: 6px;
  touch-action: manipulation;
  -webkit-tap-highlight-color: transparent;
  transition: color 0.12s ease, background-color 0.12s ease;

  &:hover {
    color: #22c55e;
    background-color: rgba(255, 255, 255, 0.06);
  }
}

.sortIcon {
  width: 16px;
  height: 16px;
}

.sortDropdown {
  position: absolute;
  top: 100%;
  left: 0;
  z-index: 20;
  margin-top: 6px;
  width: 170px;
  background-color: #1a1b24;
  border: 1px solid rgba(255, 255, 255, 0.12);
  border-radius: 8px;
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.8), 3px 3px 0px #000000;
  overflow: hidden;
}

.sortOption {
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

.activeSortOption {
  color: #22c55e !important;
  font-weight: 800 !important;
  background-color: rgba(34, 197, 94, 0.08) !important;
}

.viewToggleBtn {
  display: flex;
  align-items: center;
  justify-content: center;
  background: transparent;
  border: none;
  color: #d4d4d8;
  cursor: pointer;
  padding: 6px;
  border-radius: 6px;
  touch-action: manipulation;
  -webkit-tap-highlight-color: transparent;
  transition: color 0.12s ease, background-color 0.12s ease, transform 0.08s ease;

  &:hover {
    color: #22c55e;
    background-color: rgba(255, 255, 255, 0.06);
    transform: scale(1.08);
  }

  &:active {
    transform: scale(0.92);
  }
}

.viewIcon {
  width: 20px;
  height: 20px;
}

.itemsList {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.itemsGrid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 12px;

  @media (--tablet-up) {
    grid-template-columns: repeat(3, 1fr);
    gap: 14px;
  }

  @media (width >= 1200px) {
    grid-template-columns: repeat(5, 1fr);
    gap: 16px;
  }
}
</style>
