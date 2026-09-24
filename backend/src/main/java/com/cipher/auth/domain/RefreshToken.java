package com.cipher.auth.domain;

import java.time.Instant;
import java.util.UUID;

/**
 * A refresh session. Only the SHA-256 digest of the opaque token is stored, so a database leak
 * does not hand out usable sessions; a token is usable until it is either revoked or expired.
 */
public record RefreshToken(UUID id, UUID userId, String tokenHash, Instant expiresAt, Instant revokedAt, Instant createdAt) {

    public boolean isActive(Instant now) {
        return revokedAt == null && expiresAt.isAfter(now);
    }
}
