package com.cipher.messaging.application;

import com.cipher.messaging.application.port.in.AcknowledgeDeliveryUseCase;
import com.cipher.messaging.application.port.in.MarkReadUseCase;
import com.cipher.messaging.application.port.out.ConversationRepository;
import com.cipher.messaging.application.port.out.EnvelopeRepository;
import com.cipher.messaging.application.port.out.ReceiptNotifier;
import com.cipher.messaging.domain.Conversation;
import com.cipher.messaging.domain.DeliveryStatus;
import com.cipher.messaging.domain.Envelope;
import com.cipher.messaging.domain.Receipt;
import com.cipher.shared.domain.ProblemException;
import com.cipher.shared.domain.ProblemType;
import java.time.Clock;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Delivery and read receipts.
 *
 * <p>Receipts are the one piece of message state the relay owns outright, because the sender
 * needs them even when the recipient is offline and the sender is not. Both operations are
 * forgiving on purpose: clients retry acks after reconnects, and a list that mixes already
 * handled ids with new ones is normal, not an error. Only ids that belong to the caller as
 * recipient ever change state, so a user can never mark someone else's message as read.
 */
@Service
public class ReceiptService implements AcknowledgeDeliveryUseCase, MarkReadUseCase {

    private static final Logger log = LoggerFactory.getLogger(ReceiptService.class);

    private final EnvelopeRepository envelopes;
    private final ConversationRepository conversations;
    private final ReceiptNotifier notifier;
    private final Clock clock;

    public ReceiptService(EnvelopeRepository envelopes, ConversationRepository conversations, ReceiptNotifier notifier,
                          Clock clock) {
        this.envelopes = envelopes;
        this.conversations = conversations;
        this.notifier = notifier;
        this.clock = clock;
    }

    @Override
    @Transactional
    public List<Receipt> acknowledge(UUID userId, List<UUID> messageIds) {
        if (messageIds.isEmpty()) {
            return List.of();
        }
        Instant now = clock.instant();
        List<Envelope> delivered = envelopes.findAllById(messageIds).stream()
                .filter(envelope -> envelope.recipientId().equals(userId))
                .filter(envelope -> envelope.status() == DeliveryStatus.SENT)
                .map(envelope -> envelope.delivered(now))
                .toList();
        if (delivered.isEmpty()) {
            return List.of();
        }
        envelopes.saveAll(delivered);
        Map<UUID, List<Envelope>> byConversation = new LinkedHashMap<>();
        delivered.forEach(envelope -> byConversation
                .computeIfAbsent(envelope.conversationId(), ignored -> new ArrayList<>()).add(envelope));
        List<Receipt> receipts = new ArrayList<>();
        byConversation.forEach((conversationId, group) -> {
            Receipt receipt = new Receipt(conversationId, group.stream().map(Envelope::id).toList(), userId, now);
            notifier.notifyDelivered(group.get(0).senderId(), receipt);
            receipts.add(receipt);
        });
        log.debug("User {} acknowledged {} envelopes across {} conversations", userId, delivered.size(), receipts.size());
        return receipts;
    }

    @Override
    @Transactional
    public Optional<Receipt> markRead(UUID userId, UUID conversationId, List<UUID> messageIds) {
        Conversation conversation = conversations.findById(conversationId).orElseThrow(() -> new ProblemException(
                ProblemType.CONVERSATION_NOT_FOUND, "No conversation matches the given id"));
        if (!conversation.involves(userId)) {
            throw new ProblemException(ProblemType.NOT_A_PARTICIPANT, "You are not a participant of this conversation");
        }
        if (messageIds.isEmpty()) {
            return Optional.empty();
        }
        Instant now = clock.instant();
        List<Envelope> read = envelopes.findAllById(messageIds).stream()
                .filter(envelope -> envelope.conversationId().equals(conversationId))
                .filter(envelope -> envelope.recipientId().equals(userId))
                .filter(envelope -> envelope.status() != DeliveryStatus.READ)
                .map(envelope -> envelope.read(now))
                .toList();
        if (read.isEmpty()) {
            return Optional.empty();
        }
        envelopes.saveAll(read);
        Receipt receipt = new Receipt(conversationId, read.stream().map(Envelope::id).toList(), userId, now);
        notifier.notifyRead(conversation.otherParticipant(userId), receipt);
        log.debug("User {} read {} envelopes in conversation {}", userId, read.size(), conversationId);
        return Optional.of(receipt);
    }
}
