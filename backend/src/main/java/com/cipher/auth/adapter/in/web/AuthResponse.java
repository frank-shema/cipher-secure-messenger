package com.cipher.auth.adapter.in.web;

import com.cipher.auth.application.port.in.AuthSession;

public record AuthResponse(UserSummary user, String accessToken, String refreshToken, long accessTokenExpiresIn) {

    static AuthResponse from(AuthSession session) {
        return new AuthResponse(UserSummary.from(session.user()), session.accessToken().value(),
                session.refreshToken(), session.accessToken().expiresInSeconds());
    }
}
