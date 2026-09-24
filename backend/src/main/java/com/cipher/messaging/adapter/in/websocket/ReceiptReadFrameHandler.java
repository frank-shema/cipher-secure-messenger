package com.cipher.messaging.adapter.in.websocket;

import com.cipher.messaging.application.port.in.MarkReadUseCase;
import com.cipher.shared.websocket.FrameCodec;
import com.cipher.shared.websocket.FrameType;
import org.springframework.stereotype.Component;

/**
 * {@code receipt.read}: the recipient reports messages of one conversation were displayed.
 */
@Component
public class ReceiptReadFrameHandler implements FrameHandler {

    private final FrameCodec codec;
    private final MarkReadUseCase markRead;

    public ReceiptReadFrameHandler(FrameCodec codec, MarkReadUseCase markRead) {
        this.codec = codec;
        this.markRead = markRead;
    }

    @Override
    public String type() {
        return FrameType.RECEIPT_READ;
    }

    @Override
    public void handle(FrameContext context) {
        Payloads.ReceiptRead payload = codec.bind(context.payload(), Payloads.ReceiptRead.class);
        markRead.markRead(context.userId(), Payloads.requireConversationId(payload.conversationId()),
                Payloads.requireMessageIds(payload.messageIds()));
    }
}
