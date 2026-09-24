package com.cipher.presence.application.port.in;

import java.util.UUID;

/**
 * Forwards a typing indicator to the other participant of the conversation, after checking that
 * the caller is a member. Fails with {@code not-a-participant} otherwise; nothing is stored.
 */
public interface RelayTypingUseCase {

    void relay(UUID userId, UUID conversationId, boolean started);
}
