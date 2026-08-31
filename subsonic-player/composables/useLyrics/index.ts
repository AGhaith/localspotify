import type { LyricLine, LyricsResponse } from './types';
import { cleanArtistName, cleanTrackTitle, parseLrc } from './utils';

export function useLyrics() {
  const { lockScroll, unlockScroll } = useScrollLock('lyrics');
  const { currentTrack, hasCurrentTrack } = useQueue();
  const { currentTime, seekTo } = useAudioPlayer();
  const { fetchData } = useAPI();

  const isLyricsOpened = useState(STATE_KEYS.lyricsOpened, () => false);
  const isLoading = useState('lyrics-loading', () => false);
  const error = useState<string | null>('lyrics-error', () => null);
  const isSynced = useState('lyrics-synced', () => false);
  const lyricLines = useState<LyricLine[]>('lyrics-lines', () => []);
  const source = useState<string>('lyrics-source', () => '');
  const loadedTrackId = useState<string | null>(
    'lyrics-loaded-track-id',
    () => null,
  );

  function getArtist(track: PlayableTrack): string {
    if ('artists' in track && track.artists?.length) {
      return track.artists.map((a) => a.name).join(', ');
    }
    if ('author' in track && track.author) {
      return track.author;
    }
    if ('artist' in track && track.artist) {
      return track.artist;
    }
    return '';
  }

  // Active line index based on playback currentTime
  const currentLineIndex = computed(() => {
    if (!isSynced.value || !lyricLines.value.length) {
      return -1;
    }

    const time = currentTime.value;
    const lines = lyricLines.value;

    let activeIdx = -1;
    for (let i = 0; i < lines.length; i++) {
      if (lines[i].time !== undefined && lines[i].time! <= time) {
        activeIdx = i;
      } else if (lines[i].time !== undefined && lines[i].time! > time) {
        break;
      }
    }

    return activeIdx;
  });

  async function fetchLyrics(force = false) {
    if (!hasCurrentTrack.value || !currentTrack.value) {
      lyricLines.value = [];
      error.value = null;
      return;
    }

    const track = currentTrack.value;
    if (
      !force &&
      loadedTrackId.value === track.id &&
      (lyricLines.value.length > 0 || error.value)
    ) {
      return;
    }

    isLoading.value = true;
    error.value = null;
    lyricLines.value = [];
    isSynced.value = false;
    source.value = '';

    const rawArtist = getArtist(track);
    const rawTitle = track.name || '';
    const cleanTitle = cleanTrackTitle(rawTitle);
    const cleanArtist = cleanArtistName(rawArtist);
    const album =
      'album' in track && track.album ? track.album : '';
    const duration = track.duration || 0;

    // 1. Try LRCLIB API first (Online high-quality synced lyrics)
    try {
      const lrclibParams = new URLSearchParams({
        artist_name: cleanArtist || rawArtist,
        track_name: cleanTitle || rawTitle,
      });
      if (album) lrclibParams.append('album_name', album);
      if (duration > 0)
        lrclibParams.append('duration', Math.round(duration).toString());

      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 3500);

      const response = await fetch(
        `https://lrclib.net/api/get?${lrclibParams.toString()}`,
        {
          signal: controller.signal,
        },
      );
      clearTimeout(timeoutId);

      if (response.ok) {
        const data = (await response.json()) as LyricsResponse;

        if (data.syncedLyrics) {
          lyricLines.value = parseLrc(data.syncedLyrics);
          isSynced.value = true;
          source.value = 'LRCLIB (Synced)';
          loadedTrackId.value = track.id;
          isLoading.value = false;
          return;
        }

        if (data.plainLyrics) {
          lyricLines.value = data.plainLyrics
            .split('\n')
            .map((text) => ({ text }));
          isSynced.value = false;
          source.value = 'LRCLIB';
          loadedTrackId.value = track.id;
          isLoading.value = false;
          return;
        }
      }
    } catch {
      // LRCLIB unavailable, offline, or timed out
    }

    // 2. Try Navidrome Subsonic OpenSubsonic getLyricsBySongId (Offline / Local)
    try {
      const subsonicResponse = await fetchData<any>('getLyricsBySongId', {
        query: { id: track.id },
        suppressErrorSnack: true,
      });

      if (
        subsonicResponse.data?.['subsonic-response']?.lyricsList
          ?.structuredLyrics?.length
      ) {
        const structured =
          subsonicResponse.data['subsonic-response'].lyricsList
            .structuredLyrics[0];
        if (structured.line?.length) {
          lyricLines.value = structured.line.map((l: any) => ({
            text: l.value || '',
            time: (l.start || 0) / 1000,
          }));
          isSynced.value = !!structured.synced;
          source.value = 'Navidrome';
          loadedTrackId.value = track.id;
          isLoading.value = false;
          return;
        }
      }
    } catch {
      // OpenSubsonic getLyricsBySongId not found or not supported
    }

    // 3. Try standard Subsonic getLyrics endpoint
    try {
      const legacyResponse = await fetchData<any>('getLyrics', {
        query: {
          artist: rawArtist,
          title: rawTitle,
        },
        suppressErrorSnack: true,
      });

      const content =
        legacyResponse.data?.['subsonic-response']?.lyrics?.content;
      if (content) {
        const parsed = parseLrc(content);
        lyricLines.value = parsed.length
          ? parsed
          : content.split('\n').map((text: string) => ({ text }));
        isSynced.value = parsed.some((line) => line.time !== undefined);
        source.value = 'Navidrome (Embedded)';
        loadedTrackId.value = track.id;
        isLoading.value = false;
        return;
      }
    } catch {
      // getLyrics failed
    }

    // 4. Nothing found
    error.value = 'No lyrics found for this track.';
    loadedTrackId.value = track.id;
    isLoading.value = false;
  }

  function toggleLyrics() {
    isLyricsOpened.value = !isLyricsOpened.value;

    if (isLyricsOpened.value) {
      lockScroll();
      if (loadedTrackId.value !== currentTrack.value?.id) {
        fetchLyrics();
      }
    } else {
      unlockScroll();
    }
  }

  function closeLyrics() {
    isLyricsOpened.value = false;
    unlockScroll();
  }

  function jumpToLyric(time?: number) {
    if (time !== undefined && time >= 0) {
      seekTo(time);
    }
  }

  // Watch current track change to auto-update lyrics if the view is open
  watch(
    () => currentTrack.value?.id,
    (newId) => {
      if (!newId) {
        lyricLines.value = [];
        return;
      }
      if (isLyricsOpened.value) {
        fetchLyrics();
      }
    },
  );

  return {
    closeLyrics,
    currentLineIndex,
    error,
    fetchLyrics,
    isLoading,
    isLyricsOpened,
    isSynced,
    jumpToLyric,
    lyricLines,
    source,
    toggleLyrics,
  };
}
