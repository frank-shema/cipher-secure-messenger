package com.cipher.attachments.application.port.in;

import java.io.InputStream;
import java.time.Instant;
import java.util.UUID;

/**
 * An upload as the controller hands it over: who, for which conversation, the bytes as a
 * stream (never fully buffered by the relay) and the size the client declared.
 */
public record UploadBlobCommand(UUID uploaderId, UUID conversationId, InputStream content, long declaredSize,
                                Instant expiresAt) {
}
