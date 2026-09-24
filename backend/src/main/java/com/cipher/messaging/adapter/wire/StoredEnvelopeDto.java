package com.cipher.messaging.adapter.wire;

import com.cipher.messaging.domain.Envelope;
import java.time.Instant;
import java.util.Base64;
import java.util.List;
import java.util.UUID;

/**
 * The {@code StoredEnvelope} of PROTOCOL.md: the envelope as sent plus relay-owned status.
 *
 * <p>One record serves both {@code GET /messages} items and the {@code message.new} push so the
 * iOS client decodes a single shape wherever an envelope comes from. Timestamps are epoch
 * milliseconds and binary fields standard base64, exactly as the client submitted them.
 */
public record StoredEnvelopeDto(int v,
                                UUID id,
                                UUID conversationId,
                                UUID senderId,
                                UUID recipientId,
                                long counter,
                                long timestamp,
                                String ciphertext,
                                String signature,
                                Long expiresAt,
                                String status,
                                long createdAt,
                                Long deliveredAt,
                                Long readAt) {

    private static final Base64.Encoder ENCODER = Base64.getEncoder();

    public static StoredEnvelopeDto from(Envelope envelope) {
        return new StoredEnvelopeDto(
                1,
                envelope.id(),
                envelope.conversationId(),
                envelope.senderId(),
                envelope.recipientId(),
                envelope.counter(),
                envelope.clientTimestamp(),
                ENCODER.encodeToString(envelope.ciphertext()),
                ENCODER.encodeToString(envelope.signature()),
                millis(envelope.expiresAt()),
                envelope.status().name(),
                envelope.createdAt().toEpochMilli(),
                millis(envelope.deliveredAt()),
                millis(envelope.readAt()));
    }

    public static List<StoredEnvelopeDto> from(List<Envelope> envelopes) {
        return envelopes.stream().map(StoredEnvelopeDto::from).toList();
    }

    private static Long millis(Instant instant) {
        return instant == null ? null : instant.toEpochMilli();
    }
}
