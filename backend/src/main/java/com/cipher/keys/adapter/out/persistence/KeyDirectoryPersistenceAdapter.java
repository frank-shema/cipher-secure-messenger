package com.cipher.keys.adapter.out.persistence;

import com.cipher.keys.application.port.out.KeyDirectoryRepository;
import com.cipher.keys.domain.KeyBundle;
import java.util.Optional;
import java.util.UUID;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * JPA implementation of {@link KeyDirectoryRepository}: an upsert keyed by user id, since a
 * user has exactly one current bundle and rotation replaces it in place.
 */
@Component
public class KeyDirectoryPersistenceAdapter implements KeyDirectoryRepository {

    private final IdentityKeyJpaRepository repository;

    public KeyDirectoryPersistenceAdapter(IdentityKeyJpaRepository repository) {
        this.repository = repository;
    }

    @Override
    public Optional<KeyBundle> findByUserId(UUID userId) {
        return repository.findById(userId).map(KeyDirectoryPersistenceAdapter::toDomain);
    }

    @Override
    @Transactional
    public KeyBundle save(KeyBundle bundle) {
        IdentityKeyEntity entity = repository.findById(bundle.userId())
                .map(existing -> {
                    existing.replaceMaterial(bundle.identityKey(), bundle.signingKey(), bundle.version(),
                            bundle.updatedAt());
                    return existing;
                })
                .orElseGet(() -> new IdentityKeyEntity(bundle.userId(), bundle.identityKey(), bundle.signingKey(),
                        bundle.version(), bundle.createdAt(), bundle.updatedAt()));
        return toDomain(repository.saveAndFlush(entity));
    }

    static KeyBundle toDomain(IdentityKeyEntity entity) {
        return new KeyBundle(entity.getUserId(), entity.getIdentityKey(), entity.getSigningKey(), entity.getVersion(),
                entity.getCreatedAt(), entity.getUpdatedAt());
    }
}
