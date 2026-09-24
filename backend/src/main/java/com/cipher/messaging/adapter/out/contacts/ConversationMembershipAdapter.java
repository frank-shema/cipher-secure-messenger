package com.cipher.messaging.adapter.out.contacts;

import com.cipher.attachments.application.port.out.ConversationAccess;
import com.cipher.messaging.application.port.out.ConversationRepository;
import com.cipher.messaging.domain.Conversation;
import com.cipher.presence.application.port.out.ConversationMembership;
import java.util.Optional;
import java.util.UUID;
import org.springframework.stereotype.Component;

/**
 * Answers "is this user in this conversation, and who is the other side" for the features that
 * must not own conversations themselves: typing relay (presence) and blob authorisation
 * (attachments). Both features depend only on their own small port; this class is the one
 * place where those ports meet the messaging model.
 */
@Component
public class ConversationMembershipAdapter implements ConversationMembership, ConversationAccess {

    private final ConversationRepository conversations;

    public ConversationMembershipAdapter(ConversationRepository conversations) {
        this.conversations = conversations;
    }

    @Override
    public Optional<UUID> otherParticipant(UUID conversationId, UUID userId) {
        return conversations.findById(conversationId)
                .filter(conversation -> conversation.involves(userId))
                .map(conversation -> conversation.otherParticipant(userId));
    }

    @Override
    public Decision check(UUID conversationId, UUID userId) {
        Optional<Conversation> conversation = conversations.findById(conversationId);
        if (conversation.isEmpty()) {
            return Decision.NOT_FOUND;
        }
        return conversation.get().involves(userId) ? Decision.ALLOWED : Decision.NOT_A_PARTICIPANT;
    }
}
