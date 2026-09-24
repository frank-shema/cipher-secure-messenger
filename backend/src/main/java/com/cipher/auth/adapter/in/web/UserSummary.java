package com.cipher.auth.adapter.in.web;

import com.cipher.auth.domain.User;
import java.util.UUID;

public record UserSummary(UUID id, String username, String displayName) {

    static UserSummary from(User user) {
        return new UserSummary(user.id(), user.username(), user.displayName());
    }
}
