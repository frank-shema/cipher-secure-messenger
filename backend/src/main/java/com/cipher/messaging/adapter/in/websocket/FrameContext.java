package com.cipher.messaging.adapter.in.websocket;

import com.fasterxml.jackson.databind.JsonNode;
import java.util.UUID;
import org.springframework.web.socket.WebSocketSession;

/**
 * What a {@link FrameHandler} receives: the authenticated user (from the handshake, never from
 * the payload), the session to reply on, the raw payload tree and the correlation id of this
 * frame for logging and error frames.
 */
public record FrameContext(UUID userId, WebSocketSession session, JsonNode payload, String correlationId) {
}
