package com.cipher.shared.security;

import java.util.UUID;

/**
 * The caller as established by the bearer token, in the only two fields controllers need.
 */
public record AuthenticatedUser(UUID id, String username) {
}
