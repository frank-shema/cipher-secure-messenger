package com.cipher.auth.application.port.in;

/**
 * Exchanges a username and password for a session. Unknown usernames and wrong passwords are
 * indistinguishable to the caller so the endpoint cannot be used to enumerate accounts.
 */
public interface LoginUseCase {

    AuthSession login(LoginCommand command);
}
