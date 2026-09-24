package com.cipher.auth.application;

import static org.assertj.core.api.Assertions.assertThat;

import java.security.SecureRandom;
import java.util.Base64;
import org.junit.jupiter.api.Test;

class RefreshTokenSecretsTest {

    @Test
    void generatesUnpadded32ByteBase64UrlTokens() {
        SecureRandom random = new SecureRandom();

        String first = RefreshTokenSecrets.generate(random);
        String second = RefreshTokenSecrets.generate(random);

        assertThat(first).hasSize(43).matches("^[A-Za-z0-9_-]+$");
        assertThat(Base64.getUrlDecoder().decode(first)).hasSize(RefreshTokenSecrets.TOKEN_BYTES);
        assertThat(first).isNotEqualTo(second);
    }

    @Test
    void hashesWithSha256Hex() {
        assertThat(RefreshTokenSecrets.hash("abc"))
                .isEqualTo("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
        assertThat(RefreshTokenSecrets.hash("abc")).isEqualTo(RefreshTokenSecrets.hash("abc"));
        assertThat(RefreshTokenSecrets.hash("abd")).isNotEqualTo(RefreshTokenSecrets.hash("abc"));
    }
}
