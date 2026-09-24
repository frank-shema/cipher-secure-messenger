package com.cipher.messaging.adapter.out.persistence;

import com.cipher.messaging.domain.DeliveryStatus;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.data.domain.Limit;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface EnvelopeJpaRepository extends JpaRepository<EnvelopeEntity, UUID> {

    List<EnvelopeEntity> findByConversationIdOrderByCreatedAtDescIdDesc(UUID conversationId, Limit limit);

    List<EnvelopeEntity> findByConversationIdAndCreatedAtBeforeOrderByCreatedAtDescIdDesc(UUID conversationId,
                                                                                          Instant before, Limit limit);

    List<EnvelopeEntity> findByRecipientIdAndStatusOrderByCreatedAtAscIdAsc(UUID recipientId, DeliveryStatus status);

    @Modifying
    @Query("delete from EnvelopeEntity e where e.expiresAt is not null and e.expiresAt < :now")
    int deleteExpiredBefore(@Param("now") Instant now);
}
