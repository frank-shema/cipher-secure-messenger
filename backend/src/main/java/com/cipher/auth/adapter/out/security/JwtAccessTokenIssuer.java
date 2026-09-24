package com.cipher.auth.adapter.out.security;

import com.cipher.auth.application.port.out.AccessToken;
import com.cipher.auth.application.port.out.AccessTokenIssuer;
import com.cipher.auth.domain.User;
import com.cipher.shared.security.JwtIssuer;
import com.cipher.shared.security.JwtProperties;
import org.springframework.stereotype.Component;

/**
 * Adapts the shared {@link JwtIssuer} to the auth feature's {@link AccessTokenIssuer} port so
 * the use cases stay unaware that access tokens are JWTs.
 */
@Component
public class JwtAccessTokenIssuer implements AccessTokenIssuer {

    private final JwtIssuer jwtIssuer;
    private final JwtProperties properties;

    public JwtAccessTokenIssuer(JwtIssuer jwtIssuer, JwtProperties properties) {
        this.jwtIssuer = jwtIssuer;
        this.properties = properties;
    }

    @Override
    public AccessToken issue(User user) {
        JwtIssuer.IssuedJwt jwt = jwtIssuer.issue(user.id(), user.username());
        return new AccessToken(jwt.value(), properties.accessTokenTtl().toSeconds());
    }
}
