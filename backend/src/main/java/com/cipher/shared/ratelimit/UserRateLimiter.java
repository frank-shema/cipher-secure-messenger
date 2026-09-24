package com.cipher.shared.ratelimit;

import java.time.Clock;
import java.util.UUID;

/**
 * A per-user budget built on {@link TokenBucketRateLimiter}.
 *
 * <p>Each feature that throttles authenticated actions instantiates one of these with its own
 * key prefix so that, for example, a burst of uploads can never eat into the message budget.
 * The class stays free of Spring so it can be constructed directly wherever a budget is needed.
 */
public final class UserRateLimiter {

    private final TokenBucketRateLimiter limiter;
    private final String keyPrefix;
    private final String action;

    public UserRateLimiter(String keyPrefix, String action, int capacity, int refillPerMinute, Clock clock) {
        this.limiter = new TokenBucketRateLimiter(capacity, refillPerMinute, clock);
        this.keyPrefix = keyPrefix;
        this.action = action;
    }

    /**
     * Consumes one token for the user or raises {@link RateLimitExceededException}.
     */
    public void acquire(UUID userId) {
        TokenBucketRateLimiter.Decision decision = tryAcquire(userId);
        if (!decision.allowed()) {
            throw new RateLimitExceededException("Too many " + action + ". Retry after "
                    + decision.retryAfterSeconds() + " seconds.", decision.retryAfterSeconds());
        }
    }

    public TokenBucketRateLimiter.Decision tryAcquire(UUID userId) {
        return limiter.tryAcquire(keyPrefix + userId);
    }
}
