package com.cipher.messaging.adapter.out.push;

import com.cipher.messaging.adapter.wire.StoredEnvelopeDto;
import com.cipher.messaging.application.port.out.EnvelopePusher;
import com.cipher.messaging.domain.Envelope;
import com.cipher.shared.websocket.FrameCodec;
import com.cipher.shared.websocket.FrameType;
import com.cipher.shared.websocket.SessionRegistry;
import java.util.UUID;
import org.springframework.stereotype.Component;

/**
 * Pushes {@code message.new} to every open session of the recipient. The return value only
 * reports whether a socket accepted the bytes; delivery is confirmed by the client's ack.
 */
@Component
public class WebSocketEnvelopePusher implements EnvelopePusher {

    private final SessionRegistry registry;
    private final FrameCodec codec;

    public WebSocketEnvelopePusher(SessionRegistry registry, FrameCodec codec) {
        this.registry = registry;
        this.codec = codec;
    }

    @Override
    public boolean pushNewEnvelope(UUID recipientId, Envelope envelope) {
        return registry.send(recipientId, codec.frame(FrameType.MESSAGE_NEW, StoredEnvelopeDto.from(envelope)));
    }
}
