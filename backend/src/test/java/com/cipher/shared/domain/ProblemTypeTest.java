package com.cipher.shared.domain;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;

class ProblemTypeTest {

    @ParameterizedTest
    @EnumSource(ProblemType.class)
    void everyTypeUsesTheCipherUrnScheme(ProblemType type) {
        assertThat(type.uri().toString()).isEqualTo("urn:cipher:problem:" + type.slug());
        assertThat(type.slug()).matches("^[a-z]+(-[a-z]+)*$");
        assertThat(type.status()).isBetween(400, 599);
        assertThat(type.title()).isNotBlank();
    }

    @Test
    void statusCodesMatchTheProtocolTable() {
        assertThat(ProblemType.VALIDATION.status()).isEqualTo(400);
        assertThat(ProblemType.INVALID_CREDENTIALS.status()).isEqualTo(401);
        assertThat(ProblemType.INVALID_REFRESH_TOKEN.status()).isEqualTo(401);
        assertThat(ProblemType.USER_NOT_FOUND.status()).isEqualTo(404);
        assertThat(ProblemType.KEYS_NOT_REGISTERED.status()).isEqualTo(404);
        assertThat(ProblemType.USERNAME_TAKEN.status()).isEqualTo(409);
        assertThat(ProblemType.KEYS_ALREADY_REGISTERED.status()).isEqualTo(409);
        assertThat(ProblemType.RATE_LIMITED.status()).isEqualTo(429);
        assertThat(ProblemType.INTERNAL.status()).isEqualTo(500);
    }

    @Test
    void problemExceptionCarriesTypeAndDetail() {
        ProblemException ex = new ProblemException(ProblemType.USERNAME_TAKEN, "taken");

        assertThat(ex.type()).isEqualTo(ProblemType.USERNAME_TAKEN);
        assertThat(ex.detail()).isEqualTo("taken");
        assertThat(ex.getMessage()).isEqualTo("taken");
    }
}
