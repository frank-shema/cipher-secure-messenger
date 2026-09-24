package com.cipher.keys.application.port.in;

/**
 * Explicit key rotation: bumps the version and notifies contacts so their pinned keys can be
 * re-verified instead of trusting the change blindly.
 */
public interface RotateKeysUseCase {

    KeyDirectoryEntry rotate(RotateKeysCommand command);
}
