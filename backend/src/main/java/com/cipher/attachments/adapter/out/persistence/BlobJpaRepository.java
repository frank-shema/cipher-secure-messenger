package com.cipher.attachments.adapter.out.persistence;

import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface BlobJpaRepository extends JpaRepository<BlobEntity, UUID> {

    List<BlobEntity> findByExpiresAtBefore(Instant now);
}
