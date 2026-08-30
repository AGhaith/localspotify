<script setup lang="ts">
import CompactRecentCard, { type RecentItem } from '@/components/home/CompactRecentCard.vue';

const props = defineProps<{
  favourites: Favourite;
  frequentAlbums: Album[];
  newestAlbums: Album[];
  playlists?: Playlist[];
  recentAlbums: Album[];
}>();

const emit = defineEmits<{
  playAlbum: [album: Album];
  playTracks: [tracks: Track[]];
}>();

const { getMediaTracks } = useMediaTracks();
const { playTracks: playAudioTracks } = useAudioPlayer();

const recentItems = computed<RecentItem[]>(() => {
  const items: RecentItem[] = [];

  // 1. Liked Songs tile (always first)
  items.push({
    id: 'liked-songs',
    title: 'Liked Songs',
    to: {
      name: ROUTE_NAMES.favourites,
      params: {
        [ROUTE_PARAM_KEYS.favourites.mediaType]: ROUTE_MEDIA_TYPE_PARAMS.Tracks,
      },
    },
    tracks: props.favourites?.tracks || [],
    type: 'liked-songs',
  });

  // 2. Add Recent / Frequent Playlists
  if (props.playlists?.length) {
    for (const pl of props.playlists.slice(0, 3)) {
      items.push({
        id: `playlist-${pl.id}`,
        image: pl.images?.[0] || undefined,
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

  // 3. Add Recent / Frequent Albums
  const albumPool = [...(props.recentAlbums || []), ...(props.frequentAlbums || []), ...(props.newestAlbums || [])];
  const seenAlbumIds = new Set<string>();

  for (const alb of albumPool) {
    if (!seenAlbumIds.has(alb.id) && items.length < 8) {
      seenAlbumIds.add(alb.id);
      items.push({
        id: `album-${alb.id}`,
        image: alb.image || undefined,
        title: alb.name,
        to: {
          name: ROUTE_NAMES.album,
          params: {
            [ROUTE_PARAM_KEYS.album.id]: alb.id,
          },
        },
        tracks: alb.tracks,
        type: 'album',
      });
    }
  }

  // 4. Add Top / Favourite Artists
  if (props.favourites?.artists?.length) {
    for (const art of props.favourites.artists.slice(0, 2)) {
      if (items.length < 8) {
        items.push({
          id: `artist-${art.id}`,
          image: art.image || undefined,
          isCircle: true,
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
    }
  }

  return items.slice(0, 8);
});

async function onPlayItem(item: RecentItem) {
  if (item.type === 'liked-songs') {
    if (props.favourites?.tracks?.length) {
      playAudioTracks(props.favourites.tracks);
    }
  } else if (item.type === 'album') {
    const albumObj = [...props.recentAlbums, ...props.frequentAlbums, ...props.newestAlbums].find(
      (a) => `album-${a.id}` === item.id,
    );
    if (albumObj) {
      const tracks = await getMediaTracks(albumObj);
      if (tracks?.length) {
        playAudioTracks(tracks);
      }
    }
  } else if (item.type === 'playlist') {
    const plObj = props.playlists?.find((p) => `playlist-${p.id}` === item.id);
    if (plObj?.tracks?.length) {
      playAudioTracks(plObj.tracks);
    }
  }
}
</script>

<template>
  <section :class="$style.recentGridSection" aria-label="Recently accessed media">
    <div :class="$style.recentGrid">
      <CompactRecentCard
        v-for="item in recentItems"
        :key="item.id"
        :item
        @play="onPlayItem"
      />
    </div>
  </section>
</template>

<style module>
.recentGridSection {
  width: 100%;
  margin-bottom: 28px;
}

.recentGrid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 10px;

  @media (--tablet-up) {
    grid-template-columns: repeat(2, 1fr);
    gap: 12px;
  }

  @media (width >= 1200px) {
    grid-template-columns: repeat(4, 1fr);
    gap: 12px;
  }
}
</style>
