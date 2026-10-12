export default defineEventHandler(async (event) => {
  const body = await readBody(event);
  const { title, artist, album, durationMs, coverUrl, uri } = body || {};

  if (!title || !artist) {
    throw createError({
      statusCode: 400,
      statusMessage: 'title and artist are required',
    });
  }

  try {
    const result = await $fetch<{ status: string; file: string }>(
      `${process.env.DOWNLOADER_URL || 'http://localhost:8000'}/download`,
      {
        method: 'POST',
        body: { title, artist, album, durationMs, coverUrl, uri },
        timeout: 180_000,
      },
    );

    if (result.status !== 'ready' || !result.file) {
      throw new Error('Downloader did not return a ready file');
    }

    return {
      success: true,
      status: 'ready',
      file: result.file,
      streamUrl: `/api/stream?file=${encodeURIComponent(result.file)}`,
    };
  } catch (error) {
    throw createError({
      statusCode: 502,
      statusMessage: error instanceof Error ? error.message : 'Download failed',
    });
  }
});
