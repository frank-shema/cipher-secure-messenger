package com.cipher.messaging.adapter.in.websocket;

import com.cipher.shared.websocket.FrameDecodingException;
import java.util.List;
import java.util.UUID;

/**
 * Client-to-server payload shapes and the size sanity checks shared by the handlers.
 */
final class Payloads {

    static final int MAX_MESSAGE_IDS = 500;

    private Payloads() {
    }

    record MessageAck(List<UUID> messageIds) {
    }

    record ReceiptRead(UUID conversationId, List<UUID> messageIds) {
    }

    record Typing(UUID conversationId) {
    }

    static List<UUID> requireMessageIds(List<UUID> messageIds) {
        if (messageIds == null || messageIds.isEmpty()) {
            throw new FrameDecodingException("messageIds must contain at least one id");
        }
        if (messageIds.size() > MAX_MESSAGE_IDS) {
            throw new FrameDecodingException("messageIds may contain at most " + MAX_MESSAGE_IDS + " ids");
        }
        if (messageIds.stream().anyMatch(id -> id == null)) {
            throw new FrameDecodingException("messageIds must not contain null");
        }
        return messageIds;
    }

    static UUID requireConversationId(UUID conversationId) {
        if (conversationId == null) {
            throw new FrameDecodingException("conversationId is required");
        }
        return conversationId;
    }
}
