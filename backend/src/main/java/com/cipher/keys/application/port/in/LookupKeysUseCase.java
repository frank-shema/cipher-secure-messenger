package com.cipher.keys.application.port.in;

import java.util.UUID;

/**
 * Reads from the key directory. Two distinct not-found problems are kept apart on purpose:
 * "no such user" lets the client fix a typo, "keys not registered" tells it the contact has not
 * finished onboarding yet.
 */
public interface LookupKeysUseCase {

    KeyDirectoryEntry forUser(UUID userId);

    KeyDirectoryEntry forUsername(String username);
}
