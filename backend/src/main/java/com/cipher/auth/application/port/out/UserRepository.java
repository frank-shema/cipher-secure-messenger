package com.cipher.auth.application.port.out;

import com.cipher.auth.domain.User;
import java.util.Optional;
import java.util.UUID;

/**
 * Persistence port for accounts. Usernames passed in are expected to be normalised (lowercase)
 * by the caller; the store treats them as exact keys.
 */
public interface UserRepository {

    Optional<User> findByUsername(String username);

    Optional<User> findById(UUID id);

    boolean existsByUsername(String username);

    /**
     * Persists the user. Implementations must translate a concurrent duplicate-username insert
     * into {@code ProblemType.USERNAME_TAKEN}, because the pre-check in the use case cannot be
     * atomic with the insert.
     */
    User save(User user);
}
