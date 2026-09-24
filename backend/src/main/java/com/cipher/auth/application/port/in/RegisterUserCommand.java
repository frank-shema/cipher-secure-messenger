package com.cipher.auth.application.port.in;

public record RegisterUserCommand(String username, String password, String displayName) {
}
