package com.cipher.messaging.application.port.in;

import com.cipher.messaging.domain.Receipt;
import java.util.List;
import java.util.UUID;

/**
 * The recipient confirms it holds the pushed envelopes.
 *
 * <p>Only envelopes addressed to the caller and still {@code SENT} change state; anything else
 * in the list is ignored rather than rejected, because acks are retried and may legitimately
 * name messages already acknowledged from another device. Each affected sender is notified
 * with a {@code receipt.delivered}.
 */
public interface AcknowledgeDeliveryUseCase {

    List<Receipt> acknowledge(UUID userId, List<UUID> messageIds);
}
