package com.cipher.messaging.adapter.in.web;

import com.cipher.messaging.domain.Envelope;
import com.cipher.shared.domain.ProblemException;
import com.cipher.shared.domain.ProblemType;
import java.util.Base64;

/**
 * Decodes the standard-base64 binary fields of an envelope.
 *
 * <p>The size ceiling is checked on the encoded text first so an oversized upload is rejected
 * before the relay allocates a decoded copy of it.
 */
final class Base64Fields {

    private static final Base64.Decoder DECODER = Base64.getDecoder();
    private static final int MAX_CIPHERTEXT_CHARS = 4 * ((Envelope.MAX_CIPHERTEXT_BYTES + 2) / 3);

    private Base64Fields() {
    }

    static byte[] decodeCiphertext(String value) {
        if (value.length() > MAX_CIPHERTEXT_CHARS) {
            throw new ProblemException(ProblemType.PAYLOAD_TOO_LARGE,
                    "ciphertext exceeds the maximum of " + Envelope.MAX_CIPHERTEXT_BYTES + " bytes");
        }
        return decode(value, "ciphertext");
    }

    static byte[] decodeSignature(String value) {
        return decode(value, "signature");
    }

    private static byte[] decode(String value, String field) {
        try {
            return DECODER.decode(value.trim());
        } catch (IllegalArgumentException malformed) {
            throw new ProblemException(ProblemType.VALIDATION, field + " must be standard base64");
        }
    }
}
