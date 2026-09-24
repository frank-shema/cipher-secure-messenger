package com.cipher.messaging.adapter.in.websocket;

import com.cipher.shared.websocket.SessionRegistry;
import com.cipher.shared.websocket.WebSocketProperties;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.WebSocketSession;

/**
 * Closes sessions that stopped sending anything (including {@code ping}) for the idle timeout.
 *
 * <p>Phones lose connectivity without ever sending a close frame; without this sweep such
 * sessions would keep their user "online" and swallow pushes forever. Only inbound activity
 * counts, because the relay pushing to a dead socket proves nothing about the phone.
 */
@Component
public class IdleSessionSweeper {

    private static final Logger log = LoggerFactory.getLogger(IdleSessionSweeper.class);

    private final SessionRegistry registry;
    private final WebSocketProperties properties;
    private final Clock clock;

    public IdleSessionSweeper(SessionRegistry registry, WebSocketProperties properties, Clock clock) {
        this.registry = registry;
        this.properties = properties;
        this.clock = clock;
    }

    @Scheduled(fixedDelayString = "${cipher.websocket.idle-sweep-interval:PT15S}")
    public void sweep() {
        Instant cutoff = clock.instant().minus(properties.idleTimeout());
        List<WebSocketSession> idle = registry.idleSince(cutoff);
        for (WebSocketSession session : idle) {
            registry.close(session, RelayCloseStatus.IDLE);
        }
        if (!idle.isEmpty()) {
            log.debug("Closed {} idle sessions", idle.size());
        }
    }
}
