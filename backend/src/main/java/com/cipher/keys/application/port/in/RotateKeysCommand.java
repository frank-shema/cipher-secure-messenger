package com.cipher.keys.application.port.in;

import com.cipher.keys.domain.KeyBundle;
import java.util.UUID;

public record RotateKeysCommand(UUID userId, byte[] identityKey, byte[] signingKey) {

    public RotateKeysCommand {
        KeyBundle.requireKeyLength(identityKey, "identityKey");
        KeyBundle.requireKeyLength(signingKey, "signingKey");
    }
}
