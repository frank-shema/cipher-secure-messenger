package com.cipher.attachments.domain;

import com.cipher.shared.domain.ProblemException;
import com.cipher.shared.domain.ProblemType;
import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

/**
 * Bookkeeping for one encrypted attachment.
 *
 * <p>The relay knows the bytes' size, where it put them and who may fetch them (the members of
 * the conversation). Filename, MIME type and the content key travel inside the message
 * ciphertext and never reach this record, which is what keeps the relay blind to what was
 * shared.
 */
public record Blob(UUID id, UUID conversationId, UUID uploaderId, long size, String storageKey, Instant expiresAt,
                   Instant createdAt) {

    public Blob {
        Objects.requireNonNull(id, "id");
        Objects.requireNonNull(conversationId, "conversationId");
        Objects.requireNonNull(uploaderId, "uploaderId");
        Objects.requireNonNull(storageKey, "storageKey");
        Objects.requireNonNull(createdAt, "createdAt");
        if (size < 0) {
            throw new IllegalArgumentException("size must not be negative");
        }
    }

    /**
     * A freshly stored blob. Expiry is validated here, like an envelope's, because the purge
     * job is the only consumer and a past expiry would make the upload pointless.
     */
    public static Blob create(UUID id, UUID conversationId, UUID uploaderId, long size, String storageKey,
                              Instant expiresAt, Instant now) {
        if (expiresAt != null && !expiresAt.isAfter(now)) {
            throw new ProblemException(ProblemType.VALIDATION, "expiresAt must be null or in the future");
        }
        return new Blob(id, conversationId, uploaderId, size, storageKey, expiresAt, now);
    }

    public boolean isExpiredAt(Instant now) {
        return expiresAt != null && !expiresAt.isAfter(now);
    }
}
