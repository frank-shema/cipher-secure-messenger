package com.cipher.messaging.adapter.wire;

import com.cipher.messaging.domain.Receipt;
import java.util.List;
import java.util.UUID;

/**
 * Payload of {@code receipt.delivered} and {@code receipt.read} frames.
 */
public record ReceiptDto(UUID conversationId, List<UUID> messageIds, UUID byUserId, long at) {

    public static ReceiptDto from(Receipt receipt) {
        return new ReceiptDto(receipt.conversationId(), receipt.messageIds(), receipt.byUserId(),
                receipt.at().toEpochMilli());
    }
}
