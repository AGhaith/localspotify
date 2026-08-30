<script setup lang="ts">
import TracklistMixed from '@/components/tracklist/TracklistMixed.vue';
import ButtonLink from '@/components/ui/ButtonLink.vue';
import EntryHeader from '@/components/ui/EntryHeader.vue';
import NoMediaMessage from '@/components/notification/NoMediaMessage.vue';

const {
  clearAllDownloads,
  downloadedTrackIds,
  downloadedPlaylistIds,
  downloadedAlbumIds,
  getDownloadedAlbums,
  getDownloadedPlaylists,
  getDownloadedTracks,
  getStorageUsage,
  removeDownloadedAlbum,
  removeDownloadedPlaylist,
  removeDownloadedTrack,
} = useOffline();

const { addTracksToQueue, addTrackToQueue, playTracks, playTracksShuffled } = useAudioPlayer();
const { addToPlaylistModal } = usePlaylist();
const { openTrackDetailsModal } = useMediaInformation();
const { dragStart } = useDragAndDrop();

const activeTab = ref<'tracks' | 'playlists' | 'albums'>('tracks');
const downloadedTracks = ref<PlayableTrack[]>([]);
const downloadedPlaylists = ref<OfflinePlaylistRecord[]>([]);
const downloadedAlbums = ref<OfflineAlbumRecord[]>([]);
const storageUsage = ref({ bytes: 0, formatted: '0 MB' });
const isLoading = ref(true);

async function loadOfflineData() {
  isLoading.value = true;
  downloadedTracks.value = await getDownloadedTracks();
  downloadedPlaylists.value = await getDownloadedPlaylists();
  downloadedAlbums.value = await getDownloadedAlbums();
  storageUsage.value = await getStorageUsage();
  isLoading.value = false;
}

onMounted(() => {
  loadOfflineData();
});

watch([downloadedTrackIds, downloadedPlaylistIds, downloadedAlbumIds], () => {
  loadOfflineData();
});

function onPlayTrack(index: number) {
  if (downloadedTracks.value.length) {
    playTracks(downloadedTracks.value, index);
  }
}

async function handleClearAll() {
  if (confirm('Are you sure you want to delete all offline music downloads?')) {
    await clearAllDownloads();
    await loadOfflineData();
  }
}

useHead({
  title: 'Downloads - Offline Music',
});
</script>

