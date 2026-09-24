package com.cipher.auth.application.port.in;

/**
 * Revokes a refresh token. Idempotent by design so a client can retry safely after a network
 * failure and so unknown tokens do not leak whether they ever existed.
 */
public interface LogoutUseCase {

    void logout(LogoutCommand command);
}
