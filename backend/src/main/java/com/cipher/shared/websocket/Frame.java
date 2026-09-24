package com.cipher.shared.websocket;

import com.fasterxml.jackson.databind.JsonNode;
import java.util.Objects;

/**
 * One WebSocket message as defined in PROTOCOL.md section 2: a version, an event type and an
 * opaque JSON payload whose shape depends on the type.
 *
 * <p>The payload is kept as a tree rather than a typed object because the relay dispatches on
 * {@code type} first and only the matching handler knows how to bind the payload.
 */
public record Frame(int v, String type, JsonNode payload) {

    public static final int VERSION = 1;

    public Frame {
        Objects.requireNonNull(type, "type");
        Objects.requireNonNull(payload, "payload");
    }
}
