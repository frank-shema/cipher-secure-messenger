package com.cipher.keys.domain;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.cipher.shared.domain.ProblemException;
import com.cipher.shared.domain.ProblemType;
import com.cipher.support.TestKeys;
import java.time.Duration;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class KeyBundleTest {

    private static final Instant NOW = Instant.parse("2026-09-24T10:00:00Z");

    @Test
    void rejectsMaterialThatIsNotExactly32Bytes() {
        byte[] good = TestKeys.randomKey();

        assertThatThrownBy(() -> KeyBundle.initial(UUID.randomUUID(), new byte[31], good, NOW))
                .isInstanceOfSatisfying(ProblemException.class, ex -> {
                    assertThat(ex.type()).isEqualTo(ProblemType.VALIDATION);
                    assertThat(ex.detail()).contains("identityKey");
                });
        assertThatThrownBy(() -> KeyBundle.initial(UUID.randomUUID(), good, new byte[33], NOW))
                .isInstanceOfSatisfying(ProblemException.class,
                        ex -> assertThat(ex.detail()).contains("signingKey"));
        assertThatThrownBy(() -> KeyBundle.initial(UUID.randomUUID(), null, good, NOW))
                .isInstanceOf(ProblemException.class);
    }

    @Test
    void rejectsNonPositiveVersions() {
        assertThatThrownBy(() -> new KeyBundle(UUID.randomUUID(), TestKeys.randomKey(), TestKeys.randomKey(), 0, NOW, NOW))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void copiesMaterialDefensively() {
        byte[] identity = TestKeys.randomKey();
        byte[] signing = TestKeys.randomKey();
        KeyBundle bundle = KeyBundle.initial(UUID.randomUUID(), identity, signing, NOW);
        byte[] originalIdentity = identity.clone();

        identity[0] ^= 0x7f;
        bundle.identityKey()[1] ^= 0x7f;

        assertThat(bundle.identityKey()).isEqualTo(originalIdentity);
        assertThat(bundle.signingKey()).isEqualTo(signing);
    }

    @Test
    void comparesMaterialByValue() {
        byte[] identity = TestKeys.randomKey();
        byte[] signing = TestKeys.randomKey();
        KeyBundle bundle = KeyBundle.initial(UUID.randomUUID(), identity, signing, NOW);

        assertThat(bundle.hasSameMaterial(identity.clone(), signing.clone())).isTrue();
        assertThat(bundle.hasSameMaterial(TestKeys.randomKey(), signing)).isFalse();
        assertThat(bundle.hasSameMaterial(identity, TestKeys.randomKey())).isFalse();
    }

    @Test
    void rotationBumpsTheVersionAndKeepsTheOriginalCreationTime() {
        KeyBundle first = KeyBundle.initial(UUID.randomUUID(), TestKeys.randomKey(), TestKeys.randomKey(), NOW);
        byte[] newIdentity = TestKeys.randomKey();
        byte[] newSigning = TestKeys.randomKey();
        Instant later = NOW.plus(Duration.ofDays(3));

        KeyBundle rotated = first.rotate(newIdentity, newSigning, later);

        assertThat(rotated.version()).isEqualTo(2);
        assertThat(rotated.userId()).isEqualTo(first.userId());
        assertThat(rotated.createdAt()).isEqualTo(NOW);
        assertThat(rotated.updatedAt()).isEqualTo(later);
        assertThat(rotated.hasSameMaterial(newIdentity, newSigning)).isTrue();
        assertThat(first.version()).isEqualTo(1);
    }
}
