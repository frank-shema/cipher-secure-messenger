package com.cipher.support;

import java.security.SecureRandom;
import java.util.Base64;

/** Random 32-byte public-key stand-ins; the relay never inspects the bytes. */
public final class TestKeys {

    private static final SecureRandom RANDOM = new SecureRandom();

    private TestKeys() {
    }

    public static byte[] randomKey() {
        byte[] key = new byte[32];
        RANDOM.nextBytes(key);
        return key;
    }

    public static String randomKeyBase64() {
        return Base64.getEncoder().encodeToString(randomKey());
    }

    public static String base64(byte[] bytes) {
        return Base64.getEncoder().encodeToString(bytes);
    }
}
