package com.cipher.messaging.adapter.out.persistence;

import com.cipher.messaging.domain.DeliveryStatus;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "envelopes")
public class EnvelopeEntity {

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "conversation_id", nullable = false, updatable = false)
    private UUID conversationId;

    @Column(name = "sender_id", nullable = false, updatable = false)
    private UUID senderId;

    @Column(name = "recipient_id", nullable = false, updatable = false)
    private UUID recipientId;

    @Column(name = "counter", nullable = false, updatable = false)
    private long counter;

    @Column(name = "client_timestamp", nullable = false, updatable = false)
    private long clientTimestamp;

    @Column(name = "ciphertext", nullable = false, updatable = false)
    private byte[] ciphertext;

    @Column(name = "signature", nullable = false, updatable = false)
    private byte[] signature;

    @Column(name = "expires_at")
    private Instant expiresAt;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 16)
    private DeliveryStatus status;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "delivered_at")
    private Instant deliveredAt;

    @Column(name = "read_at")
    private Instant readAt;

    protected EnvelopeEntity() {
    }

    EnvelopeEntity(UUID id, UUID conversationId, UUID senderId, UUID recipientId, long counter, long clientTimestamp,
                   byte[] ciphertext, byte[] signature, Instant expiresAt, DeliveryStatus status, Instant createdAt,
                   Instant deliveredAt, Instant readAt) {
        this.id = id;
        this.conversationId = conversationId;
        this.senderId = senderId;
        this.recipientId = recipientId;
        this.counter = counter;
        this.clientTimestamp = clientTimestamp;
        this.ciphertext = ciphertext;
        this.signature = signature;
        this.expiresAt = expiresAt;
        this.status = status;
        this.createdAt = createdAt;
        this.deliveredAt = deliveredAt;
        this.readAt = readAt;
    }

    UUID getId() {
        return id;
    }

    UUID getConversationId() {
        return conversationId;
    }

    UUID getSenderId() {
        return senderId;
    }

    UUID getRecipientId() {
        return recipientId;
    }

    long getCounter() {
        return counter;
    }

    long getClientTimestamp() {
        return clientTimestamp;
    }

    byte[] getCiphertext() {
        return ciphertext;
    }

    byte[] getSignature() {
        return signature;
    }

    Instant getExpiresAt() {
        return expiresAt;
    }

    DeliveryStatus getStatus() {
        return status;
    }

    Instant getCreatedAt() {
        return createdAt;
    }

    Instant getDeliveredAt() {
        return deliveredAt;
    }

    Instant getReadAt() {
        return readAt;
    }

    /**
     * Status is the only mutable part of a stored envelope; the ciphertext columns are
     * {@code updatable = false} so a bug can never rewrite what a client signed.
     */
    void applyStatus(DeliveryStatus newStatus, Instant newDeliveredAt, Instant newReadAt) {
        this.status = newStatus;
        this.deliveredAt = newDeliveredAt;
        this.readAt = newReadAt;
    }
}
