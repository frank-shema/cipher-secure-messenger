package com.cipher.presence.adapter.out.push;

import com.cipher.presence.application.port.out.TypingRelay;
import com.cipher.presence.domain.TypingEvent;
import com.cipher.shared.websocket.FrameCodec;
import com.cipher.shared.websocket.FrameType;
import com.cipher.shared.websocket.SessionRegistry;
import java.util.UUID;
import org.springframework.stereotype.Component;

@Component
public class WebSocketTypingRelay implements TypingRelay {

    private final SessionRegistry registry;
    private final FrameCodec codec;

    public WebSocketTypingRelay(SessionRegistry registry, FrameCodec codec) {
        this.registry = registry;
        this.codec = codec;
    }

    @Override
    public void relay(UUID recipientId, TypingEvent event) {
        String type = event.started() ? FrameType.TYPING_START : FrameType.TYPING_STOP;
        registry.send(recipientId, codec.frame(type, new TypingDto(event.conversationId(), event.userId())));
    }
}
