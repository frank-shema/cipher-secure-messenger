package com.cipher.messaging.adapter.out.push;

import com.cipher.messaging.adapter.wire.ReceiptDto;
import com.cipher.messaging.application.port.out.ReceiptNotifier;
import com.cipher.messaging.domain.Receipt;
import com.cipher.shared.websocket.FrameCodec;
import com.cipher.shared.websocket.FrameType;
import com.cipher.shared.websocket.SessionRegistry;
import java.util.UUID;
import org.springframework.stereotype.Component;

/**
 * Relays {@code receipt.delivered} and {@code receipt.read} to the original sender if online.
 * An offline sender loses nothing: the status is persisted on the envelope.
 */
@Component
public class WebSocketReceiptNotifier implements ReceiptNotifier {

    private final SessionRegistry registry;
    private final FrameCodec codec;

    public WebSocketReceiptNotifier(SessionRegistry registry, FrameCodec codec) {
        this.registry = registry;
        this.codec = codec;
    }

    @Override
    public void notifyDelivered(UUID senderId, Receipt receipt) {
        registry.send(senderId, codec.frame(FrameType.RECEIPT_DELIVERED, ReceiptDto.from(receipt)));
    }

    @Override
    public void notifyRead(UUID senderId, Receipt receipt) {
        registry.send(senderId, codec.frame(FrameType.RECEIPT_READ, ReceiptDto.from(receipt)));
    }
}
