package com.cipher.shared.domain;

import java.util.Objects;

/**
 * The single failure channel from domain and application code to the HTTP layer.
 *
 * <p>Every expected failure (bad credentials, duplicate username, missing keys, ...) is raised
 * as one of these so that {@code GlobalExceptionHandler} can turn it into an RFC 7807 body
 * without a per-feature mapping table, and so that the wire contract cannot drift from the
 * {@link ProblemType} catalogue.
 */
public class ProblemException extends RuntimeException {

    private final ProblemType type;

    public ProblemException(ProblemType type, String detail) {
        super(detail);
        this.type = Objects.requireNonNull(type, "type");
    }

    public ProblemType type() {
        return type;
    }

    public String detail() {
        return getMessage();
    }
}
