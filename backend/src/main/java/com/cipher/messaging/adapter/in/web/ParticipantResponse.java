package com.cipher.messaging.adapter.in.web;

import com.cipher.messaging.domain.Participant;
import java.util.UUID;

public record ParticipantResponse(UUID userId, String username, String displayName) {

    static ParticipantResponse from(Participant participant) {
        return new ParticipantResponse(participant.userId(), participant.username(), participant.displayName());
    }
}
