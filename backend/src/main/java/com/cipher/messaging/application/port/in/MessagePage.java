package com.cipher.messaging.application.port.in;

import com.cipher.messaging.domain.Envelope;
import java.util.List;

/**
 * One page of history, newest first, with a flag instead of a total count: counting a
 * conversation's rows on every page would cost more than it tells the client.
 */
public record MessagePage(List<Envelope> items, boolean hasMore) {

    public MessagePage {
        items = List.copyOf(items);
    }
}
