package com.cipher.messaging.adapter.in.websocket;

import com.cipher.shared.websocket.FrameCodec;
import com.cipher.shared.websocket.FrameType;
import com.cipher.shared.websocket.SessionRegistry;
import org.springframework.stereotype.Component;

/**
 * {@code ping} → {@code pong}. Application-level heartbeats are used instead of protocol
 * pings because URLSession on iOS does not expose the latter to the app.
 */
@Component
public class PingFrameHandler implements FrameHandler {

    private final SessionRegistry registry;
    private final FrameCodec codec;

    public PingFrameHandler(SessionRegistry registry, FrameCodec codec) {
        this.registry = registry;
        this.codec = codec;
    }

    @Override
    public String type() {
        return FrameType.PING;
    }

    @Override
    public void handle(FrameContext context) {
        registry.send(context.session(), codec.emptyFrame(FrameType.PONG));
    }
}
