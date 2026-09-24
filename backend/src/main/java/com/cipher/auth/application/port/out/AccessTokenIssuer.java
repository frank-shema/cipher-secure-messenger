package com.cipher.auth.application.port.out;

import com.cipher.auth.domain.User;

/**
 * Issues access tokens for an account. Kept as a port so the use cases are independent of the
 * token format (JWT today) and can be unit-tested without cryptography.
 */
public interface AccessTokenIssuer {

    AccessToken issue(User user);
}
