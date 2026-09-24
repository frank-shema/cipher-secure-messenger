package com.cipher.messaging.adapter.out.persistence;

import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ConversationJpaRepository extends JpaRepository<ConversationEntity, UUID> {

    @Query("""
            select c from ConversationEntity c
            where c.participantA = :userId or c.participantB = :userId
            order by coalesce(c.lastMessageAt, c.createdAt) desc, c.id asc
            """)
    List<ConversationEntity> findAllInvolving(@Param("userId") UUID userId);

    @Query("""
            select case when c.participantA = :userId then c.participantB else c.participantA end
            from ConversationEntity c
            where c.participantA = :userId or c.participantB = :userId
            """)
    List<UUID> findContactIds(@Param("userId") UUID userId);

    @Modifying
    @Query("""
            update ConversationEntity c set c.lastMessageAt = :at
            where c.id = :id and (c.lastMessageAt is null or c.lastMessageAt < :at)
            """)
    int recordMessageAt(@Param("id") UUID id, @Param("at") Instant at);
}
