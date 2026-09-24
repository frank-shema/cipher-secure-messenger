package com.cipher.messaging.application.port.in;

import java.time.Instant;
import java.util.UUID;

/**
 * Keyset pagination request: {@code before} excludes envelopes created at or after that
 * instant; {@code null} means "from the newest".
 */
public record GetMessagesQuery(UUID userId, UUID conversationId, Instant before, int limit) {

    public static final int DEFAULT_LIMIT = 50;
    public static final int MAX_LIMIT = 200;

    public GetMessagesQuery {
        if (limit < 1 || limit > MAX_LIMIT) {
            throw new IllegalArgumentException("limit must be between 1 and " + MAX_LIMIT);
        }
    }
}
