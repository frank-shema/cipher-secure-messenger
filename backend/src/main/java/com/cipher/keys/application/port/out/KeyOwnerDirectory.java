package com.cipher.keys.application.port.out;

import com.cipher.keys.domain.KeyOwner;
import java.util.Optional;

import java.util.UUID;

/**
 * Read-only view of accounts for the keys feature. Exists so keys depends on a narrow port
 * rather than on the auth feature's aggregate, keeping the two features separable.
 */
public interface KeyOwnerDirectory {

    Optional<KeyOwner> findById(UUID userId);

    Optional<KeyOwner> findByUsername(String username);
}
