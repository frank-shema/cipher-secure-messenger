package com.cipher.messaging.application.port.in;

import com.cipher.messaging.domain.Envelope;

/**
 * The stored envelope plus whether this call created it. A retry with a known id yields
 * {@code created == false} and the stored status, which is how the client reconciles its
 * optimistic UI after a flaky connection.
 */
public record SendEnvelopeResult(Envelope envelope, boolean created) {
}
