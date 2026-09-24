package com.cipher.shared.ratelimit;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;

/**
 * Rate-limit knobs bound from {@code cipher.ratelimit.*}.
 *
 * <p>The defaults are the protocol's numbers: 10 auth requests per minute per IP, 60 messages
 * and 20 uploads per minute per user, plus a generous budget of WebSocket frames per user that
 * only a runaway client can exhaust. They are configurable so that operators can tighten them
 * under attack and so integration tests can exercise long flows without tripping the limit.
 */
@ConfigurationProperties(prefix = "cipher.ratelimit")
public record RateLimitProperties(@DefaultValue Auth auth,
                                  @DefaultValue Messages messages,
                                  @DefaultValue Uploads uploads,
                                  @DefaultValue Frames frames) {

    public record Auth(@DefaultValue("10") int capacity, @DefaultValue("10") int refillPerMinute) {

        public Auth {
            requirePositive(capacity, "cipher.ratelimit.auth.capacity");
            requirePositive(refillPerMinute, "cipher.ratelimit.auth.refill-per-minute");
        }
    }

    public record Messages(@DefaultValue("60") int capacity, @DefaultValue("60") int refillPerMinute) {

        public Messages {
            requirePositive(capacity, "cipher.ratelimit.messages.capacity");
            requirePositive(refillPerMinute, "cipher.ratelimit.messages.refill-per-minute");
        }
    }

    public record Uploads(@DefaultValue("20") int capacity, @DefaultValue("20") int refillPerMinute) {

        public Uploads {
            requirePositive(capacity, "cipher.ratelimit.uploads.capacity");
            requirePositive(refillPerMinute, "cipher.ratelimit.uploads.refill-per-minute");
        }
    }

    public record Frames(@DefaultValue("240") int capacity, @DefaultValue("240") int refillPerMinute) {

        public Frames {
            requirePositive(capacity, "cipher.ratelimit.frames.capacity");
            requirePositive(refillPerMinute, "cipher.ratelimit.frames.refill-per-minute");
        }
    }

    private static void requirePositive(int value, String property) {
        if (value < 1) {
            throw new IllegalStateException(property + " must be at least 1");
        }
    }
}
