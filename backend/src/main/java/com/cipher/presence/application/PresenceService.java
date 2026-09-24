package com.cipher.presence.application;

import com.cipher.presence.application.port.in.TrackPresenceUseCase;
import com.cipher.presence.application.port.out.ContactFinder;
import com.cipher.presence.application.port.out.LastSeenRepository;
import com.cipher.presence.application.port.out.PresencePublisher;
import com.cipher.presence.domain.PresenceUpdate;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

/**
 * Online/offline state and its fan-out.
 *
 * <p>The socket registry is the single source of truth for who is online, so this service does
 * not keep its own copy: it reacts to the first-session and last-session transitions the
 * adapter reports, records {@code last_seen_at} and tells the user's contacts. Only ids and
 * counts are logged.
 */
@Service
public class PresenceService implements TrackPresenceUseCase {

    private static final Logger log = LoggerFactory.getLogger(PresenceService.class);

    private final ContactFinder contacts;
    private final LastSeenRepository lastSeen;
    private final PresencePublisher publisher;
    private final Clock clock;

    public PresenceService(ContactFinder contacts, LastSeenRepository lastSeen, PresencePublisher publisher, Clock clock) {
        this.contacts = contacts;
        this.lastSeen = lastSeen;
        this.publisher = publisher;
        this.clock = clock;
    }

    @Override
    public void connected(UUID userId) {
        announce(userId, true);
    }

    @Override
    public void disconnected(UUID userId) {
        announce(userId, false);
    }

    private void announce(UUID userId, boolean online) {
        Instant now = clock.instant();
        lastSeen.recordLastSeen(userId, now);
        List<UUID> audience = contacts.contactsOf(userId);
        publisher.publish(audience, new PresenceUpdate(userId, online, now));
        log.debug("User {} is now {} (notified {} contacts)", userId, online ? "online" : "offline", audience.size());
    }
}
