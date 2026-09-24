package com.cipher.messaging.adapter.out.persistence;

import com.cipher.messaging.application.port.out.ConversationRepository;
import com.cipher.messaging.domain.Conversation;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Component;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * JPA implementation of {@link ConversationRepository}.
 *
 * <p>{@link #save} runs the insert in its own transaction so that, when two users create the
 * same conversation concurrently, the loser's primary-key violation rolls back only that
 * insert and the winner's row can be read back immediately. Doing this inside the caller's
 * transaction would poison it (Spring marks it rollback-only) and turn a benign race into a 500.
 */
@Component
public class ConversationPersistenceAdapter implements ConversationRepository {

    private static final Logger log = LoggerFactory.getLogger(ConversationPersistenceAdapter.class);

    private final ConversationJpaRepository repository;
    private final TransactionTemplate insertTransaction;

    public ConversationPersistenceAdapter(ConversationJpaRepository repository,
                                          PlatformTransactionManager transactionManager) {
        this.repository = repository;
        this.insertTransaction = new TransactionTemplate(transactionManager);
        this.insertTransaction.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
    }

    @Override
    public Optional<Conversation> findById(UUID id) {
        return repository.findById(id).map(ConversationPersistenceAdapter::toDomain);
    }

    @Override
    public List<Conversation> findAllInvolving(UUID userId) {
        return repository.findAllInvolving(userId).stream().map(ConversationPersistenceAdapter::toDomain).toList();
    }

    @Override
    public Conversation save(Conversation conversation) {
        try {
            ConversationEntity inserted = insertTransaction.execute(status -> repository.saveAndFlush(
                    new ConversationEntity(conversation.id(), conversation.participantA(), conversation.participantB(),
                            conversation.createdAt(), conversation.lastMessageAt())));
            return toDomain(inserted);
        } catch (DataIntegrityViolationException raced) {
            log.debug("Conversation {} was created concurrently; returning the existing row", conversation.id());
            return repository.findById(conversation.id())
                    .map(ConversationPersistenceAdapter::toDomain)
                    .orElseThrow(() -> raced);
        }
    }

    @Override
    @Transactional
    public void recordMessageAt(UUID conversationId, Instant at) {
        repository.recordMessageAt(conversationId, at);
    }

    static Conversation toDomain(ConversationEntity entity) {
        return new Conversation(entity.getId(), entity.getParticipantA(), entity.getParticipantB(), entity.getCreatedAt(),
                entity.getLastMessageAt());
    }
}
