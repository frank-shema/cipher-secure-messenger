package com.cipher.presence.domain;

import java.util.Objects;
import java.util.UUID;

/**
 * "This user is (no longer) typing in this conversation". Ephemeral by design: the relay
 * forwards it and forgets it, so there is nothing to store, page or purge.
 */
public record TypingEvent(UUID conversationId, UUID userId, boolean started) {

    public TypingEvent {
        Objects.requireNonNull(conversationId, "conversationId");
        Objects.requireNonNull(userId, "userId");
    }
}
