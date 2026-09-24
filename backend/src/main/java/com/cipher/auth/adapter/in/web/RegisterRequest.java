package com.cipher.auth.adapter.in.web;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record RegisterRequest(
        @NotBlank @Size(min = 3, max = 32) @Pattern(regexp = "^[a-z0-9_]+$",
                message = "must contain only lowercase letters, digits and underscores") String username,
        @NotBlank @Size(min = 8, max = 128) String password,
        @Size(min = 1, max = 64) String displayName) {
}
