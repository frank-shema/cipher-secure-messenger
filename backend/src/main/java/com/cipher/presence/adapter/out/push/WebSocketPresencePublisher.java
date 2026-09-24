package com.cipher.presence.adapter.out.push;

import com.cipher.presence.application.port.out.PresencePublisher;
import com.cipher.presence.domain.PresenceUpdate;
import com.cipher.shared.websocket.Frame;
import com.cipher.shared.websocket.FrameCodec;
import com.cipher.shared.websocket.FrameType;
import com.cipher.shared.websocket.SessionRegistry;
import java.util.Collection;
import java.util.UUID;
import org.springframework.stereotype.Component;

@Component
public class WebSocketPresencePublisher implements PresencePublisher {

    private final SessionRegistry registry;
    private final FrameCodec codec;

    public WebSocketPresencePublisher(SessionRegistry registry, FrameCodec codec) {
        this.registry = registry;
        this.codec = codec;
    }

    @Override
    public void publish(Collection<UUID> recipientIds, PresenceUpdate update) {
        if (recipientIds.isEmpty()) {
            return;
        }
        Frame frame = codec.frame(FrameType.PRESENCE_UPDATE, PresenceUpdateDto.from(update));
        for (UUID recipientId : recipientIds) {
            registry.send(recipientId, frame);
        }
    }
}
