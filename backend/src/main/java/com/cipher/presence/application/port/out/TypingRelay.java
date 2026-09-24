package com.cipher.presence.application.port.out;

import com.cipher.presence.domain.TypingEvent;
import java.util.UUID;

/**
 * Delivers a typing indicator to one recipient if they are online; otherwise it is dropped,
 * which is the correct outcome for an indicator that is stale within seconds anyway.
 */
public interface TypingRelay {

    void relay(UUID recipientId, TypingEvent event);
}
