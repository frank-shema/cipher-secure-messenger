package com.cipher.attachments.adapter.out.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "blobs")
public class BlobEntity {

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "conversation_id", nullable = false, updatable = false)
    private UUID conversationId;

    @Column(name = "uploader_id", nullable = false, updatable = false)
    private UUID uploaderId;

    @Column(name = "size", nullable = false, updatable = false)
    private long size;

    @Column(name = "storage_key", nullable = false, updatable = false, length = 255)
    private String storageKey;

    @Column(name = "expires_at")
    private Instant expiresAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    protected BlobEntity() {
    }

    BlobEntity(UUID id, UUID conversationId, UUID uploaderId, long size, String storageKey, Instant expiresAt,
               Instant createdAt) {
        this.id = id;
        this.conversationId = conversationId;
        this.uploaderId = uploaderId;
        this.size = size;
        this.storageKey = storageKey;
        this.expiresAt = expiresAt;
        this.createdAt = createdAt;
    }

    UUID getId() {
        return id;
    }

    UUID getConversationId() {
        return conversationId;
    }

    UUID getUploaderId() {
        return uploaderId;
    }

    long getSize() {
        return size;
    }

    String getStorageKey() {
        return storageKey;
    }

    Instant getExpiresAt() {
        return expiresAt;
    }

    Instant getCreatedAt() {
        return createdAt;
    }
}
