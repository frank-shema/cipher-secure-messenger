package com.cipher.shared.websocket;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.springframework.stereotype.Component;

/**
 * Serialises {@link Frame}s with the Spring-managed {@link ObjectMapper}.
 *
 * <p>Using the same mapper as the REST layer guarantees that a {@code StoredEnvelope} pushed as
 * {@code message.new} is byte-for-byte the object the client would get from
 * {@code GET /messages}, so the iOS client needs exactly one decoder for both paths.
 */
@Component
public class FrameCodec {

    private final ObjectMapper objectMapper;

    public FrameCodec(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    public Frame decode(String text) {
        JsonNode root;
        try {
            root = objectMapper.readTree(text);
        } catch (JsonProcessingException malformed) {
            throw new FrameDecodingException("Frame is not valid JSON", malformed);
        }
        if (root == null || !root.isObject()) {
            throw new FrameDecodingException("Frame must be a JSON object");
        }
        JsonNode type = root.get("type");
        if (type == null || !type.isTextual() || type.asText().isBlank()) {
            throw new FrameDecodingException("Frame is missing a string 'type'");
        }
        JsonNode version = root.get("v");
        int v = version != null && version.isInt() ? version.asInt() : Frame.VERSION;
        if (v != Frame.VERSION) {
            throw new FrameDecodingException("Unsupported frame version " + v);
        }
        JsonNode payload = root.get("payload");
        if (payload == null || payload.isNull()) {
            payload = objectMapper.createObjectNode();
        }
        return new Frame(v, type.asText(), payload);
    }

    public String encode(Frame frame) {
        try {
            return objectMapper.writeValueAsString(frame);
        } catch (JsonProcessingException unexpected) {
            throw new IllegalStateException("Frame of type " + frame.type() + " could not be serialised", unexpected);
        }
    }

    /**
     * Builds a frame from any Jackson-serialisable payload object.
     */
    public Frame frame(String type, Object payload) {
        JsonNode node = payload == null ? objectMapper.createObjectNode() : objectMapper.valueToTree(payload);
        return new Frame(Frame.VERSION, type, node);
    }

    public Frame emptyFrame(String type) {
        return new Frame(Frame.VERSION, type, objectMapper.createObjectNode());
    }

    /**
     * Binds a payload tree onto a record type; the caller decides how a failure is reported.
     */
    public <T> T bind(JsonNode payload, Class<T> target) {
        try {
            return objectMapper.treeToValue(payload, target);
        } catch (JsonProcessingException | IllegalArgumentException invalid) {
            throw new FrameDecodingException("Payload does not match " + target.getSimpleName(), invalid);
        }
    }

    public ObjectNode objectNode() {
        return objectMapper.createObjectNode();
    }
}
