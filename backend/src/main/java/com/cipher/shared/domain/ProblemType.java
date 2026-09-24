package com.cipher.shared.domain;

import java.net.URI;

/**
 * Catalogue of the RFC 7807 problem types published in PROTOCOL.md section 5.
 *
 * <p>It lives in the domain layer, free of Spring types, so that use cases can fail with a
 * precise client-facing type while the HTTP mapping stays a concern of the web layer. The
 * status code is carried as a plain {@code int} for the same reason.
 */
public enum ProblemType {
    VALIDATION("validation", 400, "Validation failed"),
    INVALID_CREDENTIALS("invalid-credentials", 401, "Invalid credentials"),
    INVALID_REFRESH_TOKEN("invalid-refresh-token", 401, "Invalid refresh token"),
    UNAUTHORIZED("unauthorized", 401, "Unauthorized"),
    FORBIDDEN("forbidden", 403, "Forbidden"),
    NOT_A_PARTICIPANT("not-a-participant", 403, "Not a participant"),
    USER_NOT_FOUND("user-not-found", 404, "User not found"),
    KEYS_NOT_REGISTERED("keys-not-registered", 404, "Keys not registered"),
    CONVERSATION_NOT_FOUND("conversation-not-found", 404, "Conversation not found"),
    BLOB_NOT_FOUND("blob-not-found", 404, "Blob not found"),
    USERNAME_TAKEN("username-taken", 409, "Username taken"),
    KEYS_ALREADY_REGISTERED("keys-already-registered", 409, "Keys already registered"),
    PAYLOAD_TOO_LARGE("payload-too-large", 413, "Payload too large"),
    RATE_LIMITED("rate-limited", 429, "Rate limited"),
    INTERNAL("internal", 500, "Internal server error");

    public static final String URN_PREFIX = "urn:cipher:problem:";

    private final String slug;
    private final int status;
    private final String title;

    ProblemType(String slug, int status, String title) {
        this.slug = slug;
        this.status = status;
        this.title = title;
    }

    public String slug() {
        return slug;
    }

    public int status() {
        return status;
    }

    public String title() {
        return title;
    }

    public URI uri() {
        return URI.create(URN_PREFIX + slug);
    }
}
