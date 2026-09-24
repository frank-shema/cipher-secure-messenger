package com.cipher.messaging.application.port.in;

import java.util.List;
import java.util.UUID;

/**
 * The caller's inbox, most recently active first.
 */
public interface ListConversationsUseCase {

    List<ConversationView> listFor(UUID userId);
}
