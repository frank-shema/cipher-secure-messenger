package com.cipher.messaging.adapter.in.websocket;

import com.cipher.presence.application.port.in.RelayTypingUseCase;
import com.cipher.shared.websocket.FrameCodec;
import com.cipher.shared.websocket.FrameType;
import org.springframework.stereotype.Component;

@Component
public class TypingStopFrameHandler extends TypingFrameHandler {

    public TypingStopFrameHandler(FrameCodec codec, RelayTypingUseCase relayTyping) {
        super(codec, relayTyping, false);
    }

    @Override
    public String type() {
        return FrameType.TYPING_STOP;
    }
}
