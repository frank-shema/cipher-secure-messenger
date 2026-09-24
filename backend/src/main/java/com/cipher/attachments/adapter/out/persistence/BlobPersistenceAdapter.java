package com.cipher.attachments.adapter.out.persistence;

import com.cipher.attachments.application.port.out.BlobRepository;
import com.cipher.attachments.domain.Blob;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * JPA implementation of {@link BlobRepository}. Rows are immutable once written: a blob is
 * created, read and eventually deleted, never updated.
 */
@Component
public class BlobPersistenceAdapter implements BlobRepository {

    private final BlobJpaRepository repository;

    public BlobPersistenceAdapter(BlobJpaRepository repository) {
        this.repository = repository;
    }

    @Override
    public Optional<Blob> findById(UUID id) {
        return repository.findById(id).map(BlobPersistenceAdapter::toDomain);
    }

    @Override
    @Transactional
    public Blob save(Blob blob) {
        return toDomain(repository.saveAndFlush(new BlobEntity(blob.id(), blob.conversationId(), blob.uploaderId(),
                blob.size(), blob.storageKey(), blob.expiresAt(), blob.createdAt())));
    }

    @Override
    @Transactional
    public void delete(UUID id) {
        repository.deleteById(id);
    }

    @Override
    public List<Blob> findExpiredBefore(Instant now) {
        return repository.findByExpiresAtBefore(now).stream().map(BlobPersistenceAdapter::toDomain).toList();
    }

    static Blob toDomain(BlobEntity entity) {
        return new Blob(entity.getId(), entity.getConversationId(), entity.getUploaderId(), entity.getSize(),
                entity.getStorageKey(), entity.getExpiresAt(), entity.getCreatedAt());
    }
}
