package com.cipher.messaging.application.port.out;

import com.cipher.messaging.domain.Envelope;
import java.util.UUID;

/**
 * Real-time delivery seam. Implemented by the WebSocket adapter; a {@code false} return only
 * means nobody was listening, and the envelope stays {@code SENT} until the recipient acks it
 * on a later connect.
 */
public interface EnvelopePusher {

    boolean pushNewEnvelope(UUID recipientId, Envelope envelope);
}
