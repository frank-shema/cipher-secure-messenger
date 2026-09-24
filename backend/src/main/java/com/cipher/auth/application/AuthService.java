package com.cipher.auth.application;

import com.cipher.auth.application.port.in.AuthSession;
import com.cipher.auth.application.port.in.LoginCommand;
import com.cipher.auth.application.port.in.LoginUseCase;
import com.cipher.auth.application.port.in.LogoutCommand;
import com.cipher.auth.application.port.in.LogoutUseCase;
import com.cipher.auth.application.port.in.RefreshSessionCommand;
import com.cipher.auth.application.port.in.RefreshSessionUseCase;
import com.cipher.auth.application.port.in.RegisterUserCommand;
import com.cipher.auth.application.port.in.RegisterUserUseCase;
import com.cipher.auth.application.port.out.AccessToken;
import com.cipher.auth.application.port.out.AccessTokenIssuer;
import com.cipher.auth.application.port.out.PasswordHasher;
import com.cipher.auth.application.port.out.RefreshTokenRepository;
import com.cipher.auth.application.port.out.UserRepository;
import com.cipher.auth.domain.RefreshToken;
import com.cipher.auth.domain.User;
import com.cipher.shared.domain.ProblemException;
import com.cipher.shared.domain.ProblemType;
import com.cipher.shared.security.JwtProperties;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Account lifecycle: register, login, refresh, logout.
 *
 * <p>All four use cases live in one service because they share the notion of "opening a
 * session" (mint access token, mint and persist refresh token) and must agree on it exactly:
 * a register that issued tokens differently from login would be a bug the client could not see.
 * Failures surface as {@link ProblemException}s with the protocol's types; the service never
 * reveals whether a username exists on login, only on register where it is unavoidable.
 */
@Service
public class AuthService implements RegisterUserUseCase, LoginUseCase, RefreshSessionUseCase, LogoutUseCase {

    private static final Logger log = LoggerFactory.getLogger(AuthService.class);

    private final UserRepository users;
    private final RefreshTokenRepository refreshTokens;
    private final PasswordHasher passwordHasher;
    private final AccessTokenIssuer accessTokenIssuer;
    private final JwtProperties jwtProperties;
    private final Clock clock;
    private final SecureRandom random;

    public AuthService(UserRepository users, RefreshTokenRepository refreshTokens, PasswordHasher passwordHasher,
                       AccessTokenIssuer accessTokenIssuer, JwtProperties jwtProperties, Clock clock) {
        this(users, refreshTokens, passwordHasher, accessTokenIssuer, jwtProperties, clock, new SecureRandom());
    }

    AuthService(UserRepository users, RefreshTokenRepository refreshTokens, PasswordHasher passwordHasher,
                AccessTokenIssuer accessTokenIssuer, JwtProperties jwtProperties, Clock clock, SecureRandom random) {
        this.users = users;
        this.refreshTokens = refreshTokens;
        this.passwordHasher = passwordHasher;
        this.accessTokenIssuer = accessTokenIssuer;
        this.jwtProperties = jwtProperties;
        this.clock = clock;
        this.random = random;
    }

    @Override
    @Transactional
    public AuthSession register(RegisterUserCommand command) {
        String username = User.normalizeUsername(command.username());
        if (users.existsByUsername(username)) {
            throw usernameTaken(username);
        }
        String displayName = command.displayName() == null || command.displayName().isBlank()
                ? username
                : command.displayName().trim();
        Instant now = clock.instant();
        User user = users.save(new User(UUID.randomUUID(), username, displayName,
                passwordHasher.hash(command.password()), now));
        log.info("Registered user id={}", user.id());
        return openSession(user, now);
    }

    @Override
    @Transactional
    public AuthSession login(LoginCommand command) {
        String username = User.normalizeUsername(command.username());
        Optional<User> found = users.findByUsername(username);
        if (found.isEmpty() || !passwordHasher.matches(command.password(), found.get().passwordHash())) {
            throw new ProblemException(ProblemType.INVALID_CREDENTIALS, "Username or password is incorrect");
        }
        User user = found.get();
        log.info("User logged in id={}", user.id());
        return openSession(user, clock.instant());
    }

    @Override
    @Transactional
    public AuthSession refresh(RefreshSessionCommand command) {
        Instant now = clock.instant();
        RefreshToken presented = refreshTokens.findByTokenHash(RefreshTokenSecrets.hash(command.refreshToken()))
                .orElseThrow(AuthService::invalidRefreshToken);
        if (!presented.isActive(now) || !refreshTokens.revoke(presented.id(), now)) {
            throw invalidRefreshToken();
        }
        User user = users.findById(presented.userId()).orElseThrow(AuthService::invalidRefreshToken);
        log.debug("Rotated refresh token for user id={}", user.id());
        return openSession(user, now);
    }

    @Override
    @Transactional
    public void logout(LogoutCommand command) {
        Instant now = clock.instant();
        refreshTokens.findByTokenHash(RefreshTokenSecrets.hash(command.refreshToken()))
                .ifPresent(token -> {
                    if (refreshTokens.revoke(token.id(), now)) {
                        log.debug("Revoked refresh token for user id={}", token.userId());
                    }
                });
    }

    private AuthSession openSession(User user, Instant now) {
        AccessToken accessToken = accessTokenIssuer.issue(user);
        String refreshToken = RefreshTokenSecrets.generate(random);
        refreshTokens.save(new RefreshToken(UUID.randomUUID(), user.id(), RefreshTokenSecrets.hash(refreshToken),
                now.plus(jwtProperties.refreshTokenTtl()), null, now));
        return new AuthSession(user, accessToken, refreshToken);
    }

    private static ProblemException usernameTaken(String username) {
        return new ProblemException(ProblemType.USERNAME_TAKEN, "The username '" + username + "' is already taken");
    }

    private static ProblemException invalidRefreshToken() {
        return new ProblemException(ProblemType.INVALID_REFRESH_TOKEN,
                "The refresh token is unknown, expired or has already been used");
    }
}
