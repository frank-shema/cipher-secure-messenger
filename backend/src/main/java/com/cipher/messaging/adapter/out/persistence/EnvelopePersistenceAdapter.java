package com.cipher.messaging.adapter.out.persistence;

import com.cipher.messaging.application.port.out.EnvelopeRepository;
import com.cipher.messaging.domain.DeliveryStatus;
import com.cipher.messaging.domain.Envelope;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.data.domain.Limit;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * JPA implementation of {@link EnvelopeRepository}.
 *
 * <p>Inserts and status updates go through the same {@code save} so the application layer
 * never has to know whether an envelope is new; the entity itself only permits the status
 * columns to change. Page queries lean on the {@code (conversation_id, created_at desc)} index
 * and fetch one row more than asked so the caller can compute {@code hasMore} without a count.
 */
@Component
public class EnvelopePersistenceAdapter implements EnvelopeRepository {

    private final EnvelopeJpaRepository repository;

    public EnvelopePersistenceAdapter(EnvelopeJpaRepository repository) {
        this.repository = repository;
    }

    @Override
    public Optional<Envelope> findById(UUID id) {
        return repository.findById(id).map(EnvelopePersistenceAdapter::toDomain);
    }

    @Override
    public List<Envelope> findAllById(Collection<UUID> ids) {
        if (ids.isEmpty()) {
            return List.of();
        }
        return repository.findAllById(ids).stream().map(EnvelopePersistenceAdapter::toDomain).toList();
    }

    @Override
    @Transactional
    public Envelope save(Envelope envelope) {
        return toDomain(repository.saveAndFlush(merge(envelope, repository.findById(envelope.id()))));
    }

    @Override
    @Transactional
    public List<Envelope> saveAll(Collection<Envelope> envelopes) {
        if (envelopes.isEmpty()) {
            return List.of();
        }
        Map<UUID, EnvelopeEntity> existing = repository
                .findAllById(envelopes.stream().map(Envelope::id).toList()).stream()
                .collect(Collectors.toMap(EnvelopeEntity::getId, Function.identity()));
        List<EnvelopeEntity> merged = new ArrayList<>(envelopes.size());
        for (Envelope envelope : envelopes) {
            merged.add(merge(envelope, Optional.ofNullable(existing.get(envelope.id()))));
        }
        List<Envelope> saved = repository.saveAllAndFlush(merged).stream()
                .map(EnvelopePersistenceAdapter::toDomain)
                .toList();
        return saved;
    }

    @Override
    public List<Envelope> findPage(UUID conversationId, Instant before, int limit) {
        List<EnvelopeEntity> rows = before == null
                ? repository.findByConversationIdOrderByCreatedAtDescIdDesc(conversationId, Limit.of(limit))
                : repository.findByConversationIdAndCreatedAtBeforeOrderByCreatedAtDescIdDesc(conversationId, before,
                        Limit.of(limit));
        return rows.stream().map(EnvelopePersistenceAdapter::toDomain).toList();
    }

    @Override
    public List<Envelope> findPendingForRecipient(UUID recipientId) {
        return repository.findByRecipientIdAndStatusOrderByCreatedAtAscIdAsc(recipientId, DeliveryStatus.SENT).stream()
                .map(EnvelopePersistenceAdapter::toDomain)
                .toList();
    }

    @Override
    @Transactional
    public int deleteExpiredBefore(Instant now) {
        return repository.deleteExpiredBefore(now);
    }

    private static EnvelopeEntity merge(Envelope envelope, Optional<EnvelopeEntity> existing) {
        return existing
                .map(entity -> {
                    entity.applyStatus(envelope.status(), envelope.deliveredAt(), envelope.readAt());
                    return entity;
                })
                .orElseGet(() -> new EnvelopeEntity(envelope.id(), envelope.conversationId(), envelope.senderId(),
                        envelope.recipientId(), envelope.counter(), envelope.clientTimestamp(), envelope.ciphertext(),
                        envelope.signature(), envelope.expiresAt(), envelope.status(), envelope.createdAt(),
                        envelope.deliveredAt(), envelope.readAt()));
    }

    static Envelope toDomain(EnvelopeEntity entity) {
        return new Envelope(entity.getId(), entity.getConversationId(), entity.getSenderId(), entity.getRecipientId(),
                entity.getCounter(), entity.getClientTimestamp(), entity.getCiphertext(), entity.getSignature(),
                entity.getExpiresAt(), entity.getStatus(), entity.getCreatedAt(), entity.getDeliveredAt(),
                entity.getReadAt());
    }
}
