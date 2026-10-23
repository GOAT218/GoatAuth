// Lightweight in-memory sliding-window rate limiter.
// Suitable for a single-node deployment. For multi-node, swap the store for
// Redis while keeping this interface.

interface Bucket {
  count: number;
  resetAt: number;
}

const globalForRl = globalThis as unknown as { __goatauthRl?: Map<string, Bucket> };
const store: Map<string, Bucket> = globalForRl.__goatauthRl ?? new Map();
if (process.env.NODE_ENV !== "production") globalForRl.__goatauthRl = store;

export interface RateResult {
  allowed: boolean;
  remaining: number;
  resetAt: number;
}

/**
 * @param key      unique bucket key (e.g. `login:<ip>`)
 * @param limit    max requests within the window
 * @param windowMs window length in milliseconds
 */
export function rateLimit(key: string, limit: number, windowMs: number): RateResult {
  const now = Date.now();
  const bucket = store.get(key);

  if (!bucket || bucket.resetAt <= now) {
    const resetAt = now + windowMs;
    store.set(key, { count: 1, resetAt });
    return { allowed: true, remaining: limit - 1, resetAt };
  }

  if (bucket.count >= limit) {
    return { allowed: false, remaining: 0, resetAt: bucket.resetAt };
  }

  bucket.count += 1;
  return { allowed: true, remaining: limit - bucket.count, resetAt: bucket.resetAt };
}

// Opportunistically evict expired buckets so the map does not grow unbounded.
let lastSweep = 0;
export function sweepRateLimits(): void {
  const now = Date.now();
  if (now - lastSweep < 60_000) return;
  lastSweep = now;
  for (const [key, bucket] of store) {
    if (bucket.resetAt <= now) store.delete(key);
  }
}
