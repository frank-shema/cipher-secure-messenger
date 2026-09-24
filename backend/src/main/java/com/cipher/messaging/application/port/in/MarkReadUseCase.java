package com.cipher.messaging.application.port.in;

import com.cipher.messaging.domain.Receipt;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * The recipient reports that messages of one conversation were displayed. Moves them to
 * {@code READ} (skipping {@code DELIVERED} if the ack never arrived) and notifies the sender.
 * The caller must be a participant of the conversation; ids outside it are ignored.
 */
public interface MarkReadUseCase {

    Optional<Receipt> markRead(UUID userId, UUID conversationId, List<UUID> messageIds);
}
