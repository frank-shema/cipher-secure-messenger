package com.cipher.messaging.domain;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.List;
import java.util.Objects;
import java.util.UUID;

/**
 * A 1:1 conversation between two users.
 *
 * <p>The participant pair is canonical (sorted by UUID string) and the id is derived from it,
 * so two clients creating "the" conversation concurrently converge on the same row without a
 * lookup-then-insert race and the iOS client can predict the id offline. The relay knows
 * nothing else about a conversation: no title, no members beyond the pair, no content.
 */
public record Conversation(UUID id, UUID participantA, UUID participantB, Instant createdAt, Instant lastMessageAt) {

    private static final String ID_NAMESPACE = "cipher/conv/";

    public Conversation {
        Objects.requireNonNull(id, "id");
        Objects.requireNonNull(participantA, "participantA");
        Objects.requireNonNull(participantB, "participantB");
        Objects.requireNonNull(createdAt, "createdAt");
        if (participantA.equals(participantB)) {
            throw new IllegalArgumentException("A conversation needs two distinct participants");
        }
        if (compare(participantA, participantB) > 0) {
            throw new IllegalArgumentException("Participants must be stored in canonical order");
        }
    }

    /**
     * Builds the canonical conversation for an unordered pair of users.
     */
    public static Conversation between(UUID first, UUID second, Instant now) {
        UUID a = compare(first, second) <= 0 ? first : second;
        UUID b = a.equals(first) ? second : first;
        return new Conversation(idFor(a, b), a, b, now, null);
    }

    /**
     * Deterministic id for a canonical pair: {@code UUID.nameUUIDFromBytes("cipher/conv/" + a + "|" + b)}.
     */
    public static UUID idFor(UUID first, UUID second) {
        UUID a = compare(first, second) <= 0 ? first : second;
        UUID b = a.equals(first) ? second : first;
        return UUID.nameUUIDFromBytes((ID_NAMESPACE + a + "|" + b).getBytes(StandardCharsets.UTF_8));
    }

    public boolean involves(UUID userId) {
        return participantA.equals(userId) || participantB.equals(userId);
    }

    public UUID otherParticipant(UUID userId) {
        if (participantA.equals(userId)) {
            return participantB;
        }
        if (participantB.equals(userId)) {
            return participantA;
        }
        throw new IllegalArgumentException("User is not a participant of this conversation");
    }

    public List<UUID> participants() {
        return List.of(participantA, participantB);
    }

    public Conversation withLastMessageAt(Instant at) {
        if (lastMessageAt != null && !at.isAfter(lastMessageAt)) {
            return this;
        }
        return new Conversation(id, participantA, participantB, createdAt, at);
    }

    private static int compare(UUID first, UUID second) {
        return first.toString().compareTo(second.toString());
    }
}
