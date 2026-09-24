package com.cipher.messaging.adapter.in.web;

import jakarta.validation.constraints.NotNull;
import java.util.UUID;

public record CreateConversationRequest(@NotNull UUID participantId) {
}
