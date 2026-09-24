package com.cipher.keys.adapter.out.notify;

import com.cipher.keys.domain.KeyBundle;
import java.util.Base64;
import java.util.UUID;

/**
 * Payload of a {@code key.changed} frame: the rotated public material so a contact can re-pin
 * without a round trip, plus the version the client compares against its pinned one.
 */
record KeyChangedDto(UUID userId, int version, String identityKey, String signingKey, long changedAt) {

    private static final Base64.Encoder ENCODER = Base64.getEncoder();

    static KeyChangedDto from(KeyBundle bundle) {
        return new KeyChangedDto(bundle.userId(), bundle.version(), ENCODER.encodeToString(bundle.identityKey()),
                ENCODER.encodeToString(bundle.signingKey()), bundle.updatedAt().toEpochMilli());
    }
}
