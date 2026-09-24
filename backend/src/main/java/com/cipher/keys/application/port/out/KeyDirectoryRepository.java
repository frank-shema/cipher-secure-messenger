package com.cipher.keys.application.port.out;

import com.cipher.keys.domain.KeyBundle;
import java.util.Optional;
import java.util.UUID;

/**
 * Persistence port for key bundles; one bundle per user, replaced in place on rotation.
 */
public interface KeyDirectoryRepository {

    Optional<KeyBundle> findByUserId(UUID userId);

    KeyBundle save(KeyBundle bundle);
}
