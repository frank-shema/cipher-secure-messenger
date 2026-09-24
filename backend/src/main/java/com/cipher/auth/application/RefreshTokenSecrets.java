package com.cipher.auth.application;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.util.Base64;
import java.util.HexFormat;

/**
 * Generates and digests refresh tokens.
 *
 * <p>Tokens are 32 random bytes rendered as unpadded base64url, which is URL- and JSON-safe and
 * carries 256 bits of entropy. Only the SHA-256 hex digest is persisted: because the token is
 * already high-entropy, a plain hash (no salt, no BCrypt) is sufficient and keeps lookups by
 * digest a simple indexed equality.
 */
final class RefreshTokenSecrets {

    static final int TOKEN_BYTES = 32;

    private static final Base64.Encoder ENCODER = Base64.getUrlEncoder().withoutPadding();
    private static final HexFormat HEX = HexFormat.of();

    private RefreshTokenSecrets() {
    }

    static String generate(SecureRandom random) {
        byte[] bytes = new byte[TOKEN_BYTES];
        random.nextBytes(bytes);
        return ENCODER.encodeToString(bytes);
    }

    static String hash(String token) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return HEX.formatHex(digest.digest(token.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 is mandatory in every Java runtime", e);
        }
    }
}
