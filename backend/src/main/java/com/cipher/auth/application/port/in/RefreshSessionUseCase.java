package com.cipher.auth.application.port.in;

/**
 * Rotates a refresh token: the presented token is revoked and a fresh pair is issued, so a
 * stolen refresh token is usable at most once and its reuse is detectable.
 */
public interface RefreshSessionUseCase {

    AuthSession refresh(RefreshSessionCommand command);
}
