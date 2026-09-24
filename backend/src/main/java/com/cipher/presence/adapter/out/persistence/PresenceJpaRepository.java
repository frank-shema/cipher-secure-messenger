package com.cipher.presence.adapter.out.persistence;

import com.cipher.auth.adapter.out.persistence.UserEntity;
import java.time.Instant;
import java.util.UUID;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.Repository;
import org.springframework.data.repository.query.Param;

/**
 * A single-column update on {@code users}, kept out of the auth feature because
 * {@code last_seen_at} is presence state that must never be touched by an account re-save.
 */
public interface PresenceJpaRepository extends Repository<UserEntity, UUID> {

    @Modifying
    @Query("update UserEntity u set u.lastSeenAt = :at where u.id = :userId")
    int recordLastSeen(@Param("userId") UUID userId, @Param("at") Instant at);
}
