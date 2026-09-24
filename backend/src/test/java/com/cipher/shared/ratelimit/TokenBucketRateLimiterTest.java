package com.cipher.shared.ratelimit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.cipher.support.MutableClock;
import java.time.Duration;
import java.time.Instant;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class TokenBucketRateLimiterTest {

    private MutableClock clock;

    @BeforeEach
    void setUp() {
        clock = new MutableClock(Instant.parse("2026-09-24T10:00:00Z"));
    }

    @Test
    void allowsBurstUpToCapacityThenDenies() {
        TokenBucketRateLimiter limiter = new TokenBucketRateLimiter(3, 60, clock);

        assertThat(limiter.tryAcquire("ip").allowed()).isTrue();
        assertThat(limiter.tryAcquire("ip").allowed()).isTrue();
        assertThat(limiter.tryAcquire("ip").allowed()).isTrue();

        TokenBucketRateLimiter.Decision denied = limiter.tryAcquire("ip");
        assertThat(denied.allowed()).isFalse();
        assertThat(denied.retryAfter()).isPositive().isLessThanOrEqualTo(Duration.ofSeconds(1));
        assertThat(denied.retryAfterSeconds()).isEqualTo(1);
    }

    @Test
    void refillsAtTheConfiguredRate() {
        TokenBucketRateLimiter limiter = new TokenBucketRateLimiter(1, 60, clock);
        assertThat(limiter.tryAcquire("ip").allowed()).isTrue();
        assertThat(limiter.tryAcquire("ip").allowed()).isFalse();

        clock.advance(Duration.ofMillis(999));
        assertThat(limiter.tryAcquire("ip").allowed()).isFalse();

        clock.advance(Duration.ofMillis(1));
        assertThat(limiter.tryAcquire("ip").allowed()).isTrue();
    }

    @Test
    void neverAccumulatesBeyondCapacity() {
        TokenBucketRateLimiter limiter = new TokenBucketRateLimiter(2, 60, clock);
        clock.advance(Duration.ofHours(1));

        assertThat(limiter.tryAcquire("ip").allowed()).isTrue();
        assertThat(limiter.tryAcquire("ip").allowed()).isTrue();
        assertThat(limiter.tryAcquire("ip").allowed()).isFalse();
    }

    @Test
    void keysAreIndependent() {
        TokenBucketRateLimiter limiter = new TokenBucketRateLimiter(1, 60, clock);

        assertThat(limiter.tryAcquire("a").allowed()).isTrue();
        assertThat(limiter.tryAcquire("a").allowed()).isFalse();
        assertThat(limiter.tryAcquire("b").allowed()).isTrue();
    }

    @Test
    void retryAfterReflectsTheTimeUntilTheNextToken() {
        TokenBucketRateLimiter limiter = new TokenBucketRateLimiter(1, 10, clock);
        limiter.tryAcquire("ip");

        TokenBucketRateLimiter.Decision denied = limiter.tryAcquire("ip");

        assertThat(denied.retryAfter()).isEqualTo(Duration.ofSeconds(6));
        assertThat(denied.retryAfterSeconds()).isEqualTo(6);
    }

    @Test
    void evictsFullBucketsOnceTooManyKeysAreTracked() {
        TokenBucketRateLimiter limiter = new TokenBucketRateLimiter(1, 60, clock, 2);
        limiter.tryAcquire("a");
        limiter.tryAcquire("b");
        limiter.tryAcquire("c");
        assertThat(limiter.trackedKeys()).isEqualTo(3);

        clock.advance(Duration.ofSeconds(2));
        limiter.tryAcquire("d");

        assertThat(limiter.trackedKeys()).isEqualTo(1);
    }

    @Test
    void rejectsNonPositiveConfiguration() {
        assertThatThrownBy(() -> new TokenBucketRateLimiter(0, 10, clock)).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> new TokenBucketRateLimiter(10, 0, clock)).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> new TokenBucketRateLimiter(10, 10, clock, 0)).isInstanceOf(IllegalArgumentException.class);
    }
}
