package com.cipher.shared.security;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Duration;
import org.junit.jupiter.api.Test;

class JwtPropertiesTest {

    private static final String VALID_SECRET = "0123456789abcdef0123456789abcdef";

    @Test
    void acceptsASecretOfAtLeast32Bytes() {
        JwtProperties properties = new JwtProperties(VALID_SECRET, Duration.ofMinutes(15), Duration.ofDays(30));

        assertThat(properties.secretBytes()).hasSize(32);
        assertThat(properties.accessTokenTtl()).isEqualTo(Duration.ofMinutes(15));
    }

    @Test
    void failsFastWhenTheSecretIsMissing() {
        assertThatThrownBy(() -> new JwtProperties("", Duration.ofMinutes(15), Duration.ofDays(30)))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("JWT_SECRET");
        assertThatThrownBy(() -> new JwtProperties(null, Duration.ofMinutes(15), Duration.ofDays(30)))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("JWT_SECRET");
    }

    @Test
    void failsFastWhenTheSecretIsShorterThan32Bytes() {
        assertThatThrownBy(() -> new JwtProperties(VALID_SECRET.substring(1), Duration.ofMinutes(15), Duration.ofDays(30)))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("32 bytes");
    }

    @Test
    void failsFastOnNonPositiveLifetimes() {
        assertThatThrownBy(() -> new JwtProperties(VALID_SECRET, Duration.ZERO, Duration.ofDays(30)))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("access-token-ttl");
        assertThatThrownBy(() -> new JwtProperties(VALID_SECRET, Duration.ofMinutes(15), Duration.ofDays(-1)))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("refresh-token-ttl");
    }
}
