package com.cipher.messaging.adapter.in.websocket;

import com.cipher.presence.application.port.in.RelayTypingUseCase;
import com.cipher.shared.websocket.FrameCodec;

/**
 * Shared body of {@code typing.start} and {@code typing.stop}: bind the conversation, let the
 * presence feature check membership and relay. Nothing is stored.
 */
abstract class TypingFrameHandler implements FrameHandler {

    private final FrameCodec codec;
    private final RelayTypingUseCase relayTyping;
    private final boolean started;

    TypingFrameHandler(FrameCodec codec, RelayTypingUseCase relayTyping, boolean started) {
        this.codec = codec;
        this.relayTyping = relayTyping;
        this.started = started;
    }

    @Override
    public void handle(FrameContext context) {
        Payloads.Typing payload = codec.bind(context.payload(), Payloads.Typing.class);
        relayTyping.relay(context.userId(), Payloads.requireConversationId(payload.conversationId()), started);
    }
}
