package com.cipher.shared.security;

import java.time.Clock;
import java.time.Instant;
import java.util.UUID;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.stereotype.Component;

/**
 * Mints the relay's access tokens.
 *
 * <p>The claim set is deliberately tiny ({@code sub}, {@code username}, {@code iss},
 * {@code iat}, {@code exp}): the token is a bearer credential, not a profile, and anything
 * else would have to be re-validated against the database anyway. Feature adapters wrap this
 * class behind their own ports so the application layer never sees JWT types.
 */
@Component
public class JwtIssuer {

    public static final String ISSUER = "cipher-relay";
    public static final String USERNAME_CLAIM = "username";

    private final JwtEncoder encoder;
    private final JwtProperties properties;
    private final Clock clock;

    public JwtIssuer(JwtEncoder encoder, JwtProperties properties, Clock clock) {
        this.encoder = encoder;
        this.properties = properties;
        this.clock = clock;
    }

    public IssuedJwt issue(UUID userId, String username) {
        Instant issuedAt = clock.instant();
        Instant expiresAt = issuedAt.plus(properties.accessTokenTtl());
        JwtClaimsSet claims = JwtClaimsSet.builder()
                .issuer(ISSUER)
                .subject(userId.toString())
                .issuedAt(issuedAt)
                .expiresAt(expiresAt)
                .claim(USERNAME_CLAIM, username)
                .build();
        JwsHeader header = JwsHeader.with(MacAlgorithm.HS256).build();
        String value = encoder.encode(JwtEncoderParameters.from(header, claims)).getTokenValue();
        return new IssuedJwt(value, expiresAt);
    }

    public record IssuedJwt(String value, Instant expiresAt) {
    }
}
