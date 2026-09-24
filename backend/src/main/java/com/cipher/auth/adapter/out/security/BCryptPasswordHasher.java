package com.cipher.auth.adapter.out.security;

import com.cipher.auth.application.port.out.PasswordHasher;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Component;

/**
 * BCrypt adapter for {@link PasswordHasher}. BCrypt is chosen over a faster hash because the
 * relay must assume its database can leak, and the per-hash salt plus adaptive cost make
 * offline guessing expensive without any extra infrastructure.
 */
@Component
public class BCryptPasswordHasher implements PasswordHasher {

    private final BCryptPasswordEncoder encoder = new BCryptPasswordEncoder();

    @Override
    public String hash(String rawPassword) {
        return encoder.encode(rawPassword);
    }

    @Override
    public boolean matches(String rawPassword, String passwordHash) {
        return passwordHash != null && encoder.matches(rawPassword, passwordHash);
    }
}
