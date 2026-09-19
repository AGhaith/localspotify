// Redis caching utility for LocalSpotify Subsonic server
const inMemoryCache = new Map<string, { data: unknown; expiresAt: number }>();

export class RedisCache {
  private static instance: RedisCache;
  private client: unknown = null;
  private isConnected = false;

  private constructor() {
    this.init();
  }

  public static getInstance(): RedisCache {
    if (!RedisCache.instance) {
      RedisCache.instance = new RedisCache();
    }
    return RedisCache.instance;
  }

  private async init() {
    const host = process.env.REDIS_HOST || '127.0.0.1';
    const port = Number(process.env.REDIS_PORT || 6379);

    try {
      // Dynamic import to avoid crash if ioredis is not bundled
      const { default: Redis } = await import('ioredis');
      const redisClient = new Redis({
        host,
        port,
        maxRetriesPerRequest: 2,
        connectTimeout: 2000,
        lazyConnect: true,
      });

      redisClient.on('connect', () => {
        this.isConnected = true;
        // eslint-disable-next-line no-console
        console.log(`[Redis] Connected successfully to ${host}:${port}`);
      });

      redisClient.on('error', (err: Error) => {
        this.isConnected = false;
        // eslint-disable-next-line no-console
        console.warn(`[Redis] Warning (using in-memory fallback): ${err.message}`);
      });

      await redisClient.connect();
      this.client = redisClient;
    } catch {
      this.isConnected = false;
      // eslint-disable-next-line no-console
      console.log('[Redis] Running with high-speed in-memory cache fallback');
    }
  }

  public async get<T>(key: string): Promise<T | null> {
    const prefixedKey = `localspotify:${key}`;

    if (this.isConnected && this.client) {
      try {
        const raw = await (this.client as { get: (k: string) => Promise<string | null> }).get(prefixedKey);
        if (raw) {
          return JSON.parse(raw) as T;
        }
        return null;
      } catch {
        // Fall back to memory
      }
    }

    const item = inMemoryCache.get(prefixedKey);
    if (!item) return null;
    if (Date.now() > item.expiresAt) {
      inMemoryCache.delete(prefixedKey);
      return null;
    }
    return item.data as T;
  }

  public async set<T>(key: string, value: T, ttlSeconds = 3600): Promise<void> {
    const prefixedKey = `localspotify:${key}`;

    if (this.isConnected && this.client) {
      try {
        const serialized = JSON.stringify(value);
        await (this.client as { set: (k: string, v: string, mode: string, ttl: number) => Promise<unknown> }).set(
          prefixedKey,
          serialized,
          'EX',
          ttlSeconds,
        );
        return;
      } catch {
        // Fall back to memory
      }
    }

    inMemoryCache.set(prefixedKey, {
      data: value,
      expiresAt: Date.now() + ttlSeconds * 1000,
    });
  }

  public async getOrSet<T>(key: string, fetcher: () => Promise<T>, ttlSeconds = 3600): Promise<T> {
    const cached = await this.get<T>(key);
    if (cached !== null && cached !== undefined) {
      return cached;
    }
    const fresh = await fetcher();
    if (fresh !== null && fresh !== undefined) {
      await this.set(key, fresh, ttlSeconds);
    }
    return fresh;
  }
}

export const redisCache = RedisCache.getInstance();
