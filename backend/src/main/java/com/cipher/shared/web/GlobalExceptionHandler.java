package com.cipher.shared.web;

import com.cipher.shared.domain.ProblemException;
import com.cipher.shared.domain.ProblemType;
import jakarta.servlet.http.HttpServletRequest;
import java.net.URI;
import java.util.Comparator;
import java.util.Locale;
import java.util.Objects;
import java.util.stream.Collectors;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.MessageSourceResolvable;
import org.springframework.http.HttpStatus;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.MediaType;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.validation.FieldError;
import org.springframework.web.ErrorResponse;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.HandlerMethodValidationException;
import org.springframework.web.multipart.MaxUploadSizeExceededException;

/**
 * Maps every failure that escapes a controller onto the RFC 7807 contract of PROTOCOL.md.
 *
 * <p>Controllers never build error bodies themselves: the application layer raises
 * {@link ProblemException}, framework validation raises its own exceptions, and this advice is
 * the one place that decides how each becomes a {@code type}, {@code status} and {@code detail}.
 * Unexpected exceptions are logged with their correlation id and reported as an opaque
 * {@code internal} problem so that no stack trace or SQL ever reaches a client.
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    private final ProblemDetailFactory problems;

    public GlobalExceptionHandler(ProblemDetailFactory problems) {
        this.problems = problems;
    }

    @ExceptionHandler(ProblemException.class)
    public ResponseEntity<ProblemDetail> handleProblem(ProblemException ex, HttpServletRequest request) {
        return respond(problems.create(ex.type(), ex.detail(), request));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ProblemDetail> handleInvalidBody(MethodArgumentNotValidException ex, HttpServletRequest request) {
        String detail = ex.getBindingResult().getFieldErrors().stream()
                .sorted(Comparator.comparing(FieldError::getField))
                .map(error -> error.getField() + ": " + error.getDefaultMessage())
                .collect(Collectors.joining("; "));
        return respond(problems.create(ProblemType.VALIDATION, detail.isEmpty() ? "Request validation failed" : detail, request));
    }

    @ExceptionHandler(HandlerMethodValidationException.class)
    public ResponseEntity<ProblemDetail> handleInvalidParameters(HandlerMethodValidationException ex, HttpServletRequest request) {
        String detail = ex.getAllErrors().stream()
                .map(MessageSourceResolvable::getDefaultMessage)
                .filter(Objects::nonNull)
                .sorted()
                .collect(Collectors.joining("; "));
        return respond(problems.create(ProblemType.VALIDATION, detail.isEmpty() ? "Request validation failed" : detail, request));
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<ProblemDetail> handleUnreadableBody(HttpMessageNotReadableException ex, HttpServletRequest request) {
        return respond(problems.create(ProblemType.VALIDATION, "Request body is missing or malformed", request));
    }

    @ExceptionHandler(MaxUploadSizeExceededException.class)
    public ResponseEntity<ProblemDetail> handleTooLarge(MaxUploadSizeExceededException ex, HttpServletRequest request) {
        return respond(problems.create(ProblemType.PAYLOAD_TOO_LARGE, "Request payload exceeds the permitted size", request));
    }

    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<ProblemDetail> handleAccessDenied(AccessDeniedException ex, HttpServletRequest request) {
        return respond(problems.create(ProblemType.FORBIDDEN, "Access to this resource is denied", request));
    }

    @ExceptionHandler(AuthenticationException.class)
    public ResponseEntity<ProblemDetail> handleAuthentication(AuthenticationException ex, HttpServletRequest request) {
        return respond(problems.create(ProblemType.UNAUTHORIZED, "Authentication is required", request));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ProblemDetail> handleFallback(Exception ex, HttpServletRequest request) {
        if (ex instanceof ErrorResponse errorResponse) {
            return respond(fromErrorResponse(errorResponse, request));
        }
        log.error("Unhandled exception while serving {} {}", request.getMethod(), request.getRequestURI(), ex);
        return respond(problems.create(ProblemType.INTERNAL, "An unexpected error occurred", request));
    }

    private ProblemDetail fromErrorResponse(ErrorResponse errorResponse, HttpServletRequest request) {
        HttpStatusCode status = errorResponse.getStatusCode();
        String detail = errorResponse.getBody().getDetail();
        ProblemType known = switch (status.value()) {
            case 400 -> ProblemType.VALIDATION;
            case 401 -> ProblemType.UNAUTHORIZED;
            case 403 -> ProblemType.FORBIDDEN;
            case 413 -> ProblemType.PAYLOAD_TOO_LARGE;
            case 429 -> ProblemType.RATE_LIMITED;
            case 500 -> ProblemType.INTERNAL;
            default -> null;
        };
        if (status.is5xxServerError()) {
            log.error("Framework error {} while serving {} {}: {}", status.value(), request.getMethod(),
                    request.getRequestURI(), errorResponse.getClass().getSimpleName());
        }
        if (known != null) {
            return problems.create(known, detail != null ? detail : known.title(), request);
        }
        HttpStatus resolved = HttpStatus.resolve(status.value());
        String reason = resolved != null ? resolved.getReasonPhrase() : "Error";
        URI type = URI.create(ProblemType.URN_PREFIX + slugOf(reason));
        return problems.create(status, type, reason, detail != null ? detail : reason, request);
    }

    private static String slugOf(String reasonPhrase) {
        return reasonPhrase.toLowerCase(Locale.ROOT).replaceAll("[^a-z0-9]+", "-").replaceAll("(^-|-$)", "");
    }

    private static ResponseEntity<ProblemDetail> respond(ProblemDetail problem) {
        return ResponseEntity.status(problem.getStatus())
                .contentType(MediaType.APPLICATION_PROBLEM_JSON)
                .body(problem);
    }
}
