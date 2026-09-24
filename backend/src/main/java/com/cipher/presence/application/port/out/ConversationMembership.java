package com.cipher.presence.application.port.out;

import java.util.Optional;
import java.util.UUID;

/**
 * Resolves the other member of a conversation for a caller who is in it; empty when the
 * conversation is unknown or the caller is not a member. One answer covers both cases on
 * purpose, so a typing frame cannot be used to probe which conversation ids exist.
 */
public interface ConversationMembership {

    Optional<UUID> otherParticipant(UUID conversationId, UUID userId);
}
