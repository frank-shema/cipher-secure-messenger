package com.cipher.shared.security;

import com.cipher.shared.domain.ProblemType;
import com.cipher.shared.web.ProblemDetailFactory;
import com.cipher.shared.web.ProblemResponseWriter;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.web.access.AccessDeniedHandler;

/**
 * Turns an authenticated-but-not-allowed request into a {@code 403 urn:cipher:problem:forbidden}
 * body instead of the framework's empty response.
 */
public class ProblemAccessDeniedHandler implements AccessDeniedHandler {

    private final ProblemDetailFactory problems;
    private final ProblemResponseWriter writer;

    public ProblemAccessDeniedHandler(ProblemDetailFactory problems, ProblemResponseWriter writer) {
        this.problems = problems;
        this.writer = writer;
    }

    @Override
    public void handle(HttpServletRequest request, HttpServletResponse response,
                       AccessDeniedException accessDeniedException) throws IOException {
        writer.write(response, problems.create(ProblemType.FORBIDDEN, "Access to this resource is denied", request));
    }
}
