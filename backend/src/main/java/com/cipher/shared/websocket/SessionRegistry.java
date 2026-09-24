package com.cipher.shared.websocket;

import java.io.IOException;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArraySet;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.ConcurrentWebSocketSessionDecorator;
import org.springframework.web.socket.handler.SessionLimitExceededException;

/**
 * Who is connected right now, and the only way to write to them.
 *
 * <p>Every session is wrapped in a {@link ConcurrentWebSocketSessionDecorator} because the
 * relay writes to a socket from many threads at once (a REST send on one request thread, a
 * receipt on another, the scheduler on a third) and the underlying container permits only one
 * writer at a time. The decorator also bounds how much the relay buffers for a stalled phone:
 * past the limit the session is terminated instead of growing the heap. A user may hold several
 * sessions (two devices, or a reconnect racing an old socket), so pushes fan out to all of them.
 * Activity timestamps live here so the idle sweep and the handler share one source of truth.
 */
@Component
public class SessionRegistry {

    private static final Logger log = LoggerFactory.getLogger(SessionRegistry.class);

    private final Map<UUID, Set<WebSocketSession>> sessionsByUser = new ConcurrentHashMap<>();
    private final Map<String, Registration> registrations = new ConcurrentHashMap<>();
    private final FrameCodec codec;
    private final WebSocketProperties properties;
    private final Clock clock;

    public SessionRegistry(FrameCodec codec, WebSocketProperties properties, Clock clock) {
        this.codec = codec;
        this.properties = properties;
        this.clock = clock;
    }

    /**
     * Wraps and records a freshly opened session.
     *
     * @return the decorated session every later write must go through, and whether it is the
     *         user's first open session (which is what "came online" means)
     */
    public Arrival register(WebSocketSession raw, UUID userId) {
        WebSocketSession decorated = new ConcurrentWebSocketSessionDecorator(raw,
                (int) properties.sendTimeLimit().toMillis(),
                (int) properties.sendBufferSizeLimit().toBytes(),
                ConcurrentWebSocketSessionDecorator.OverflowStrategy.TERMINATE);
        registrations.put(raw.getId(), new Registration(userId, decorated, clock.millis()));
        Set<WebSocketSession> sessions = sessionsByUser.computeIfAbsent(userId, ignored -> new CopyOnWriteArraySet<>());
        sessions.add(decorated);
        return new Arrival(decorated, sessions.size() == 1);
    }

    /**
     * Forgets a session.
     *
     * @return the user it belonged to and whether that user still has another open session
     */
    public Optional<Departure> unregister(WebSocketSession session) {
        Registration registration = registrations.remove(session.getId());
        if (registration == null) {
            return Optional.empty();
        }
        UUID userId = registration.userId();
        Set<WebSocketSession> remaining = sessionsByUser.get(userId);
        boolean stillOnline = false;
        if (remaining != null) {
            remaining.remove(registration.session());
            if (remaining.isEmpty()) {
                sessionsByUser.remove(userId, remaining);
            } else {
                stillOnline = true;
            }
        }
        return Optional.of(new Departure(userId, stillOnline));
    }

    public Optional<UUID> userOf(WebSocketSession session) {
        Registration registration = registrations.get(session.getId());
        return registration == null ? Optional.empty() : Optional.of(registration.userId());
    }

    public boolean isOnline(UUID userId) {
        Set<WebSocketSession> sessions = sessionsByUser.get(userId);
        return sessions != null && !sessions.isEmpty();
    }

    public int sessionCount(UUID userId) {
        Set<WebSocketSession> sessions = sessionsByUser.get(userId);
        return sessions == null ? 0 : sessions.size();
    }

    public void touch(WebSocketSession session) {
        Registration registration = registrations.get(session.getId());
        if (registration != null) {
            registration.touch(clock.millis());
        }
    }

    /**
     * Sessions with no inbound activity since {@code cutoff}, for the idle sweep.
     */
    public List<WebSocketSession> idleSince(Instant cutoff) {
        long cutoffMillis = cutoff.toEpochMilli();
        return registrations.values().stream()
                .filter(registration -> registration.lastActivityMillis() < cutoffMillis)
                .map(Registration::session)
                .toList();
    }

    /**
     * Pushes a frame to every session of the user.
     *
     * @return {@code true} if at least one session accepted the write
     */
    public boolean send(UUID userId, Frame frame) {
        Set<WebSocketSession> sessions = sessionsByUser.get(userId);
        if (sessions == null || sessions.isEmpty()) {
            return false;
        }
        String text = codec.encode(frame);
        boolean delivered = false;
        for (WebSocketSession session : sessions) {
            delivered |= sendText(session, text, frame.type());
        }
        return delivered;
    }

    /**
     * Writes to one session. The raw container session is accepted too: the registered
     * decorator is looked up so that a reply from the handler thread still goes through the
     * same serialised writer as pushes from other threads.
     */
    public boolean send(WebSocketSession session, Frame frame) {
        Registration registration = registrations.get(session.getId());
        WebSocketSession target = registration != null ? registration.session() : session;
        return sendText(target, codec.encode(frame), frame.type());
    }

    public void close(WebSocketSession session, CloseStatus status) {
        try {
            if (session.isOpen()) {
                session.close(status);
            }
        } catch (IOException closeFailed) {
            log.debug("Closing session {} failed: {}", session.getId(), closeFailed.getMessage());
        }
    }

    private boolean sendText(WebSocketSession session, String text, String type) {
        if (!session.isOpen()) {
            return false;
        }
        try {
            session.sendMessage(new TextMessage(text));
            return true;
        } catch (IOException | SessionLimitExceededException | IllegalStateException sendFailed) {
            log.warn("Sending {} frame to session {} failed: {}", type, session.getId(), sendFailed.getMessage());
            close(session, CloseStatus.SESSION_NOT_RELIABLE);
            return false;
        }
    }

    public record Arrival(WebSocketSession session, boolean firstSession) {
    }

    public record Departure(UUID userId, boolean stillOnline) {
    }

    private static final class Registration {

        private final UUID userId;
        private final WebSocketSession session;
        private volatile long lastActivityMillis;

        Registration(UUID userId, WebSocketSession session, long now) {
            this.userId = userId;
            this.session = session;
            this.lastActivityMillis = now;
        }

        UUID userId() {
            return userId;
        }

        WebSocketSession session() {
            return session;
        }

        long lastActivityMillis() {
            return lastActivityMillis;
        }

        void touch(long now) {
            lastActivityMillis = now;
        }
    }
}
