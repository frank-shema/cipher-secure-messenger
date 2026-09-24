package com.cipher.auth.adapter.out.security;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class BCryptPasswordHasherTest {

    private final BCryptPasswordHasher hasher = new BCryptPasswordHasher();

    @Test
    void hashesAreSaltedBcryptAndVerifiable() {
        String first = hasher.hash("cipher-alice");
        String second = hasher.hash("cipher-alice");

        assertThat(first).startsWith("$2a$").isNotEqualTo("cipher-alice").isNotEqualTo(second);
        assertThat(hasher.matches("cipher-alice", first)).isTrue();
        assertThat(hasher.matches("cipher-alice", second)).isTrue();
        assertThat(hasher.matches("wrong", first)).isFalse();
    }

    @Test
    void neverMatchesAgainstAMissingHash() {
        assertThat(hasher.matches("anything", null)).isFalse();
    }
}
