import { createImportJob, runImportJob } from '../utils/playlist-import';

export default defineEventHandler(async (event) => {
  const body = await readBody(event);
  const { spotifyUrl, playlistName, tracks } = body || {};

  if (typeof spotifyUrl !== 'string' || !/^(https:\/\/open\.spotify\.com\/playlist\/[\w]+(?:\?.*)?|spotify:playlist:[\w]+|[a-zA-Z0-9]{15,30})$/.test(spotifyUrl)) {
    throw createError({
      statusCode: 400,
      statusMessage: 'Valid spotifyUrl is required',
    });
  }
  if (playlistName !== undefined && (typeof playlistName !== 'string' || !playlistName.trim())) {
    throw createError({ statusCode: 400, statusMessage: 'Invalid playlistName' });
  }
  if (tracks !== undefined && (!Array.isArray(tracks) || tracks.some((track) =>
    !track || typeof track.title !== 'string' || !track.title.trim() ||
    typeof track.artist !== 'string' || !track.artist.trim() ||
    (track.durationMs !== undefined && (!Number.isFinite(track.durationMs) || track.durationMs < 0)) ||
    ['album', 'coverUrl', 'uri', 'isrc'].some((key) => track[key] != null && typeof track[key] !== 'string')
  ))) {
    throw createError({ statusCode: 400, statusMessage: 'Invalid tracks' });
  }

  const job = createImportJob(Array.isArray(tracks) ? tracks.length : 0);
  void runImportJob(job, spotifyUrl, tracks || []).catch((error) => {
    job.status = 'error';
    job.error = error instanceof Error ? error.message : String(error);
    console.error('Playlist import failed:', error);
  });

  return {
    success: true,
    status: 'downloading',
    playlistName: playlistName || 'Imported Playlist',
    trackCount: job.totalCount,
    jobId: job.id,
    timestamp: new Date().toISOString(),
  };
});
