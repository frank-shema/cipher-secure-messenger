package com.cipher.auth.application.port.out;

/**
 * A minted access token together with its lifetime in seconds, which is what the client needs
 * to schedule a refresh without parsing the JWT.
 */
public record AccessToken(String value, long expiresInSeconds) {
}
