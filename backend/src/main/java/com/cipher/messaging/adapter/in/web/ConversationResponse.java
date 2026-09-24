package com.cipher.messaging.adapter.in.web;

import com.cipher.messaging.application.port.in.ConversationView;
import java.util.List;
import java.util.UUID;

public record ConversationResponse(UUID id, List<ParticipantResponse> participants, long createdAt, Long lastMessageAt) {

    static ConversationResponse from(ConversationView view) {
        return new ConversationResponse(
                view.conversation().id(),
                view.participants().stream().map(ParticipantResponse::from).toList(),
                view.conversation().createdAt().toEpochMilli(),
                view.conversation().lastMessageAt() == null ? null : view.conversation().lastMessageAt().toEpochMilli());
    }
}
