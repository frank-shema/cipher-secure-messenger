package com.cipher.auth.application;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.cipher.auth.application.port.in.AuthSession;
import com.cipher.auth.application.port.in.LoginCommand;
import com.cipher.auth.application.port.in.LogoutCommand;
import com.cipher.auth.application.port.in.RefreshSessionCommand;
import com.cipher.auth.application.port.in.RegisterUserCommand;
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
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class AuthServiceTest {

    private static final Instant NOW = Instant.parse("2026-09-24T10:00:00Z");
    private static final JwtProperties JWT = new JwtProperties("0123456789abcdef0123456789abcdef",
            Duration.ofMinutes(15), Duration.ofDays(30));
    private static final AccessToken ACCESS_TOKEN = new AccessToken("jwt-value", 900);

    @Mock
    private UserRepository users;
    @Mock
    private RefreshTokenRepository refreshTokens;
    @Mock
    private PasswordHasher passwordHasher;
    @Mock
    private AccessTokenIssuer accessTokenIssuer;

    private AuthService service;
    private final User alice = new User(UUID.randomUUID(), "alice", "Alice", "$2a$hash", NOW.minus(Duration.ofDays(1)));

    @BeforeEach
    void setUp() {
        service = new AuthService(users, refreshTokens, passwordHasher, accessTokenIssuer, JWT,
                Clock.fixed(NOW, ZoneOffset.UTC), new SecureRandom());
    }

    @Nested
    class Register {

        @Test
        void createsTheUserWithNormalisedUsernameAndOpensASession() {
            when(users.existsByUsername("alice")).thenReturn(false);
            when(passwordHasher.hash("cipher-alice")).thenReturn("$2a$hash");
            when(users.save(any())).thenAnswer(invocation -> invocation.getArgument(0));
            when(accessTokenIssuer.issue(any())).thenReturn(ACCESS_TOKEN);
            when(refreshTokens.save(any())).thenAnswer(invocation -> invocation.getArgument(0));

            AuthSession session = service.register(new RegisterUserCommand("  Alice ", "cipher-alice", " Alice A. "));

            assertThat(session.user().username()).isEqualTo("alice");
            assertThat(session.user().displayName()).isEqualTo("Alice A.");
            assertThat(session.user().passwordHash()).isEqualTo("$2a$hash");
            assertThat(session.user().createdAt()).isEqualTo(NOW);
            assertThat(session.accessToken()).isEqualTo(ACCESS_TOKEN);
            assertThat(session.refreshToken()).hasSize(43);

            ArgumentCaptor<RefreshToken> stored = ArgumentCaptor.forClass(RefreshToken.class);
            verify(refreshTokens).save(stored.capture());
            assertThat(stored.getValue().userId()).isEqualTo(session.user().id());
            assertThat(stored.getValue().tokenHash()).isEqualTo(RefreshTokenSecrets.hash(session.refreshToken()));
            assertThat(stored.getValue().expiresAt()).isEqualTo(NOW.plus(Duration.ofDays(30)));
            assertThat(stored.getValue().createdAt()).isEqualTo(NOW);
            assertThat(stored.getValue().revokedAt()).isNull();
        }

        @Test
        void defaultsDisplayNameToTheUsername() {
            when(users.existsByUsername("bob")).thenReturn(false);
            when(passwordHasher.hash(anyString())).thenReturn("h");
            when(users.save(any())).thenAnswer(invocation -> invocation.getArgument(0));
            when(accessTokenIssuer.issue(any())).thenReturn(ACCESS_TOKEN);
            when(refreshTokens.save(any())).thenAnswer(invocation -> invocation.getArgument(0));

            assertThat(service.register(new RegisterUserCommand("bob", "cipher-bob", null)).user().displayName())
                    .isEqualTo("bob");
            assertThat(service.register(new RegisterUserCommand("bob", "cipher-bob", "   ")).user().displayName())
                    .isEqualTo("bob");
        }

        @Test
        void rejectsATakenUsernameBeforeHashing() {
            when(users.existsByUsername("alice")).thenReturn(true);

            assertThatThrownBy(() -> service.register(new RegisterUserCommand("alice", "cipher-alice", "Alice")))
                    .isInstanceOfSatisfying(ProblemException.class,
                            ex -> assertThat(ex.type()).isEqualTo(ProblemType.USERNAME_TAKEN));

            verify(passwordHasher, never()).hash(anyString());
            verify(users, never()).save(any());
        }
    }

    @Nested
    class Login {

        @Test
        void opensASessionForValidCredentials() {
            when(users.findByUsername("alice")).thenReturn(Optional.of(alice));
            when(passwordHasher.matches("cipher-alice", "$2a$hash")).thenReturn(true);
            when(accessTokenIssuer.issue(alice)).thenReturn(ACCESS_TOKEN);
            when(refreshTokens.save(any())).thenAnswer(invocation -> invocation.getArgument(0));

            AuthSession session = service.login(new LoginCommand("Alice", "cipher-alice"));

            assertThat(session.user()).isEqualTo(alice);
            assertThat(session.accessToken()).isEqualTo(ACCESS_TOKEN);
            assertThat(session.refreshToken()).isNotBlank();
        }

        @Test
        void rejectsAWrongPassword() {
            when(users.findByUsername("alice")).thenReturn(Optional.of(alice));
            when(passwordHasher.matches("wrong", "$2a$hash")).thenReturn(false);

            assertThatThrownBy(() -> service.login(new LoginCommand("alice", "wrong")))
                    .isInstanceOfSatisfying(ProblemException.class,
                            ex -> assertThat(ex.type()).isEqualTo(ProblemType.INVALID_CREDENTIALS));
            verify(refreshTokens, never()).save(any());
        }

        @Test
        void rejectsAnUnknownUserWithTheSameProblem() {
            when(users.findByUsername("nobody")).thenReturn(Optional.empty());

            assertThatThrownBy(() -> service.login(new LoginCommand("nobody", "whatever")))
                    .isInstanceOfSatisfying(ProblemException.class,
                            ex -> assertThat(ex.type()).isEqualTo(ProblemType.INVALID_CREDENTIALS));
        }
    }

    @Nested
    class Refresh {

        private final String presented = "presented-refresh-token";
        private final RefreshToken active = new RefreshToken(UUID.randomUUID(), alice.id(),
                RefreshTokenSecrets.hash(presented), NOW.plus(Duration.ofDays(10)), null, NOW.minus(Duration.ofDays(1)));

        @Test
        void revokesThePresentedTokenAndIssuesANewPair() {
            when(refreshTokens.findByTokenHash(active.tokenHash())).thenReturn(Optional.of(active));
            when(refreshTokens.revoke(active.id(), NOW)).thenReturn(true);
            when(users.findById(alice.id())).thenReturn(Optional.of(alice));
            when(accessTokenIssuer.issue(alice)).thenReturn(ACCESS_TOKEN);
            when(refreshTokens.save(any())).thenAnswer(invocation -> invocation.getArgument(0));

            AuthSession session = service.refresh(new RefreshSessionCommand(presented));

            assertThat(session.refreshToken()).isNotEqualTo(presented);
            assertThat(session.user()).isEqualTo(alice);
            ArgumentCaptor<RefreshToken> stored = ArgumentCaptor.forClass(RefreshToken.class);
            verify(refreshTokens).save(stored.capture());
            assertThat(stored.getValue().tokenHash()).isEqualTo(RefreshTokenSecrets.hash(session.refreshToken()));
            assertThat(stored.getValue().expiresAt()).isEqualTo(NOW.plus(Duration.ofDays(30)));
        }

        @Test
        void rejectsUnknownTokens() {
            when(refreshTokens.findByTokenHash(anyString())).thenReturn(Optional.empty());

            assertInvalidRefresh(() -> service.refresh(new RefreshSessionCommand("unknown")));
            verify(refreshTokens, never()).revoke(any(), any());
        }

        @Test
        void rejectsExpiredTokensWithoutRevoking() {
            RefreshToken expired = new RefreshToken(active.id(), alice.id(), active.tokenHash(),
                    NOW.minus(Duration.ofSeconds(1)), null, active.createdAt());
            when(refreshTokens.findByTokenHash(active.tokenHash())).thenReturn(Optional.of(expired));

            assertInvalidRefresh(() -> service.refresh(new RefreshSessionCommand(presented)));
            verify(refreshTokens, never()).revoke(any(), any());
        }

        @Test
        void rejectsAlreadyRevokedTokens() {
            RefreshToken revoked = new RefreshToken(active.id(), alice.id(), active.tokenHash(), active.expiresAt(),
                    NOW.minus(Duration.ofMinutes(5)), active.createdAt());
            when(refreshTokens.findByTokenHash(active.tokenHash())).thenReturn(Optional.of(revoked));

            assertInvalidRefresh(() -> service.refresh(new RefreshSessionCommand(presented)));
        }

        @Test
        void rejectsWhenAConcurrentRefreshWonTheRevocationRace() {
            when(refreshTokens.findByTokenHash(active.tokenHash())).thenReturn(Optional.of(active));
            when(refreshTokens.revoke(active.id(), NOW)).thenReturn(false);

            assertInvalidRefresh(() -> service.refresh(new RefreshSessionCommand(presented)));
            verify(refreshTokens, never()).save(any());
        }

        @Test
        void rejectsWhenTheOwningUserNoLongerExists() {
            when(refreshTokens.findByTokenHash(active.tokenHash())).thenReturn(Optional.of(active));
            when(refreshTokens.revoke(active.id(), NOW)).thenReturn(true);
            when(users.findById(alice.id())).thenReturn(Optional.empty());

            assertInvalidRefresh(() -> service.refresh(new RefreshSessionCommand(presented)));
        }

        private void assertInvalidRefresh(org.assertj.core.api.ThrowableAssert.ThrowingCallable call) {
            assertThatThrownBy(call).isInstanceOfSatisfying(ProblemException.class,
                    ex -> assertThat(ex.type()).isEqualTo(ProblemType.INVALID_REFRESH_TOKEN));
        }
    }

    @Nested
    class Logout {

        @Test
        void revokesAKnownToken() {
            String presented = "known";
            RefreshToken token = new RefreshToken(UUID.randomUUID(), alice.id(), RefreshTokenSecrets.hash(presented),
                    NOW.plus(Duration.ofDays(1)), null, NOW);
            when(refreshTokens.findByTokenHash(token.tokenHash())).thenReturn(Optional.of(token));
            when(refreshTokens.revoke(token.id(), NOW)).thenReturn(true);

            service.logout(new LogoutCommand(presented));

            verify(refreshTokens).revoke(eq(token.id()), eq(NOW));
        }

        @Test
        void isIdempotentForUnknownOrAlreadyRevokedTokens() {
            when(refreshTokens.findByTokenHash(anyString())).thenReturn(Optional.empty());

            service.logout(new LogoutCommand("unknown"));

            verify(refreshTokens, never()).revoke(any(), any());
        }
    }
}