<template>
  <div class="p-4 md:p-8 max-w-7xl mx-auto space-y-8">
    <!-- Neo-Brutalist Hero Header -->
    <div class="border-3 border-black bg-neo-card p-6 md:p-8 rounded-2xl shadow-neo transition-all">
      <div class="flex flex-col md:flex-row md:items-center justify-between gap-6">
        <div>
          <div class="inline-flex items-center gap-2 px-3 py-1 bg-neo-green text-black font-extrabold text-xs tracking-wider uppercase border-2 border-black rounded-lg shadow-neo-sm mb-3">
            <component :is="ICONS.check" class="w-3.5 h-3.5" />
            Spotify-Style Offline Storage
          </div>
          <h1 class="text-3xl md:text-5xl font-black font-display tracking-tight text-white">
            Offline Downloads
          </h1>
          <p class="text-secondary-font-color font-medium mt-2 text-sm md:text-base">
            Listen to your downloaded music library anywhere without an internet connection.
          </p>
        </div>

        <!-- Quick Stats Cards -->
        <div class="flex flex-wrap gap-3">
          <div class="bg-neo-secondary border-2 border-black p-3.5 rounded-xl shadow-neo-sm min-w-[110px] text-center">
            <div class="text-xs uppercase font-extrabold text-secondary-font-color">Tracks</div>
            <div class="text-2xl font-black text-neo-green font-display">{{ downloadedTracks.length }}</div>
          </div>
          <div class="bg-neo-secondary border-2 border-black p-3.5 rounded-xl shadow-neo-sm min-w-[110px] text-center">
            <div class="text-xs uppercase font-extrabold text-secondary-font-color">Playlists</div>
            <div class="text-2xl font-black text-neo-yellow font-display">{{ downloadedPlaylists.length }}</div>
          </div>
          <div class="bg-neo-secondary border-2 border-black p-3.5 rounded-xl shadow-neo-sm min-w-[110px] text-center">
            <div class="text-xs uppercase font-extrabold text-secondary-font-color">Storage</div>
            <div class="text-xl font-black text-neo-purple font-display mt-0.5">{{ storageUsage.formatted }}</div>
          </div>
        </div>
      </div>

      <!-- Action Buttons -->
      <div v-if="downloadedTracks.length" class="flex flex-wrap items-center gap-3 mt-6 pt-6 border-t-2 border-white/10">
        <ButtonLink
          class="neoButtonPrimary"
          :icon="ICONS.play"
          @click="playTracks(downloadedTracks)"
        >
          Play All Offline
        </ButtonLink>
        <ButtonLink
          class="neoButton"
          :icon="ICONS.shuffle"
          @click="playTracksShuffled(downloadedTracks)"
        >
          Shuffle
        </ButtonLink>
        <ButtonLink
          class="neoButton text-neo-pink hover:bg-neo-pink/20 ml-auto"
          :icon="ICONS.clear"
          @click="handleClearAll"
        >
          Clear All Downloads
        </ButtonLink>
      </div>
    </div>

    <!-- Filter Tabs -->
    <div class="flex items-center gap-3 border-b-2 border-black/20 pb-4">
      <button
        class="px-5 py-2 font-display font-extrabold rounded-xl border-2 transition-all duration-150"
        :class="activeTab === 'tracks' ? 'bg-neo-green text-black border-black shadow-neo-sm translate-y-[-2px]' : 'bg-neo-card text-white/70 border-white/10 hover:border-white/30'"
        @click="activeTab = 'tracks'"
      >
        Downloaded Songs ({{ downloadedTracks.length }})
      </button>
      <button
        class="px-5 py-2 font-display font-extrabold rounded-xl border-2 transition-all duration-150"
        :class="activeTab === 'playlists' ? 'bg-neo-yellow text-black border-black shadow-neo-sm translate-y-[-2px]' : 'bg-neo-card text-white/70 border-white/10 hover:border-white/30'"
        @click="activeTab = 'playlists'"
      >
        Playlists ({{ downloadedPlaylists.length }})
      </button>
      <button
        class="px-5 py-2 font-display font-extrabold rounded-xl border-2 transition-all duration-150"
        :class="activeTab === 'albums' ? 'bg-neo-purple text-white border-black shadow-neo-sm translate-y-[-2px]' : 'bg-neo-card text-white/70 border-white/10 hover:border-white/30'"
        @click="activeTab = 'albums'"
      >
        Albums ({{ downloadedAlbums.length }})
      </button>
    </div>

    <!-- Tab 1: Downloaded Tracks -->
    <div v-if="activeTab === 'tracks'">
      <TracklistMixed
        v-if="downloadedTracks.length"
        :tracks="downloadedTracks"
        @addToPlaylist="addToPlaylistModal"
        @addToQueue="addTrackToQueue"
        @downloadMedia="downloadTrack"
        @dragStart="dragStart"
        @mediaInformation="openTrackDetailsModal"
        @playTrack="onPlayTrack"
      />
      <div v-else class="text-center py-16 bg-neo-card border-2 border-black rounded-2xl shadow-neo-sm p-8">
        <component :is="ICONS.download" class="w-16 h-16 mx-auto text-white/30 mb-4" />
        <h3 class="text-xl font-bold font-display text-white">No Downloaded Songs Yet</h3>
        <p class="text-secondary-font-color mt-2 max-w-md mx-auto">
          Browse your playlists, albums, or tracks and click the Download button to save music for offline listening!
        </p>
      </div>
    </div>

    <!-- Tab 2: Downloaded Playlists -->
    <div v-else-if="activeTab === 'playlists'">
      <div v-if="downloadedPlaylists.length" class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6">
        <div
          v-for="p in downloadedPlaylists"
          :key="p.id"
          class="bg-neo-card border-3 border-black rounded-2xl p-5 shadow-neo hover:shadow-neo-lg hover:-translate-y-1 transition-all duration-150 flex flex-col justify-between"
        >
          <div>
            <div class="w-full aspect-square bg-neo-secondary border-2 border-black rounded-xl overflow-hidden mb-4 relative shadow-neo-sm">
              <img
                v-if="p.images && p.images[0]"
                :src="p.images[0]"
                :alt="p.name"
                class="w-full h-full object-cover"
              />
              <div v-else class="w-full h-full flex items-center justify-center text-white/20">
                <component :is="ICONS.playlist" class="w-12 h-12" />
              </div>
              <span class="absolute top-2 right-2 bg-neo-green text-black font-extrabold text-[10px] px-2 py-0.5 rounded-md border border-black shadow-neo-sm">
                OFFLINE
              </span>
            </div>
            <h4 class="font-display font-black text-lg text-white truncate">{{ p.name }}</h4>
            <p class="text-xs text-secondary-font-color font-semibold mt-1">{{ p.trackCount }} Tracks • {{ p.formattedDuration || 'Offline' }}</p>
          </div>

          <div class="flex items-center gap-2 mt-5 pt-4 border-t border-white/10">
            <NuxtLink
              :to="{ name: ROUTE_NAMES.playlist, params: { [ROUTE_PARAM_KEYS.playlist.id]: p.id } }"
              class="neoButtonPrimary flex-1 text-center py-2 text-xs"
            >
              Open
            </NuxtLink>
            <button
              class="neoButton text-neo-pink p-2"
              title="Remove Offline Download"
              @click="removeDownloadedPlaylist(p.id)"
            >
              <component :is="ICONS.clear" class="w-4 h-4" />
            </button>
          </div>
        </div>
      </div>
      <div v-else class="text-center py-16 bg-neo-card border-2 border-black rounded-2xl shadow-neo-sm p-8">
        <component :is="ICONS.playlist" class="w-16 h-16 mx-auto text-white/30 mb-4" />
        <h3 class="text-xl font-bold font-display text-white">No Offline Playlists</h3>
        <p class="text-secondary-font-color mt-2 max-w-md mx-auto">
          Open any playlist and tap "Download Playlist" to save the full collection for offline playback.
        </p>
      </div>
    </div>

    <!-- Tab 3: Downloaded Albums -->
    <div v-else-if="activeTab === 'albums'">
      <div v-if="downloadedAlbums.length" class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6">
        <div
          v-for="a in downloadedAlbums"
          :key="a.id"
          class="bg-neo-card border-3 border-black rounded-2xl p-5 shadow-neo hover:shadow-neo-lg hover:-translate-y-1 transition-all duration-150 flex flex-col justify-between"
        >
          <div>
            <div class="w-full aspect-square bg-neo-secondary border-2 border-black rounded-xl overflow-hidden mb-4 relative shadow-neo-sm">
              <img
                v-if="a.images && a.images[0]"
                :src="a.images[0]"
                :alt="a.name"
                class="w-full h-full object-cover"
              />
              <div v-else class="w-full h-full flex items-center justify-center text-white/20">
                <component :is="ICONS.album" class="w-12 h-12" />
              </div>
              <span class="absolute top-2 right-2 bg-neo-green text-black font-extrabold text-[10px] px-2 py-0.5 rounded-md border border-black shadow-neo-sm">
                OFFLINE
              </span>
            </div>
            <h4 class="font-display font-black text-lg text-white truncate">{{ a.name }}</h4>
            <p class="text-xs text-secondary-font-color font-semibold mt-1">{{ a.artist }} • {{ a.trackCount }} Tracks</p>
          </div>

          <div class="flex items-center gap-2 mt-5 pt-4 border-t border-white/10">
            <NuxtLink
              :to="{ name: ROUTE_NAMES.album, params: { [ROUTE_PARAM_KEYS.album.id]: a.id } }"
              class="neoButtonPrimary flex-1 text-center py-2 text-xs"
            >
              Open
            </NuxtLink>
            <button
              class="neoButton text-neo-pink p-2"
              title="Remove Offline Download"
              @click="removeDownloadedAlbum(a.id)"
            >
              <component :is="ICONS.clear" class="w-4 h-4" />
            </button>
          </div>
        </div>
      </div>
      <div v-else class="text-center py-16 bg-neo-card border-2 border-black rounded-2xl shadow-neo-sm p-8">
        <component :is="ICONS.album" class="w-16 h-16 mx-auto text-white/30 mb-4" />
        <h3 class="text-xl font-bold font-display text-white">No Offline Albums</h3>
        <p class="text-secondary-font-color mt-2 max-w-md mx-auto">
          Open any album and tap "Download Album" to save all tracks locally.
        </p>
      </div>
    </div>
  </div>
</template>
