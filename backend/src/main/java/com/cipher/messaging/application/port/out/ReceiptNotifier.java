package com.cipher.messaging.application.port.out;

import com.cipher.messaging.domain.Receipt;
import java.util.UUID;

/**
 * Best-effort fan-out of receipts to the original sender. Receipts are also persisted on the
 * envelope, so a sender who is offline learns the status from the next history fetch.
 */
public interface ReceiptNotifier {

    void notifyDelivered(UUID senderId, Receipt receipt);

    void notifyRead(UUID senderId, Receipt receipt);
}
