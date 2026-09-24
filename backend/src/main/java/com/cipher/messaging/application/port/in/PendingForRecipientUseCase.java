package com.cipher.messaging.application.port.in;

import com.cipher.messaging.domain.Envelope;
import java.util.List;
import java.util.UUID;

/**
 * Envelopes the recipient has not yet acknowledged, oldest first, replayed as
 * {@code message.new} on every connect so that a message is never lost to a dropped socket.
 */
public interface PendingForRecipientUseCase {

    List<Envelope> pendingFor(UUID userId);
}
