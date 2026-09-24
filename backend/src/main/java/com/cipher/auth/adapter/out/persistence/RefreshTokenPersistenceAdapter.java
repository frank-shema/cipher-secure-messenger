package com.cipher.auth.adapter.out.persistence;

import com.cipher.auth.application.port.out.RefreshTokenRepository;
import com.cipher.auth.domain.RefreshToken;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * JPA implementation of {@link RefreshTokenRepository}. Revocation is a conditional bulk update
 * so that concurrent rotations of one token resolve atomically in the database.
 */
@Component
public class RefreshTokenPersistenceAdapter implements RefreshTokenRepository {

    private final RefreshTokenJpaRepository repository;

    public RefreshTokenPersistenceAdapter(RefreshTokenJpaRepository repository) {
        this.repository = repository;
    }

    @Override
    @Transactional
    public RefreshToken save(RefreshToken token) {
        RefreshTokenEntity entity = new RefreshTokenEntity(token.id(), token.userId(), token.tokenHash(),
                token.expiresAt(), token.revokedAt(), token.createdAt());
        return toDomain(repository.save(entity));
    }

    @Override
    public Optional<RefreshToken> findByTokenHash(String tokenHash) {
        return repository.findByTokenHash(tokenHash).map(RefreshTokenPersistenceAdapter::toDomain);
    }

    @Override
    @Transactional
    public boolean revoke(UUID tokenId, Instant revokedAt) {
        return repository.revokeIfActive(tokenId, revokedAt) == 1;
    }

    static RefreshToken toDomain(RefreshTokenEntity entity) {
        return new RefreshToken(entity.getId(), entity.getUserId(), entity.getTokenHash(), entity.getExpiresAt(),
                entity.getRevokedAt(), entity.getCreatedAt());
    }
}
