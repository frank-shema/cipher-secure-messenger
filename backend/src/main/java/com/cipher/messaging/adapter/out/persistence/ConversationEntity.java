package com.cipher.messaging.adapter.out.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "conversations")
public class ConversationEntity {

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "participant_a", nullable = false, updatable = false)
    private UUID participantA;

    @Column(name = "participant_b", nullable = false, updatable = false)
    private UUID participantB;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "last_message_at")
    private Instant lastMessageAt;

    protected ConversationEntity() {
    }

    ConversationEntity(UUID id, UUID participantA, UUID participantB, Instant createdAt, Instant lastMessageAt) {
        this.id = id;
        this.participantA = participantA;
        this.participantB = participantB;
        this.createdAt = createdAt;
        this.lastMessageAt = lastMessageAt;
    }

    UUID getId() {
        return id;
    }

    UUID getParticipantA() {
        return participantA;
    }

    UUID getParticipantB() {
        return participantB;
    }

    Instant getCreatedAt() {
        return createdAt;
    }

    Instant getLastMessageAt() {
        return lastMessageAt;
    }
}
