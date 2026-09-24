package com.cipher.auth.application.port.in;

import com.cipher.auth.application.port.out.AccessToken;
import com.cipher.auth.domain.User;

/**
 * Result of any use case that opens a session: the account, a short-lived access token and the
 * opaque refresh token in the only moment the relay ever holds it in clear.
 */
public record AuthSession(User user, AccessToken accessToken, String refreshToken) {
}
