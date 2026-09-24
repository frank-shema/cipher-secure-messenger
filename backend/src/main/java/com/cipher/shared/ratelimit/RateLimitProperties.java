package com.cipher.shared.ratelimit;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;

/**
 * Rate-limit knobs bound from {@code cipher.ratelimit.*}.
 *
 * <p>The defaults are the protocol's numbers (10 auth requests per minute per IP). They are
 * configurable so that operators can tighten them under attack and so integration tests can
 * exercise long flows without tripping the limit, while a dedicated test pins the default.
 */
@ConfigurationProperties(prefix = "cipher.ratelimit")
public record RateLimitProperties(@DefaultValue Auth auth) {

    public record Auth(@DefaultValue("10") int capacity, @DefaultValue("10") int refillPerMinute) {

        public Auth {
            if (capacity < 1) {
                throw new IllegalStateException("cipher.ratelimit.auth.capacity must be at least 1");
            }
            if (refillPerMinute < 1) {
                throw new IllegalStateException("cipher.ratelimit.auth.refill-per-minute must be at least 1");
            }
        }
    }
}
