package com.cipher.keys.application.port.in;

/**
 * First-time upload of a user's public keys.
 *
 * <p>The operation is idempotent for byte-identical material (a reinstalled app may re-send the
 * same keys) but refuses to silently replace different keys: an attacker with a stolen access
 * token must not be able to swap a victim's identity without the explicit, contact-notifying
 * rotation path.
 */
public interface RegisterKeysUseCase {

    RegisterKeysResult register(RegisterKeysCommand command);
}
