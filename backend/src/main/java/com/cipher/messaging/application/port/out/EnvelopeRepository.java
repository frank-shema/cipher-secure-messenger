package com.cipher.messaging.application.port.out;

import com.cipher.messaging.domain.Envelope;
import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Persistence port for stored envelopes. Page queries return newest first; the pending query
 * returns oldest first because replay order matters to the client's counter check.
 */
public interface EnvelopeRepository {

    Optional<Envelope> findById(UUID id);

    List<Envelope> findAllById(Collection<UUID> ids);

    Envelope save(Envelope envelope);

    List<Envelope> saveAll(Collection<Envelope> envelopes);

    /**
     * Up to {@code limit} envelopes of the conversation created strictly before {@code before}
     * ({@code null} for no upper bound), newest first.
     */
    List<Envelope> findPage(UUID conversationId, Instant before, int limit);

    List<Envelope> findPendingForRecipient(UUID recipientId);

    int deleteExpiredBefore(Instant now);
}
