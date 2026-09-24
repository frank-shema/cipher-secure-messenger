package com.cipher.shared.web;

import com.cipher.shared.config.CorrelationIdFilter;
import com.cipher.shared.domain.ProblemType;
import jakarta.servlet.http.HttpServletRequest;
import java.net.URI;
import org.slf4j.MDC;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ProblemDetail;
import org.springframework.stereotype.Component;

/**
 * Builds RFC 7807 bodies in exactly one place.
 *
 * <p>Problems are produced from three very different call sites (MVC exception handler,
 * security entry points, servlet filters). Centralising the assembly guarantees they all carry
 * the same {@code type} URN scheme, the request {@code instance} and the {@code correlationId}
 * extension the iOS client uses to line up its logs with the relay's.
 */
@Component
public class ProblemDetailFactory {

    public static final String CORRELATION_ID_PROPERTY = "correlationId";

    public ProblemDetail create(ProblemType type, String detail, HttpServletRequest request) {
        return create(HttpStatusCode.valueOf(type.status()), type.uri(), type.title(), detail, request);
    }

    public ProblemDetail create(HttpStatusCode status, URI type, String title, String detail, HttpServletRequest request) {
        ProblemDetail problem = ProblemDetail.forStatus(status);
        problem.setType(type);
        problem.setTitle(title);
        problem.setDetail(detail);
        URI instance = instanceOf(request);
        if (instance != null) {
            problem.setInstance(instance);
        }
        String correlationId = MDC.get(CorrelationIdFilter.MDC_KEY);
        if (correlationId != null) {
            problem.setProperty(CORRELATION_ID_PROPERTY, correlationId);
        }
        return problem;
    }

    private static URI instanceOf(HttpServletRequest request) {
        if (request == null || request.getRequestURI() == null) {
            return null;
        }
        try {
            return URI.create(request.getRequestURI());
        } catch (IllegalArgumentException malformed) {
            return null;
        }
    }
}
