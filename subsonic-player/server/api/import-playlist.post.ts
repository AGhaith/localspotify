export default defineEventHandler(async (event) => {
  const body = await readBody(event);
  const { spotifyUrl, playlistName, tracks, username } = body || {};

  if (!spotifyUrl) {
    throw createError({
      statusCode: 400,
      statusMessage: 'spotifyUrl is required',
    });
  }

  // Acknowledge receipt of import request for server vault queue
  return {
    success: true,
    status: 'queued',
    playlistName: playlistName || 'Imported Playlist',
    trackCount: Array.isArray(tracks) ? tracks.length : 0,
    timestamp: new Date().toISOString(),
  };
});
