package com.cipher.shared.security;

import com.cipher.shared.domain.ProblemType;
import com.cipher.shared.web.ProblemDetailFactory;
import com.cipher.shared.web.ProblemResponseWriter;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.springframework.http.HttpHeaders;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.oauth2.server.resource.InvalidBearerTokenException;
import org.springframework.security.web.AuthenticationEntryPoint;

/**
 * Turns a missing or rejected bearer token into a {@code 401 urn:cipher:problem:unauthorized}.
 *
 * <p>Spring Security's default entry point answers with an empty body and a
 * {@code WWW-Authenticate} header only; the protocol requires problem+json everywhere, and the
 * client shows different copy for "you are logged out" versus "the token was rejected".
 */
public class ProblemAuthenticationEntryPoint implements AuthenticationEntryPoint {

    private final ProblemDetailFactory problems;
    private final ProblemResponseWriter writer;

    public ProblemAuthenticationEntryPoint(ProblemDetailFactory problems, ProblemResponseWriter writer) {
        this.problems = problems;
        this.writer = writer;
    }

    @Override
    public void commence(HttpServletRequest request, HttpServletResponse response,
                         AuthenticationException authException) throws IOException {
        String detail = authException instanceof InvalidBearerTokenException
                ? "The access token is invalid or has expired"
                : "A valid bearer access token is required";
        response.setHeader(HttpHeaders.WWW_AUTHENTICATE, "Bearer");
        writer.write(response, problems.create(ProblemType.UNAUTHORIZED, detail, request));
    }
}
