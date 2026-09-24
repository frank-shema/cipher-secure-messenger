package com.cipher.messaging.domain;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * A delivery or read confirmation relayed back to a sender: which messages of which
 * conversation the other party acknowledged, and when the relay recorded it.
 */
public record Receipt(UUID conversationId, List<UUID> messageIds, UUID byUserId, Instant at) {

    public Receipt {
        messageIds = List.copyOf(messageIds);
    }
}
