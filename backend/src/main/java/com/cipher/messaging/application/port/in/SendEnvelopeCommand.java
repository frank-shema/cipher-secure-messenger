package com.cipher.messaging.application.port.in;

import java.time.Instant;
import java.util.UUID;

/**
 * Everything the relay needs to store and route one envelope. {@code principalId} is the
 * authenticated caller and is compared against {@code senderId} in the use case, never trusted
 * from the body alone.
 */
public record SendEnvelopeCommand(UUID principalId,
                                  UUID pathConversationId,
                                  UUID id,
                                  UUID conversationId,
                                  UUID senderId,
                                  UUID recipientId,
                                  long counter,
                                  long clientTimestamp,
                                  byte[] ciphertext,
                                  byte[] signature,
                                  Instant expiresAt) {
}
