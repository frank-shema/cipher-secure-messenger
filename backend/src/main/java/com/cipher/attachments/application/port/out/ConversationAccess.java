package com.cipher.attachments.application.port.out;

import java.util.UUID;

/**
 * Whether a user may touch a conversation's blobs. Attachments do not own conversations, so
 * this port is the only thing the feature knows about them; the messaging feature provides the
 * adapter.
 */
public interface ConversationAccess {

    Decision check(UUID conversationId, UUID userId);

    enum Decision {
        NOT_FOUND,
        NOT_A_PARTICIPANT,
        ALLOWED
    }
}
