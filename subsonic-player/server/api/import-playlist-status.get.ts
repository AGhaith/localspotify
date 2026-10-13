import { importJobs } from '../utils/playlist-import';

export default defineEventHandler((event) => {
  const id = getQuery(event).jobId;
  const job = typeof id === 'string' ? importJobs.get(id) : undefined;
  if (!job) throw createError({ statusCode: 404, statusMessage: 'Import job not found' });
  return job;
});
