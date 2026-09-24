package com.cipher.messaging.application;

import com.cipher.messaging.application.port.in.GetMessagesQuery;
import com.cipher.messaging.application.port.in.GetMessagesUseCase;
import com.cipher.messaging.application.port.in.MessagePage;
import com.cipher.messaging.application.port.in.PendingForRecipientUseCase;
import com.cipher.messaging.application.port.in.PurgeExpiredEnvelopesUseCase;
import com.cipher.messaging.application.port.in.SendEnvelopeCommand;
import com.cipher.messaging.application.port.in.SendEnvelopeResult;
import com.cipher.messaging.application.port.in.SendEnvelopeUseCase;
import com.cipher.messaging.application.port.out.ConversationRepository;
import com.cipher.messaging.application.port.out.EnvelopePusher;
import com.cipher.messaging.application.port.out.EnvelopeRepository;
import com.cipher.messaging.domain.Conversation;
import com.cipher.messaging.domain.Envelope;
import com.cipher.shared.domain.ProblemException;
import com.cipher.shared.domain.ProblemType;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Accepting, paging, replaying and expiring opaque envelopes.
 *
 * <p>The relay cannot read a message, so routing metadata is the only thing it can police:
 * the sender must be the caller, the conversation must be one of theirs, the recipient must be
 * the other member, and the byte sizes must be sane. Those checks all happen here rather than
 * in the controller so that no future transport (a second REST version, a WebSocket send) can
 * bypass them. Storing and pushing are deliberately separate steps: the row is committed before
 * the recipient is told about it, otherwise a fast {@code message.ack} could race the insert
 * and find nothing to acknowledge.
 */
@Service
public class EnvelopeService implements SendEnvelopeUseCase, GetMessagesUseCase, PendingForRecipientUseCase,
        PurgeExpiredEnvelopesUseCase {

    private static final Logger log = LoggerFactory.getLogger(EnvelopeService.class);

    private final ConversationRepository conversations;
    private final EnvelopeRepository envelopes;
    private final EnvelopePusher pusher;
    private final TransactionTemplate transactions;
    private final Clock clock;

    public EnvelopeService(ConversationRepository conversations, EnvelopeRepository envelopes, EnvelopePusher pusher,
                           TransactionTemplate transactions, Clock clock) {
        this.conversations = conversations;
        this.envelopes = envelopes;
        this.pusher = pusher;
        this.transactions = transactions;
        this.clock = clock;
    }

    @Override
    public SendEnvelopeResult send(SendEnvelopeCommand command) {
        if (!command.pathConversationId().equals(command.conversationId())) {
            throw new ProblemException(ProblemType.VALIDATION, "conversationId must match the conversation in the path");
        }
        Conversation conversation = requireMembership(command.conversationId(), command.principalId());
        if (!command.principalId().equals(command.senderId())) {
            throw new ProblemException(ProblemType.VALIDATION, "senderId must be the authenticated user");
        }
        UUID expectedRecipient = conversation.otherParticipant(command.principalId());
        if (!expectedRecipient.equals(command.recipientId())) {
            throw new ProblemException(ProblemType.VALIDATION, "recipientId must be the other participant of the conversation");
        }
        Optional<Envelope> duplicate = envelopes.findById(command.id());
        if (duplicate.isPresent()) {
            Envelope stored = duplicate.get();
            if (!stored.senderId().equals(command.principalId()) || !stored.conversationId().equals(conversation.id())) {
                throw new ProblemException(ProblemType.VALIDATION, "Message id is already used by another envelope");
            }
            log.debug("Duplicate envelope id={} from {}; returning stored status {}", stored.id(), stored.senderId(),
                    stored.status());
            return new SendEnvelopeResult(stored, false);
        }
        Instant now = clock.instant();
        Envelope accepted = Envelope.sent(command.id(), conversation.id(), command.senderId(), command.recipientId(),
                command.counter(), command.clientTimestamp(), command.ciphertext(), command.signature(),
                command.expiresAt(), now);
        Envelope stored = transactions.execute(status -> {
            Envelope saved = envelopes.save(accepted);
            conversations.recordMessageAt(conversation.id(), now);
            return saved;
        });
        boolean pushed = pusher.pushNewEnvelope(stored.recipientId(), stored);
        log.info("Stored envelope id={} conversation={} bytes={} pushed={}", stored.id(), stored.conversationId(),
                stored.ciphertextSize(), pushed);
        return new SendEnvelopeResult(stored, true);
    }

    @Override
    @Transactional(readOnly = true)
    public MessagePage getMessages(GetMessagesQuery query) {
        requireMembership(query.conversationId(), query.userId());
        List<Envelope> page = envelopes.findPage(query.conversationId(), query.before(), query.limit() + 1);
        boolean hasMore = page.size() > query.limit();
        return new MessagePage(hasMore ? page.subList(0, query.limit()) : page, hasMore);
    }

    @Override
    @Transactional(readOnly = true)
    public List<Envelope> pendingFor(UUID userId) {
        Instant now = clock.instant();
        return envelopes.findPendingForRecipient(userId).stream()
                .filter(envelope -> !envelope.isExpiredAt(now))
                .toList();
    }

    @Override
    @Transactional
    public int purgeExpired() {
        int removed = envelopes.deleteExpiredBefore(clock.instant());
        if (removed > 0) {
            log.info("Purged {} expired envelopes", removed);
        }
        return removed;
    }

    private Conversation requireMembership(UUID conversationId, UUID userId) {
        Conversation conversation = conversations.findById(conversationId).orElseThrow(() -> new ProblemException(
                ProblemType.CONVERSATION_NOT_FOUND, "No conversation matches the given id"));
        if (!conversation.involves(userId)) {
            throw new ProblemException(ProblemType.NOT_A_PARTICIPANT, "You are not a participant of this conversation");
        }
        return conversation;
    }
}
