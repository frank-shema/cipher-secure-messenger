package com.cipher.keys.adapter.in.web;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Upload / rotate body: standard base64 of a raw 32-byte X25519 key and a raw 32-byte Ed25519
 * key (44 characters each once padded).
 */
public record KeyMaterialRequest(
        @NotBlank @Size(max = 64) String identityKey,
        @NotBlank @Size(max = 64) String signingKey) {
}
