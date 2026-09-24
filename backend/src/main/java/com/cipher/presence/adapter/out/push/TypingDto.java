package com.cipher.presence.adapter.out.push;

import java.util.UUID;

/**
 * Payload of {@code typing.start} and {@code typing.stop} frames as relayed to the recipient.
 */
record TypingDto(UUID conversationId, UUID userId) {
}
