package com.cipher.shared.security;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.cipher.shared.domain.ProblemException;
import com.cipher.shared.domain.ProblemType;
import java.lang.reflect.Method;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.core.MethodParameter;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;

class CurrentUserArgumentResolverTest {

    private final CurrentUserArgumentResolver resolver = new CurrentUserArgumentResolver();

    @AfterEach
    void tearDown() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void supportsOnlyAnnotatedAuthenticatedUserParameters() throws Exception {
        Method method = Sample.class.getDeclaredMethod("handler", AuthenticatedUser.class, AuthenticatedUser.class, String.class);

        assertThat(resolver.supportsParameter(new MethodParameter(method, 0))).isTrue();
        assertThat(resolver.supportsParameter(new MethodParameter(method, 1))).isFalse();
        assertThat(resolver.supportsParameter(new MethodParameter(method, 2))).isFalse();
    }

    @Test
    void resolvesIdAndUsernameFromTheJwt() {
        UUID userId = UUID.randomUUID();
        SecurityContextHolder.getContext().setAuthentication(new JwtAuthenticationToken(jwt(userId.toString(), "alice")));

        Object resolved = resolver.resolveArgument(null, null, null, null);

        assertThat(resolved).isEqualTo(new AuthenticatedUser(userId, "alice"));
    }

    @Test
    void failsClosedWithoutAJwtAuthentication() {
        assertThatThrownBy(() -> resolver.resolveArgument(null, null, null, null))
                .isInstanceOfSatisfying(ProblemException.class,
                        ex -> assertThat(ex.type()).isEqualTo(ProblemType.UNAUTHORIZED));

        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken("alice", "n/a"));
        assertThatThrownBy(() -> resolver.resolveArgument(null, null, null, null))
                .isInstanceOfSatisfying(ProblemException.class,
                        ex -> assertThat(ex.type()).isEqualTo(ProblemType.UNAUTHORIZED));
    }

    @Test
    void rejectsTokensWhoseSubjectIsNotAUserId() {
        SecurityContextHolder.getContext().setAuthentication(new JwtAuthenticationToken(jwt("not-a-uuid", "alice")));

        assertThatThrownBy(() -> resolver.resolveArgument(null, null, null, null))
                .isInstanceOfSatisfying(ProblemException.class,
                        ex -> assertThat(ex.type()).isEqualTo(ProblemType.UNAUTHORIZED));
    }

    @Test
    void rejectsTokensMissingTheUsernameClaim() {
        Jwt jwt = Jwt.withTokenValue("token").header("alg", "HS256").subject(UUID.randomUUID().toString()).build();
        SecurityContextHolder.getContext().setAuthentication(new JwtAuthenticationToken(jwt));

        assertThatThrownBy(() -> resolver.resolveArgument(null, null, null, null))
                .isInstanceOfSatisfying(ProblemException.class,
                        ex -> assertThat(ex.type()).isEqualTo(ProblemType.UNAUTHORIZED));
    }

    private static Jwt jwt(String subject, String username) {
        return Jwt.withTokenValue("token")
                .header("alg", "HS256")
                .subject(subject)
                .claim(JwtIssuer.USERNAME_CLAIM, username)
                .build();
    }

    private static final class Sample {

        @SuppressWarnings("unused")
        void handler(@CurrentUser AuthenticatedUser annotated, AuthenticatedUser plain, @CurrentUser String wrongType) {
        }
    }
}
