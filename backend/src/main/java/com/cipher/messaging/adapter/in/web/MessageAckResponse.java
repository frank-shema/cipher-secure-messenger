package com.cipher.messaging.adapter.in.web;

import com.cipher.messaging.domain.Envelope;
import io.swagger.v3.oas.annotations.media.Schema;
import java.util.UUID;

@Schema(name = "MessageAck")
public record MessageAckResponse(UUID id, String status, long createdAt) {

    static MessageAckResponse from(Envelope envelope) {
        return new MessageAckResponse(envelope.id(), envelope.status().name(), envelope.createdAt().toEpochMilli());
    }
}
