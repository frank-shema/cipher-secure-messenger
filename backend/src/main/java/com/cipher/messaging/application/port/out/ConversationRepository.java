package com.cipher.messaging.application.port.out;

import com.cipher.messaging.domain.Conversation;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Persistence port for conversations. {@code save} must tolerate a concurrent insert of the
 * same deterministic id by returning the winner's row, so two first messages racing each other
 * never fail.
 */
public interface ConversationRepository {

    Optional<Conversation> findById(UUID id);

    List<Conversation> findAllInvolving(UUID userId);

    Conversation save(Conversation conversation);

    void recordMessageAt(UUID conversationId, Instant at);
}
