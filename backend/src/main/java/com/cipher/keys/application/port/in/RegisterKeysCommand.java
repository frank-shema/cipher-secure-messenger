package com.cipher.keys.application.port.in;

import com.cipher.keys.domain.KeyBundle;
import java.util.UUID;

public record RegisterKeysCommand(UUID userId, byte[] identityKey, byte[] signingKey) {

    public RegisterKeysCommand {
        KeyBundle.requireKeyLength(identityKey, "identityKey");
        KeyBundle.requireKeyLength(signingKey, "signingKey");
    }
}
