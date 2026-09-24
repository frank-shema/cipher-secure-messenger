package com.cipher.keys.adapter.out.notify;

import com.cipher.keys.application.port.out.KeyChangeNotifier;
import com.cipher.keys.domain.KeyBundle;
import com.cipher.shared.websocket.Frame;
import com.cipher.shared.websocket.FrameCodec;
import com.cipher.shared.websocket.FrameType;
import com.cipher.shared.websocket.SessionRegistry;
import java.util.List;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

/**
 * Pushes {@code key.changed} to every online contact of the rotating user.
 *
 * <p>Best effort by design: an offline contact learns about the rotation on its next key fetch,
 * and the iOS client treats any version bump as "verify again" regardless of how it found out.
 * Only ids, the version and the delivered count are logged; key bytes travel in the frame,
 * never in the log.
 */
@Component
public class WebSocketKeyChangeNotifier implements KeyChangeNotifier {

    private static final Logger log = LoggerFactory.getLogger(WebSocketKeyChangeNotifier.class);

    private final SessionRegistry registry;
    private final FrameCodec codec;

    public WebSocketKeyChangeNotifier(SessionRegistry registry, FrameCodec codec) {
        this.registry = registry;
        this.codec = codec;
    }

    @Override
    public void notifyContacts(KeyBundle bundle, List<UUID> contactIds) {
        if (contactIds.isEmpty()) {
            return;
        }
        Frame frame = codec.frame(FrameType.KEY_CHANGED, KeyChangedDto.from(bundle));
        int delivered = 0;
        for (UUID contactId : contactIds) {
            if (registry.send(contactId, frame)) {
                delivered++;
            }
        }
        log.info("key.changed userId={} version={} contacts={} delivered={}", bundle.userId(), bundle.version(),
                contactIds.size(), delivered);
    }
}
