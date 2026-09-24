package com.cipher.shared.web;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import org.springframework.http.MediaType;
import org.springframework.http.ProblemDetail;
import org.springframework.stereotype.Component;

/**
 * Writes a {@link ProblemDetail} straight to the servlet response.
 *
 * <p>Filters and Spring Security callbacks run before the MVC message converters exist, yet the
 * protocol promises {@code application/problem+json} for every error. Reusing the Spring-managed
 * {@link ObjectMapper} keeps those bodies byte-for-byte consistent with the ones produced by
 * {@code @RestControllerAdvice}, including the flattened {@code correlationId} property.
 */
@Component
public class ProblemResponseWriter {

    private final ObjectMapper objectMapper;

    public ProblemResponseWriter(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    public void write(HttpServletResponse response, ProblemDetail problem) throws IOException {
        response.setStatus(problem.getStatus());
        response.setContentType(MediaType.APPLICATION_PROBLEM_JSON_VALUE);
        response.setCharacterEncoding(StandardCharsets.UTF_8.name());
        response.getWriter().write(objectMapper.writeValueAsString(problem));
        response.getWriter().flush();
    }
}
