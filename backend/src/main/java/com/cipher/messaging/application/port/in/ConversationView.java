package com.cipher.messaging.application.port.in;

import com.cipher.messaging.domain.Conversation;
import com.cipher.messaging.domain.Participant;
import java.util.List;

/**
 * A conversation joined with its members' public profiles, which is what the client renders in
 * its inbox; the bare {@link Conversation} carries only ids.
 */
public record ConversationView(Conversation conversation, List<Participant> participants) {

    public ConversationView {
        participants = List.copyOf(participants);
    }
}
