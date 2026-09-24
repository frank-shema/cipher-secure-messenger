package com.cipher.messaging.adapter.out.directory;

import com.cipher.auth.adapter.out.persistence.UserEntity;
import com.cipher.messaging.domain.Participant;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.Repository;
import org.springframework.data.repository.query.Param;

/**
 * Read-only projection of accounts onto {@link Participant}, selected straight from the
 * {@code users} table so the password hash is never even loaded into memory for this feature.
 */
public interface ParticipantJpaRepository extends Repository<UserEntity, UUID> {

    @Query("select new com.cipher.messaging.domain.Participant(u.id, u.username, u.displayName) "
            + "from UserEntity u where u.id = :id")
    Optional<Participant> findParticipantById(@Param("id") UUID id);

    @Query("select new com.cipher.messaging.domain.Participant(u.id, u.username, u.displayName) "
            + "from UserEntity u where u.id in :ids")
    List<Participant> findParticipantsById(@Param("ids") Collection<UUID> ids);
}
