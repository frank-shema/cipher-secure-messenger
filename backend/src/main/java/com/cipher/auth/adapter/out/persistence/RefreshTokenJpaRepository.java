package com.cipher.auth.adapter.out.persistence;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface RefreshTokenJpaRepository extends JpaRepository<RefreshTokenEntity, UUID> {

    Optional<RefreshTokenEntity> findByTokenHash(String tokenHash);

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update RefreshTokenEntity t set t.revokedAt = :revokedAt where t.id = :id and t.revokedAt is null")
    int revokeIfActive(@Param("id") UUID id, @Param("revokedAt") Instant revokedAt);
}
