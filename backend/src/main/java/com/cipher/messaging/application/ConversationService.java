package com.cipher.messaging.application;

import com.cipher.messaging.application.port.in.ConversationResult;
import com.cipher.messaging.application.port.in.ConversationView;
import com.cipher.messaging.application.port.in.CreateOrGetConversationUseCase;
import com.cipher.messaging.application.port.in.ListConversationsUseCase;
import com.cipher.messaging.application.port.out.ConversationRepository;
import com.cipher.messaging.application.port.out.ParticipantDirectory;
import com.cipher.messaging.domain.Conversation;
import com.cipher.messaging.domain.Participant;
import com.cipher.shared.domain.ProblemException;
import com.cipher.shared.domain.ProblemType;
import java.time.Clock;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

/**
 * The inbox: resolving and listing 1:1 conversations.
 *
 * <p>Creation is idempotent because the conversation id is a pure function of the participant
 * pair. That property is what lets two phones "create" the same conversation at the same moment
 * and still converge, and what lets the client compute the id offline before the relay is ever
 * asked. The relay never learns anything about a conversation beyond who is in it.
 */
@Service
public class ConversationService implements CreateOrGetConversationUseCase, ListConversationsUseCase {

    private static final Logger log = LoggerFactory.getLogger(ConversationService.class);

    private final ConversationRepository conversations;
    private final ParticipantDirectory participants;
    private final Clock clock;

    public ConversationService(ConversationRepository conversations, ParticipantDirectory participants, Clock clock) {
        this.conversations = conversations;
        this.participants = participants;
        this.clock = clock;
    }

    @Override
    public ConversationResult createOrGet(UUID userId, UUID participantId) {
        if (userId.equals(participantId)) {
            throw new ProblemException(ProblemType.VALIDATION, "participantId must be another user, not yourself");
        }
        Participant other = participants.findById(participantId).orElseThrow(() -> new ProblemException(
                ProblemType.USER_NOT_FOUND, "No user matches participantId"));
        Participant self = participants.findById(userId).orElseThrow(() -> new ProblemException(
                ProblemType.USER_NOT_FOUND, "The authenticated user no longer exists"));
        Conversation canonical = Conversation.between(userId, participantId, clock.instant());
        Optional<Conversation> existing = conversations.findById(canonical.id());
        if (existing.isPresent()) {
            return new ConversationResult(view(existing.get(), Map.of(self.userId(), self, other.userId(), other)), false);
        }
        Conversation saved = conversations.save(canonical);
        boolean created = saved.equals(canonical);
        if (created) {
            log.info("Created conversation id={} between {} and {}", saved.id(), saved.participantA(), saved.participantB());
        }
        return new ConversationResult(view(saved, Map.of(self.userId(), self, other.userId(), other)), created);
    }

    @Override
    public List<ConversationView> listFor(UUID userId) {
        List<Conversation> owned = conversations.findAllInvolving(userId);
        Set<UUID> memberIds = new HashSet<>();
        owned.forEach(conversation -> memberIds.addAll(conversation.participants()));
        Map<UUID, Participant> profiles = memberIds.isEmpty() ? Map.of() : participants.findAllById(memberIds);
        return owned.stream().map(conversation -> view(conversation, profiles)).toList();
    }

    private static ConversationView view(Conversation conversation, Map<UUID, Participant> profiles) {
        List<Participant> members = conversation.participants().stream()
                .map(id -> Optional.ofNullable(profiles.get(id))
                        .orElseThrow(() -> new IllegalStateException("Conversation " + conversation.id()
                                + " references a missing user " + id)))
                .toList();
        return new ConversationView(conversation, members);
    }
}
