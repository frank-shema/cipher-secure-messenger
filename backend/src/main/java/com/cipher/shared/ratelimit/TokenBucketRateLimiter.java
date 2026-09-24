package com.cipher.shared.ratelimit;

import java.time.Clock;
import java.time.Duration;
import java.util.concurrent.ConcurrentHashMap;

/**
 * In-memory token bucket keyed by an arbitrary string (client IP, user id, ...).
 *
 * <p>A token bucket is preferred over a fixed window because it tolerates short bursts up to
 * {@code capacity} while still bounding the sustained rate, which matches how a phone retries
 * after a flaky connection. State is per JVM on purpose: the relay runs as a single instance
 * behind one database in Phase 1, and a distributed limiter would add a dependency for no
 * current benefit. Idle buckets are swept once the map grows past {@code maxTrackedKeys} so a
 * scan of random IPs cannot exhaust memory.
 */
public final class TokenBucketRateLimiter {

    private static final int DEFAULT_MAX_TRACKED_KEYS = 100_000;

    private final int capacity;
    private final double refillPerMilli;
    private final Clock clock;
    private final int maxTrackedKeys;
    private final ConcurrentHashMap<String, Bucket> buckets = new ConcurrentHashMap<>();

    public TokenBucketRateLimiter(int capacity, int refillPerMinute, Clock clock) {
        this(capacity, refillPerMinute, clock, DEFAULT_MAX_TRACKED_KEYS);
    }

    public TokenBucketRateLimiter(int capacity, int refillPerMinute, Clock clock, int maxTrackedKeys) {
        if (capacity < 1) {
            throw new IllegalArgumentException("capacity must be at least 1");
        }
        if (refillPerMinute < 1) {
            throw new IllegalArgumentException("refillPerMinute must be at least 1");
        }
        if (maxTrackedKeys < 1) {
            throw new IllegalArgumentException("maxTrackedKeys must be at least 1");
        }
        this.capacity = capacity;
        this.refillPerMilli = refillPerMinute / (double) Duration.ofMinutes(1).toMillis();
        this.clock = clock;
        this.maxTrackedKeys = maxTrackedKeys;
    }

    /**
     * Consumes one token for {@code key} if available.
     *
     * @return the decision, with a {@code retryAfter} hint that is only meaningful when denied
     */
    public Decision tryAcquire(String key) {
        long now = clock.millis();
        Bucket bucket = buckets.computeIfAbsent(key, ignored -> new Bucket(capacity, now));
        Decision decision = bucket.tryConsume(now, capacity, refillPerMilli);
        if (buckets.size() > maxTrackedKeys) {
            buckets.entrySet().removeIf(entry -> entry.getValue().isFull(now, capacity, refillPerMilli));
        }
        return decision;
    }

    public int trackedKeys() {
        return buckets.size();
    }

    public record Decision(boolean allowed, Duration retryAfter) {

        static final Decision ALLOWED = new Decision(true, Duration.ZERO);

        public long retryAfterSeconds() {
            long seconds = (retryAfter.toMillis() + 999) / 1000;
            return Math.max(1, seconds);
        }
    }

    private static final class Bucket {

        private double tokens;
        private long lastRefillMillis;

        Bucket(int capacity, long now) {
            this.tokens = capacity;
            this.lastRefillMillis = now;
        }

        synchronized Decision tryConsume(long now, int capacity, double refillPerMilli) {
            refill(now, capacity, refillPerMilli);
            if (tokens >= 1.0) {
                tokens -= 1.0;
                return Decision.ALLOWED;
            }
            long waitMillis = (long) Math.ceil((1.0 - tokens) / refillPerMilli);
            return new Decision(false, Duration.ofMillis(Math.max(1, waitMillis)));
        }

        synchronized boolean isFull(long now, int capacity, double refillPerMilli) {
            refill(now, capacity, refillPerMilli);
            return tokens >= capacity;
        }

        private void refill(long now, int capacity, double refillPerMilli) {
            long elapsed = now - lastRefillMillis;
            if (elapsed <= 0) {
                return;
            }
            tokens = Math.min(capacity, tokens + elapsed * refillPerMilli);
            lastRefillMillis = now;
        }
    }
}
