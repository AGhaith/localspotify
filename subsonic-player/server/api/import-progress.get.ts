type ImportProgress = {
  stage: 'idle' | 'searching' | 'downloading' | 'processing' | 'ready' | 'failed';
  percent: number;
  message: string;
};

export default defineEventHandler(async (event): Promise<ImportProgress> => {
  const { title, artist } = getQuery(event);

  try {
    return await $fetch<ImportProgress>(
      `${process.env.DOWNLOADER_URL || 'http://localhost:8000'}/progress`,
      {
        query: { title, artist },
        timeout: 3_000,
      },
    );
  } catch {
    return { stage: 'idle', percent: 0, message: '' };
  }
});
