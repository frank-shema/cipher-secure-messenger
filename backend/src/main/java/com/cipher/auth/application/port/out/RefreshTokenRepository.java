package com.cipher.auth.application.port.out;

import com.cipher.auth.domain.RefreshToken;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

/**
 * Persistence port for refresh sessions, keyed by token digest so the clear token never needs
 * to be stored or compared.
 */
public interface RefreshTokenRepository {

    RefreshToken save(RefreshToken token);

    Optional<RefreshToken> findByTokenHash(String tokenHash);

    /**
     * Revokes the token only if it is still active.
     *
     * @return {@code true} when this call performed the revocation; {@code false} when the token
     *         was already revoked, which lets two concurrent refreshes of the same token race
     *         safely with exactly one winner
     */
    boolean revoke(UUID tokenId, Instant revokedAt);
}
