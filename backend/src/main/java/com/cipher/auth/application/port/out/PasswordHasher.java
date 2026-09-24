package com.cipher.auth.application.port.out;

/**
 * Password hashing behind a port so the application layer never depends on a specific
 * algorithm and tests can swap in a cheap fake.
 */
public interface PasswordHasher {

    String hash(String rawPassword);

    boolean matches(String rawPassword, String passwordHash);
}
