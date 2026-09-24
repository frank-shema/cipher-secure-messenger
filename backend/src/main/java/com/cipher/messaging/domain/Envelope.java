package com.cipher.messaging.domain;

import com.cipher.shared.domain.ProblemException;
import com.cipher.shared.domain.ProblemType;
import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

/**
 * An opaque, stored message.
 *
 * <p>The relay validates only what it needs to route and to protect itself: routing ids, the
 * size ceiling on the ciphertext, the fixed Ed25519 signature length and a sane expiry. It
 * never verifies the signature (it does not know the sender's key pinning state) and never
 * inspects the ciphertext. Byte arrays are copied on the way in and out so a stored envelope
 * cannot be mutated through a reference.
 */
public record Envelope(UUID id,
                       UUID conversationId,
                       UUID senderId,
                       UUID recipientId,
                       long counter,
                       long clientTimestamp,
                       byte[] ciphertext,
                       byte[] signature,
                       Instant expiresAt,
                       DeliveryStatus status,
                       Instant createdAt,
                       Instant deliveredAt,
                       Instant readAt) {

    public static final int MAX_CIPHERTEXT_BYTES = 256 * 1024;
    public static final int SIGNATURE_LENGTH = 64;

    public Envelope {
        Objects.requireNonNull(id, "id");
        Objects.requireNonNull(conversationId, "conversationId");
        Objects.requireNonNull(senderId, "senderId");
        Objects.requireNonNull(recipientId, "recipientId");
        Objects.requireNonNull(status, "status");
        Objects.requireNonNull(createdAt, "createdAt");
        if (senderId.equals(recipientId)) {
            throw new ProblemException(ProblemType.VALIDATION, "recipientId must differ from senderId");
        }
        if (counter < 0) {
            throw new ProblemException(ProblemType.VALIDATION, "counter must be greater than or equal to 0");
        }
        requireCiphertextSize(ciphertext);
        requireSignatureLength(signature);
        ciphertext = ciphertext.clone();
        signature = signature.clone();
    }

    /**
     * A freshly accepted envelope, before any receipt.
     */
    public static Envelope sent(UUID id, UUID conversationId, UUID senderId, UUID recipientId, long counter,
                                long clientTimestamp, byte[] ciphertext, byte[] signature, Instant expiresAt,
                                Instant now) {
        if (expiresAt != null && !expiresAt.isAfter(now)) {
            throw new ProblemException(ProblemType.VALIDATION, "expiresAt must be null or in the future");
        }
        return new Envelope(id, conversationId, senderId, recipientId, counter, clientTimestamp, ciphertext, signature,
                expiresAt, DeliveryStatus.SENT, now, null, null);
    }

    public Envelope delivered(Instant at) {
        if (status != DeliveryStatus.SENT) {
            return this;
        }
        return new Envelope(id, conversationId, senderId, recipientId, counter, clientTimestamp, ciphertext, signature,
                expiresAt, DeliveryStatus.DELIVERED, createdAt, at, readAt);
    }

    public Envelope read(Instant at) {
        if (status == DeliveryStatus.READ) {
            return this;
        }
        Instant deliveredMoment = deliveredAt != null ? deliveredAt : at;
        return new Envelope(id, conversationId, senderId, recipientId, counter, clientTimestamp, ciphertext, signature,
                expiresAt, DeliveryStatus.READ, createdAt, deliveredMoment, at);
    }

    public boolean isExpiredAt(Instant now) {
        return expiresAt != null && !expiresAt.isAfter(now);
    }

    @Override
    public byte[] ciphertext() {
        return ciphertext.clone();
    }

    @Override
    public byte[] signature() {
        return signature.clone();
    }

    public int ciphertextSize() {
        return ciphertext.length;
    }

    public static void requireCiphertextSize(byte[] ciphertext) {
        if (ciphertext == null || ciphertext.length == 0) {
            throw new ProblemException(ProblemType.VALIDATION, "ciphertext must not be empty");
        }
        if (ciphertext.length > MAX_CIPHERTEXT_BYTES) {
            throw new ProblemException(ProblemType.PAYLOAD_TOO_LARGE,
                    "ciphertext exceeds the maximum of " + MAX_CIPHERTEXT_BYTES + " bytes");
        }
    }

    public static void requireSignatureLength(byte[] signature) {
        if (signature == null || signature.length != SIGNATURE_LENGTH) {
            throw new ProblemException(ProblemType.VALIDATION,
                    "signature must decode to exactly " + SIGNATURE_LENGTH + " bytes");
        }
    }
}
