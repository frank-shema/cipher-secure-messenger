package com.cipher.presence.adapter.out.push;

import com.cipher.presence.domain.PresenceUpdate;
import java.util.UUID;

/**
 * Payload of a {@code presence.update} frame.
 */
record PresenceUpdateDto(UUID userId, boolean online, long lastSeenAt) {

    static PresenceUpdateDto from(PresenceUpdate update) {
        return new PresenceUpdateDto(update.userId(), update.online(), update.lastSeenAt().toEpochMilli());
    }
}
