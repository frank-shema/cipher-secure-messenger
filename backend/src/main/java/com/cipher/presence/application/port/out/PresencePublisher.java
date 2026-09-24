package com.cipher.presence.application.port.out;

import com.cipher.presence.domain.PresenceUpdate;
import java.util.Collection;
import java.util.UUID;

/**
 * Best-effort fan-out of {@code presence.update}. Offline recipients are simply skipped; they
 * will see current presence when they reconnect and their own contacts announce themselves.
 */
public interface PresencePublisher {

    void publish(Collection<UUID> recipientIds, PresenceUpdate update);
}
