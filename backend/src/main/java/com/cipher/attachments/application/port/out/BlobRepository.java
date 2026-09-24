package com.cipher.attachments.application.port.out;

import com.cipher.attachments.domain.Blob;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Persistence port for blob bookkeeping rows.
 */
public interface BlobRepository {

    Optional<Blob> findById(UUID id);

    Blob save(Blob blob);

    void delete(UUID id);

    List<Blob> findExpiredBefore(Instant now);
}
