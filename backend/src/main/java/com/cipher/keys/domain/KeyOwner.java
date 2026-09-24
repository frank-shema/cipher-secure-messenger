package com.cipher.keys.domain;

import java.util.UUID;

/**
 * The public face of the account a key bundle belongs to. The keys feature deliberately sees
 * only these three fields of a user, never the password hash.
 */
public record KeyOwner(UUID id, String username, String displayName) {
}
