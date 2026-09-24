package com.cipher.presence.application.port.out;

import java.time.Instant;
import java.util.UUID;

/**
 * Persists the {@code last_seen_at} column. Written on connect and disconnect so a relay
 * restart leaves a sensible value behind even for users whose disconnect was never observed.
 */
public interface LastSeenRepository {

    void recordLastSeen(UUID userId, Instant at);
}
