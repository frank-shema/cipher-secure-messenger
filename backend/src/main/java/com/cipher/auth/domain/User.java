package com.cipher.auth.domain;

import java.time.Instant;
import java.util.Locale;
import java.util.UUID;

/**
 * An account on the relay. The password hash travels with the aggregate because login is the
 * only place that reads it; nothing else may ever expose it.
 */
public record User(UUID id, String username, String displayName, String passwordHash, Instant createdAt) {

    public static String normalizeUsername(String raw) {
        return raw.trim().toLowerCase(Locale.ROOT);
    }
}
