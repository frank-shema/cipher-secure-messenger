package com.cipher.keys.adapter.in.web;

import com.cipher.keys.application.port.in.KeyDirectoryEntry;
import java.util.Base64;
import java.util.UUID;

public record KeyBundleResponse(UUID userId, String username, String displayName, String identityKey,
                                String signingKey, int version, long createdAt) {

    private static final Base64.Encoder ENCODER = Base64.getEncoder();

    static KeyBundleResponse from(KeyDirectoryEntry entry) {
        return new KeyBundleResponse(
                entry.owner().id(),
                entry.owner().username(),
                entry.owner().displayName(),
                ENCODER.encodeToString(entry.bundle().identityKey()),
                ENCODER.encodeToString(entry.bundle().signingKey()),
                entry.bundle().version(),
                entry.bundle().createdAt().toEpochMilli());
    }
}
