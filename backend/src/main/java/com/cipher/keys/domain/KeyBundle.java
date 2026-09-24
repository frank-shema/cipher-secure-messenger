package com.cipher.keys.domain;

import com.cipher.shared.domain.ProblemException;
import com.cipher.shared.domain.ProblemType;
import java.time.Instant;
import java.util.Arrays;
import java.util.UUID;

/**
 * A user's public identity material: a raw X25519 key for key agreement and a raw Ed25519 key
 * for signatures, plus the monotonically increasing version the client pins against.
 *
 * <p>Length is enforced here rather than in the DTO because the 32-byte invariant is what the
 * cryptography on the phone relies on, not a formatting preference of one endpoint. Arrays are
 * copied on the way in and out so no caller can mutate stored material.
 */
public record KeyBundle(UUID userId, byte[] identityKey, byte[] signingKey, int version, Instant createdAt,
                        Instant updatedAt) {

    public static final int KEY_LENGTH = 32;

    public KeyBundle {
        requireKeyLength(identityKey, "identityKey");
        requireKeyLength(signingKey, "signingKey");
        if (version < 1) {
            throw new IllegalArgumentException("version must be at least 1");
        }
        identityKey = identityKey.clone();
        signingKey = signingKey.clone();
    }

    public static KeyBundle initial(UUID userId, byte[] identityKey, byte[] signingKey, Instant now) {
        return new KeyBundle(userId, identityKey, signingKey, 1, now, now);
    }

    public KeyBundle rotate(byte[] newIdentityKey, byte[] newSigningKey, Instant now) {
        return new KeyBundle(userId, newIdentityKey, newSigningKey, version + 1, createdAt, now);
    }

    public boolean hasSameMaterial(byte[] otherIdentityKey, byte[] otherSigningKey) {
        return Arrays.equals(identityKey, otherIdentityKey) && Arrays.equals(signingKey, otherSigningKey);
    }

    @Override
    public byte[] identityKey() {
        return identityKey.clone();
    }

    @Override
    public byte[] signingKey() {
        return signingKey.clone();
    }

    /**
     * Rejects material that is not exactly 32 bytes with the protocol's {@code validation}
     * problem. Commands call this too so a malformed upload fails before any database access.
     */
    public static void requireKeyLength(byte[] key, String name) {
        if (key == null || key.length != KEY_LENGTH) {
            throw new ProblemException(ProblemType.VALIDATION,
                    name + " must decode to exactly " + KEY_LENGTH + " bytes");
        }
    }
}
