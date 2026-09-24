package com.cipher.auth.adapter.in.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

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
import com.cipher.auth.domain.User;
import com.cipher.shared.config.CorrelationIdFilter;
import com.cipher.shared.domain.ProblemException;
import com.cipher.shared.domain.ProblemType;
import com.cipher.shared.ratelimit.RateLimitFilter;
import com.cipher.support.WebSliceConfig;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.context.annotation.ComponentScan;
import org.springframework.context.annotation.FilterType;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

@WebMvcTest(controllers = AuthController.class,
        excludeFilters = @ComponentScan.Filter(type = FilterType.ASSIGNABLE_TYPE, classes = RateLimitFilter.class))
@ActiveProfiles("test")
@Import(WebSliceConfig.class)
class AuthControllerTest {

    private static final UUID USER_ID = UUID.fromString("5f3a7c1e-8b2d-4e6f-9a0b-1c2d3e4f5a6b");
    private static final AuthSession SESSION = new AuthSession(
            new User(USER_ID, "alice", "Alice", "$2a$hash", Instant.parse("2026-09-24T10:00:00Z")),
            new AccessToken("access-jwt", 900), "refresh-opaque");

    @Autowired
    private MockMvc mvc;

    @MockitoBean
    private RegisterUserUseCase registerUser;
    @MockitoBean
    private LoginUseCase login;
    @MockitoBean
    private RefreshSessionUseCase refreshSession;
    @MockitoBean
    private LogoutUseCase logout;

    @Test
    void registerReturns201WithTheAuthResponseAndNeverEchoesThePasswordHash() throws Exception {
        when(registerUser.register(any())).thenReturn(SESSION);

        mvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"username":"alice","password":"cipher-alice","displayName":"Alice"}
                                """))
                .andExpect(status().isCreated())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.user.id").value(USER_ID.toString()))
                .andExpect(jsonPath("$.user.username").value("alice"))
                .andExpect(jsonPath("$.user.displayName").value("Alice"))
                .andExpect(jsonPath("$.user.passwordHash").doesNotExist())
                .andExpect(jsonPath("$.accessToken").value("access-jwt"))
                .andExpect(jsonPath("$.refreshToken").value("refresh-opaque"))
                .andExpect(jsonPath("$.accessTokenExpiresIn").value(900));

        ArgumentCaptor<RegisterUserCommand> command = ArgumentCaptor.forClass(RegisterUserCommand.class);
        verify(registerUser).register(command.capture());
        assertThat(command.getValue()).isEqualTo(new RegisterUserCommand("alice", "cipher-alice", "Alice"));
    }

    @Test
    void registerRejectsInvalidInputWithAValidationProblem() throws Exception {
        mvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON)
                        .header(CorrelationIdFilter.HEADER_NAME, "slice-trace-1")
                        .content("""
                                {"username":"Al","password":"short"}
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
                .andExpect(header().string(CorrelationIdFilter.HEADER_NAME, "slice-trace-1"))
                .andExpect(jsonPath("$.type").value("urn:cipher:problem:validation"))
                .andExpect(jsonPath("$.title").value("Validation failed"))
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.detail").value(org.hamcrest.Matchers.containsString("username")))
                .andExpect(jsonPath("$.detail").value(org.hamcrest.Matchers.containsString("password")))
                .andExpect(jsonPath("$.instance").value("/api/v1/auth/register"))
                .andExpect(jsonPath("$.correlationId").value("slice-trace-1"));
    }

    @Test
    void registerRejectsMalformedJsonWithAValidationProblem() throws Exception {
        mvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON).content("{not json"))
                .andExpect(status().isBadRequest())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
                .andExpect(jsonPath("$.type").value("urn:cipher:problem:validation"))
                .andExpect(jsonPath("$.correlationId").isNotEmpty());
    }

    @Test
    void registerMapsUsernameTakenTo409() throws Exception {
        when(registerUser.register(any()))
                .thenThrow(new ProblemException(ProblemType.USERNAME_TAKEN, "The username 'alice' is already taken"));

        mvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"username":"alice","password":"cipher-alice"}
                                """))
                .andExpect(status().isConflict())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
                .andExpect(jsonPath("$.type").value("urn:cipher:problem:username-taken"))
                .andExpect(jsonPath("$.status").value(409))
                .andExpect(jsonPath("$.detail").value("The username 'alice' is already taken"));
    }

    @Test
    void loginReturns200WithTokens() throws Exception {
        when(login.login(new LoginCommand("alice", "cipher-alice"))).thenReturn(SESSION);

        mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"username":"alice","password":"cipher-alice"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").value("access-jwt"))
                .andExpect(jsonPath("$.refreshToken").value("refresh-opaque"));
    }

    @Test
    void loginMapsInvalidCredentialsTo401() throws Exception {
        when(login.login(any())).thenThrow(new ProblemException(ProblemType.INVALID_CREDENTIALS, "nope"));

        mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"username":"alice","password":"wrong-password"}
                                """))
                .andExpect(status().isUnauthorized())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
                .andExpect(jsonPath("$.type").value("urn:cipher:problem:invalid-credentials"));
    }

    @Test
    void refreshReturnsARotatedSessionOr401() throws Exception {
        when(refreshSession.refresh(new RefreshSessionCommand("good"))).thenReturn(SESSION);
        when(refreshSession.refresh(new RefreshSessionCommand("bad")))
                .thenThrow(new ProblemException(ProblemType.INVALID_REFRESH_TOKEN, "used"));

        mvc.perform(post("/api/v1/auth/refresh").contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"refreshToken":"good"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.refreshToken").value("refresh-opaque"));

        mvc.perform(post("/api/v1/auth/refresh").contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"refreshToken":"bad"}
                                """))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.type").value("urn:cipher:problem:invalid-refresh-token"));
    }

    @Test
    void logoutReturns204AndForwardsTheToken() throws Exception {
        mvc.perform(post("/api/v1/auth/logout").contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"refreshToken":"bye"}
                                """))
                .andExpect(status().isNoContent())
                .andExpect(content().string(""));

        verify(logout).logout(new LogoutCommand("bye"));
    }

    @Test
    void logoutWithoutATokenIsAValidationProblem() throws Exception {
        mvc.perform(post("/api/v1/auth/logout").contentType(MediaType.APPLICATION_JSON).content("{}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.type").value("urn:cipher:problem:validation"));
    }
}
