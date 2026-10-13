type LyricsResponse = {
  synced: boolean;
  lrc: string;
  source: string;
};

export default defineEventHandler(async (event): Promise<LyricsResponse> => {
  const { title, artist, album, duration } = getQuery(event);
  if (typeof title !== 'string' || !title.trim() || typeof artist !== 'string' || !artist.trim()) {
    throw createError({ statusCode: 400, statusMessage: 'title and artist are required' });
  }

  try {
    return await $fetch<LyricsResponse>(
      `${process.env.DOWNLOADER_URL || 'http://localhost:8000'}/lyrics`,
      {
        query: {
          title,
          artist,
          ...(typeof album === 'string' ? { album } : {}),
          ...(typeof duration === 'string' ? { duration } : {}),
        },
        timeout: 20_000,
      },
    );
  } catch {
    throw createError({ statusCode: 404, statusMessage: 'Lyrics not found' });
  }
});
