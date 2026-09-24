package com.cipher.keys.adapter.in.web;

import com.cipher.shared.domain.ProblemException;
import com.cipher.shared.domain.ProblemType;
import java.util.Base64;

/**
 * Decodes the wire representation of key material. Base64 is a transport detail, so it is
 * undone at the edge; the length invariant is enforced by the domain {@code KeyBundle}.
 */
final class KeyMaterialDecoder {

    private static final Base64.Decoder DECODER = Base64.getDecoder();

    private KeyMaterialDecoder() {
    }

    static byte[] decode(String base64, String fieldName) {
        try {
            return DECODER.decode(base64.trim());
        } catch (IllegalArgumentException notBase64) {
            throw new ProblemException(ProblemType.VALIDATION, fieldName + " must be standard base64");
        }
    }
}
