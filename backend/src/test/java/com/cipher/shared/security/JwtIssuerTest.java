package com.cipher.shared.security;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtException;

class JwtIssuerTest {

    private static final Instant NOW = Instant.parse("2026-09-24T10:00:00Z");
    private static final JwtProperties PROPERTIES = new JwtProperties(
            "test-only-secret-not-for-production-use-0123456789abcdef", Duration.ofMinutes(15), Duration.ofDays(30));

    private final JwtConfig config = new JwtConfig();

    @Test
    void issuesTokensTheDecoderAcceptsWithTheProtocolClaims() {
        Clock clock = Clock.fixed(NOW, ZoneOffset.UTC);
        JwtIssuer issuer = new JwtIssuer(config.jwtEncoder(PROPERTIES), PROPERTIES, clock);
        JwtDecoder decoder = config.jwtDecoder(PROPERTIES, clock);
        UUID userId = UUID.randomUUID();

        JwtIssuer.IssuedJwt issued = issuer.issue(userId, "alice");
        Jwt jwt = decoder.decode(issued.value());

        assertThat(issued.expiresAt()).isEqualTo(NOW.plus(Duration.ofMinutes(15)));
        assertThat(jwt.getSubject()).isEqualTo(userId.toString());
        assertThat(jwt.getClaimAsString(JwtIssuer.USERNAME_CLAIM)).isEqualTo("alice");
        assertThat(jwt.getIssuer().toString()).isEqualTo("cipher-relay");
        assertThat(jwt.getIssuedAt()).isEqualTo(NOW);
        assertThat(jwt.getExpiresAt()).isEqualTo(NOW.plus(Duration.ofMinutes(15)));
        assertThat(jwt.getHeaders()).containsEntry("alg", "HS256");
    }

    @Test
    void rejectsTokensSignedWithAnotherSecret() {
        Clock clock = Clock.fixed(NOW, ZoneOffset.UTC);
        JwtProperties other = new JwtProperties("another-secret-another-secret-another-secret-123456",
                Duration.ofMinutes(15), Duration.ofDays(30));
        JwtIssuer rogueIssuer = new JwtIssuer(config.jwtEncoder(other), other, clock);
        JwtDecoder decoder = config.jwtDecoder(PROPERTIES, clock);

        String forged = rogueIssuer.issue(UUID.randomUUID(), "mallory").value();

        assertThatThrownBy(() -> decoder.decode(forged)).isInstanceOf(JwtException.class);
    }

    @Test
    void rejectsExpiredTokens() {
        JwtIssuer issuer = new JwtIssuer(config.jwtEncoder(PROPERTIES), PROPERTIES, Clock.fixed(NOW, ZoneOffset.UTC));
        JwtDecoder laterDecoder = config.jwtDecoder(PROPERTIES,
                Clock.fixed(NOW.plus(Duration.ofMinutes(20)), ZoneOffset.UTC));

        String expired = issuer.issue(UUID.randomUUID(), "alice").value();

        assertThatThrownBy(() -> laterDecoder.decode(expired)).isInstanceOf(JwtException.class);
    }
}
