package com.cipher.presence.domain;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

/**
 * A user's online state as broadcast to their contacts. {@code lastSeenAt} is the moment the
 * state was observed, so an "online" update carries the connect time and an "offline" one the
 * disconnect time, which is all a chat list needs to render "last seen".
 */
public record PresenceUpdate(UUID userId, boolean online, Instant lastSeenAt) {

    public PresenceUpdate {
        Objects.requireNonNull(userId, "userId");
        Objects.requireNonNull(lastSeenAt, "lastSeenAt");
    }
}
