import type { H3Event } from 'h3';

export default defineEventHandler(async (event: H3Event) => {
  const path = event.context.params?._ || '';
  const query = getQuery(event);

  // Exclude non-idempotent or stream/download/scrobble actions from caching
  const nonCacheableEndpoints = ['stream', 'download', 'scrobble', 'star', 'unstar', 'createPlaylist', 'deletePlaylist', 'updatePlaylist'];
  const endpoint = path.replace(/\.view$/, '');

  const isCacheable = !nonCacheableEndpoints.some((ep) => endpoint.toLowerCase().includes(ep));

  const authCookie = getCookie(event, COOKIE_NAMES.auth);
  if (!authCookie) {
    throw createError({ statusCode: 401, message: 'Authentication required' });
  }

  const { baseParams, baseURL } = getBaseOptions(authCookie);
  const cacheKey = `subsonic:proxy:${endpoint}:${JSON.stringify(query)}`;

  const fetchUpstream = async () => {
    return await $fetch(`${baseURL}/rest/${path}`, {
      query: {
        ...baseParams,
        ...query,
      },
    });
  };

  if (isCacheable) {
    // 30-minute default TTL for metadata, 24 hours for lyrics
    const ttl = endpoint.toLowerCase().includes('lyrics') ? 86400 : 1800;
    return await redisCache.getOrSet(cacheKey, fetchUpstream, ttl);
  }

  return await fetchUpstream();
});
