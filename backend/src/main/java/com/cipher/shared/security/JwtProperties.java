package com.cipher.shared.security;

import java.nio.charset.StandardCharsets;
import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;

/**
 * HS256 signing configuration bound from {@code cipher.jwt.*}.
 *
 * <p>The constructor validates eagerly so that a relay started with an empty or short
 * {@code JWT_SECRET} refuses to boot instead of silently issuing forgeable tokens. HS256 needs a
 * key of at least 256 bits, hence the 32-byte floor.
 */
@ConfigurationProperties(prefix = "cipher.jwt")
public record JwtProperties(String secret,
                            @DefaultValue("15m") Duration accessTokenTtl,
                            @DefaultValue("30d") Duration refreshTokenTtl) {

    public static final int MIN_SECRET_BYTES = 32;

    public JwtProperties {
        if (secret == null || secret.isBlank()) {
            throw new IllegalStateException(
                    "cipher.jwt.secret (env JWT_SECRET) is not set. Provide a random secret of at least "
                            + MIN_SECRET_BYTES + " bytes, e.g. `openssl rand -base64 48`.");
        }
        if (secret.getBytes(StandardCharsets.UTF_8).length < MIN_SECRET_BYTES) {
            throw new IllegalStateException(
                    "cipher.jwt.secret (env JWT_SECRET) is too short for HS256: at least "
                            + MIN_SECRET_BYTES + " bytes are required.");
        }
        if (accessTokenTtl == null || accessTokenTtl.isZero() || accessTokenTtl.isNegative()) {
            throw new IllegalStateException("cipher.jwt.access-token-ttl must be a positive duration.");
        }
        if (refreshTokenTtl == null || refreshTokenTtl.isZero() || refreshTokenTtl.isNegative()) {
            throw new IllegalStateException("cipher.jwt.refresh-token-ttl must be a positive duration.");
        }
    }

    public byte[] secretBytes() {
        return secret.getBytes(StandardCharsets.UTF_8);
    }
}
