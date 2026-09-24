package com.cipher.messaging.adapter.in.websocket;

import com.cipher.messaging.application.port.in.AcknowledgeDeliveryUseCase;
import com.cipher.shared.websocket.FrameCodec;
import com.cipher.shared.websocket.FrameType;
import org.springframework.stereotype.Component;

/**
 * {@code message.ack}: the recipient confirms it holds the pushed envelopes. The use case
 * relays {@code receipt.delivered} to each sender, so nothing is sent back to the caller.
 */
@Component
public class MessageAckFrameHandler implements FrameHandler {

    private final FrameCodec codec;
    private final AcknowledgeDeliveryUseCase acknowledgeDelivery;

    public MessageAckFrameHandler(FrameCodec codec, AcknowledgeDeliveryUseCase acknowledgeDelivery) {
        this.codec = codec;
        this.acknowledgeDelivery = acknowledgeDelivery;
    }

    @Override
    public String type() {
        return FrameType.MESSAGE_ACK;
    }

    @Override
    public void handle(FrameContext context) {
        Payloads.MessageAck payload = codec.bind(context.payload(), Payloads.MessageAck.class);
        acknowledgeDelivery.acknowledge(context.userId(), Payloads.requireMessageIds(payload.messageIds()));
    }
}
