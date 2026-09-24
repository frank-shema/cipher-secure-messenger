package com.cipher.auth.application.port.in;

public record LoginCommand(String username, String password) {
}
