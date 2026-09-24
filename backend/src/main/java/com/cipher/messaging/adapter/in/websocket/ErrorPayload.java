package com.cipher.messaging.adapter.in.websocket;

/**
 * Payload of an {@code error} frame. Codes are the closed set from PROTOCOL.md; the message is
 * for developers and the correlation id lines the frame up with the relay's log.
 */
record ErrorPayload(String code, String message, String correlationId) {

    static final String UNKNOWN_EVENT = "unknown_event";
    static final String INVALID_PAYLOAD = "invalid_payload";
    static final String FORBIDDEN = "forbidden";
    static final String RATE_LIMITED = "rate_limited";
}
