package com.cipher.presence.application;

import com.cipher.presence.application.port.in.RelayTypingUseCase;
import com.cipher.presence.application.port.out.ConversationMembership;
import com.cipher.presence.application.port.out.TypingRelay;
import com.cipher.presence.domain.TypingEvent;
import com.cipher.shared.domain.ProblemException;
import com.cipher.shared.domain.ProblemType;
import java.util.UUID;
import org.springframework.stereotype.Service;

/**
 * Typing indicators. The membership check is the whole point of routing these through a use
 * case instead of forwarding blindly: without it any authenticated user could make "Alice is
 * typing" appear in a conversation Alice is not part of.
 */
@Service
public class TypingService implements RelayTypingUseCase {

    private final ConversationMembership membership;
    private final TypingRelay relay;

    public TypingService(ConversationMembership membership, TypingRelay relay) {
        this.membership = membership;
        this.relay = relay;
    }

    @Override
    public void relay(UUID userId, UUID conversationId, boolean started) {
        UUID recipientId = membership.otherParticipant(conversationId, userId).orElseThrow(() -> new ProblemException(
                ProblemType.NOT_A_PARTICIPANT, "You are not a participant of this conversation"));
        relay.relay(recipientId, new TypingEvent(conversationId, userId, started));
    }
}
