package com.cipher.keys.adapter.in.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.cipher.shared.domain.ProblemException;
import com.cipher.shared.domain.ProblemType;
import com.cipher.support.TestKeys;
import org.junit.jupiter.api.Test;

class KeyMaterialDecoderTest {

    @Test
    void decodesStandardBase64() {
        byte[] key = TestKeys.randomKey();

        assertThat(KeyMaterialDecoder.decode(TestKeys.base64(key), "identityKey")).isEqualTo(key);
        assertThat(KeyMaterialDecoder.decode(" " + TestKeys.base64(key) + " ", "identityKey")).isEqualTo(key);
    }

    @Test
    void rejectsInputThatIsNotBase64() {
        assertThatThrownBy(() -> KeyMaterialDecoder.decode("not base64!!", "signingKey"))
                .isInstanceOfSatisfying(ProblemException.class, ex -> {
                    assertThat(ex.type()).isEqualTo(ProblemType.VALIDATION);
                    assertThat(ex.detail()).contains("signingKey");
                });
    }
}
