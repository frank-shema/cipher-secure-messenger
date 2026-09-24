package com.cipher.messaging.domain;

import java.util.UUID;

/**
 * The public profile of a conversation member, as shown in the conversation list. The
 * messaging feature deliberately sees nothing else about an account.
 */
public record Participant(UUID userId, String username, String displayName) {
}
