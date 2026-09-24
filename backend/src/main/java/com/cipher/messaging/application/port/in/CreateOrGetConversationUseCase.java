package com.cipher.messaging.application.port.in;

import java.util.UUID;

/**
 * Resolves the single conversation between the caller and another user, creating it on first
 * contact. Idempotent by construction: the pair determines the id.
 */
public interface CreateOrGetConversationUseCase {

    ConversationResult createOrGet(UUID userId, UUID participantId);
}
