package com.cipher.auth.adapter.in.web;

import com.cipher.auth.application.port.in.LoginCommand;
import com.cipher.auth.application.port.in.LoginUseCase;
import com.cipher.auth.application.port.in.LogoutCommand;
import com.cipher.auth.application.port.in.LogoutUseCase;
import com.cipher.auth.application.port.in.RefreshSessionCommand;
import com.cipher.auth.application.port.in.RefreshSessionUseCase;
import com.cipher.auth.application.port.in.RegisterUserCommand;
import com.cipher.auth.application.port.in.RegisterUserUseCase;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirements;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping(path = "/api/v1/auth", produces = MediaType.APPLICATION_JSON_VALUE)
@Tag(name = "Auth", description = "Account registration and session management (rate limited: 10 requests/minute/IP)")
@SecurityRequirements
public class AuthController {

    private final RegisterUserUseCase registerUser;
    private final LoginUseCase login;
    private final RefreshSessionUseCase refreshSession;
    private final LogoutUseCase logout;

    public AuthController(RegisterUserUseCase registerUser, LoginUseCase login,
                          RefreshSessionUseCase refreshSession, LogoutUseCase logout) {
        this.registerUser = registerUser;
        this.login = login;
        this.refreshSession = refreshSession;
        this.logout = logout;
    }

    @PostMapping(path = "/register", consumes = MediaType.APPLICATION_JSON_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Register a new account and open a session")
    public AuthResponse register(@Valid @RequestBody RegisterRequest request) {
        return AuthResponse.from(registerUser.register(
                new RegisterUserCommand(request.username(), request.password(), request.displayName())));
    }

    @PostMapping(path = "/login", consumes = MediaType.APPLICATION_JSON_VALUE)
    @Operation(summary = "Exchange username and password for tokens")
    public AuthResponse login(@Valid @RequestBody LoginRequest request) {
        return AuthResponse.from(login.login(new LoginCommand(request.username(), request.password())));
    }

    @PostMapping(path = "/refresh", consumes = MediaType.APPLICATION_JSON_VALUE)
    @Operation(summary = "Rotate a refresh token and obtain a new access token")
    public AuthResponse refresh(@Valid @RequestBody RefreshRequest request) {
        return AuthResponse.from(refreshSession.refresh(new RefreshSessionCommand(request.refreshToken())));
    }

    @PostMapping(path = "/logout", consumes = MediaType.APPLICATION_JSON_VALUE)
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Revoke a refresh token (idempotent)")
    public void logout(@Valid @RequestBody LogoutRequest request) {
        logout.logout(new LogoutCommand(request.refreshToken()));
    }
}
