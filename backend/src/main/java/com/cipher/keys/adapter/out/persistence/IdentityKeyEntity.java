package com.cipher.keys.adapter.out.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "identity_keys")
public class IdentityKeyEntity {

    @Id
    @Column(name = "user_id", nullable = false, updatable = false)
    private UUID userId;

    @Column(name = "identity_key", nullable = false)
    private byte[] identityKey;

    @Column(name = "signing_key", nullable = false)
    private byte[] signingKey;

    @Column(name = "version", nullable = false)
    private int version;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected IdentityKeyEntity() {
    }

    IdentityKeyEntity(UUID userId, byte[] identityKey, byte[] signingKey, int version, Instant createdAt,
                      Instant updatedAt) {
        this.userId = userId;
        this.identityKey = identityKey;
        this.signingKey = signingKey;
        this.version = version;
        this.createdAt = createdAt;
        this.updatedAt = updatedAt;
    }

    UUID getUserId() {
        return userId;
    }

    byte[] getIdentityKey() {
        return identityKey;
    }

    byte[] getSigningKey() {
        return signingKey;
    }

    int getVersion() {
        return version;
    }

    Instant getCreatedAt() {
        return createdAt;
    }

    Instant getUpdatedAt() {
        return updatedAt;
    }

    void replaceMaterial(byte[] newIdentityKey, byte[] newSigningKey, int newVersion, Instant at) {
        this.identityKey = newIdentityKey;
        this.signingKey = newSigningKey;
        this.version = newVersion;
        this.updatedAt = at;
    }
}
