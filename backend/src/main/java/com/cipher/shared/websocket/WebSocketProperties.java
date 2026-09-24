package com.cipher.shared.websocket;

import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;
import org.springframework.util.unit.DataSize;

/**
 * Relay socket tuning bound from {@code cipher.websocket.*}.
 *
 * <p>The idle timeout is the protocol's 90 seconds (clients ping every 25 s, so three missed
 * heartbeats end a session). The send limits bound how much a slow or stalled phone can make
 * the relay buffer on its behalf before the session is dropped rather than the JVM heap.
 */
@ConfigurationProperties(prefix = "cipher.websocket")
public record WebSocketProperties(@DefaultValue("90s") Duration idleTimeout,
                                  @DefaultValue("15s") Duration idleSweepInterval,
                                  @DefaultValue("10s") Duration sendTimeLimit,
                                  @DefaultValue("512KB") DataSize sendBufferSizeLimit,
                                  @DefaultValue("64KB") DataSize maxTextMessageSize) {

    public WebSocketProperties {
        requirePositive(idleTimeout, "cipher.websocket.idle-timeout");
        requirePositive(idleSweepInterval, "cipher.websocket.idle-sweep-interval");
        requirePositive(sendTimeLimit, "cipher.websocket.send-time-limit");
        if (sendBufferSizeLimit == null || sendBufferSizeLimit.toBytes() < 1024) {
            throw new IllegalStateException("cipher.websocket.send-buffer-size-limit must be at least 1KB");
        }
        if (maxTextMessageSize == null || maxTextMessageSize.toBytes() < 1024) {
            throw new IllegalStateException("cipher.websocket.max-text-message-size must be at least 1KB");
        }
    }

    private static void requirePositive(Duration value, String property) {
        if (value == null || value.isZero() || value.isNegative()) {
            throw new IllegalStateException(property + " must be a positive duration");
        }
    }
}
