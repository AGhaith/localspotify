import { randomUUID } from 'node:crypto';

export interface ImportTrack {
  title: string;
  artist: string;
  album?: string;
  durationMs?: number;
  coverUrl?: string;
  uri?: string;
  isrc?: string;
}

export interface ImportJob {
  id: string;
  status: 'downloading' | 'completed' | 'error';
  totalCount: number;
  completedCount: number;
  failedCount: number;
  error?: string;
}

export const importJobs = new Map<string, ImportJob>();

export function createImportJob(totalCount: number): ImportJob {
  const job: ImportJob = { id: randomUUID(), status: 'downloading', totalCount, completedCount: 0, failedCount: 0 };
  importJobs.set(job.id, job);
  setTimeout(() => importJobs.delete(job.id), 24 * 60 * 60 * 1000).unref();
  return job;
}

function spotifyId(url: string): string {
  return url.match(/(?:playlist\/|spotify:playlist:)([\w]+)/)?.[1] || url;
}

async function spotifyEntity(kind: 'playlist' | 'track', id: string): Promise<Record<string, any>> {
  const html = await $fetch<string>(`https://open.spotify.com/embed/${kind}/${id}`, {
    responseType: 'text',
    headers: { 'User-Agent': 'Mozilla/5.0', 'Accept-Language': 'en-US,en;q=0.9' },
    timeout: 15_000,
  });
  const json = html.match(/<script id="__NEXT_DATA__" type="application\/json">([\s\S]*?)<\/script>/)?.[1];
  if (!json) throw new Error(`Spotify ${kind} metadata unavailable`);
  return JSON.parse(json).props.pageProps.state.data.entity;
}

function imageUrl(entity: Record<string, any>): string | undefined {
  const images = entity.visualIdentity?.image;
  return Array.isArray(images) ? images.at(-1)?.url || images[0]?.url : undefined;
}

async function playlistTracks(url: string): Promise<ImportTrack[]> {
  const entity = await spotifyEntity('playlist', spotifyId(url));
  if (!Array.isArray(entity.trackList)) throw new Error('Spotify playlist has no tracklist');
  return entity.trackList.map((track: Record<string, any>) => ({
    title: track.title,
    artist: track.subtitle,
    durationMs: track.duration,
    uri: track.uri,
  })).filter((track: ImportTrack) => track.title && track.artist);
}

export function normalized(value: string): string {
  return value.toLowerCase().normalize('NFKD').replace(/[\u0300-\u036f]/g, '').replace(/[^\p{L}\p{N}]+/gu, ' ').trim();
}

const versionWords = /\b(live|remix|acoustic|instrumental|sped up|slowed|karaoke|cover|edit|mix|version|remaster(?:ed)?)\b/g;

export function matchesDeezer(track: ImportTrack, candidate: Record<string, any>): boolean {
  const title = normalized(track.title);
  const candidateTitle = normalized(candidate.title || '');
  const artist = normalized(track.artist.split(/[,;]/)[0]);
  const candidateArtist = normalized(candidate.artist?.name || '');
  const requestedVersions = new Set(title.match(versionWords) || []);
  const candidateVersions = new Set(candidateTitle.match(versionWords) || []);
  return !!title && !!artist && !!candidateArtist && candidateTitle === title &&
    (candidateArtist === artist || candidateArtist.includes(artist) || artist.includes(candidateArtist)) &&
    [...requestedVersions].every((word) => candidateVersions.has(word)) &&
    [...candidateVersions].every((word) => requestedVersions.has(word)) &&
    (track.durationMs === undefined || Math.abs(candidate.duration * 1000 - track.durationMs) <= 3000);
}

async function deezerMetadata(track: ImportTrack): Promise<ImportTrack | undefined> {
  const query = encodeURIComponent(`${track.artist.split(/[,;]/)[0]} ${track.title}`);
  const search = await $fetch<{ data?: Record<string, any>[] }>(`https://api.deezer.com/search?q=${query}`, {
    headers: { 'Accept-Language': 'en' }, timeout: 12_000,
  });
  const candidate = search.data?.find((song) => matchesDeezer(track, song));
  if (!candidate) return undefined;
  const song = await $fetch<Record<string, any>>(`https://api.deezer.com/track/${candidate.id}`, {
    headers: { 'Accept-Language': 'en' }, timeout: 12_000,
  });
  if (!matchesDeezer(track, song) || !song.album?.title) return undefined;
  return { ...track, album: song.album.title, coverUrl: song.album.cover_xl || song.album.cover_big, isrc: song.isrc || track.isrc };
}

async function resolvedTrack(track: ImportTrack): Promise<ImportTrack> {
  try {
    const deezer = await deezerMetadata(track);
    if (deezer) return deezer;
  } catch (error) {
    console.warn('Deezer metadata lookup failed:', error);
  }
  const id = track.uri?.match(/(?:spotify:track:|\/track\/)([\w]+)/)?.[1];
  if (id) {
    try {
      const entity = await spotifyEntity('track', id);
      return { ...track, album: entity.album?.name || entity.album?.title || track.album, coverUrl: imageUrl(entity) || track.coverUrl };
    } catch (error) {
      console.warn('Spotify track metadata lookup failed:', error);
    }
  }
  return track;
}

export async function runImportJob(job: ImportJob, url: string, supplied: ImportTrack[]): Promise<void> {
  const tracks = supplied.length ? supplied : await playlistTracks(url);
  job.totalCount = tracks.length;
  let next = 0;
  await Promise.all(Array.from({ length: Math.min(3, tracks.length) }, async () => {
    while (next < tracks.length) {
      const track = tracks[next++];
      try {
        const metadata = await resolvedTrack(track);
        const download = await $fetch<{ status: string; file?: string }>(
          `${process.env.DOWNLOADER_URL || 'http://localhost:8000'}/download`,
          { method: 'POST', body: metadata, timeout: 180_000 },
        );
        if (download.status !== 'ready' || !download.file) throw new Error('Downloader did not return a ready file');
      } catch (error) {
        job.failedCount++;
        console.error(`Playlist track failed: ${track.artist} - ${track.title}`, error);
      }
      job.completedCount++;
    }
  }));
  job.status = 'completed';
}
