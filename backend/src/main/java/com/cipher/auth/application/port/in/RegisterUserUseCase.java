package com.cipher.auth.application.port.in;

/**
 * Creates an account and opens its first session, so the client is signed in right after
 * sign-up without a second round trip through the rate-limited login endpoint.
 */
public interface RegisterUserUseCase {

    AuthSession register(RegisterUserCommand command);
}
