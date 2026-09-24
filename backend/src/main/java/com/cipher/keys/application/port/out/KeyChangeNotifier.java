package com.cipher.keys.application.port.out;

import com.cipher.keys.domain.KeyBundle;
import java.util.List;
import java.util.UUID;

/**
 * Fan-out seam for {@code key.changed} events.
 *
 * <p>The WebSocket branch implements this by pushing a frame to every online contact; this
 * branch ships a logging adapter so the rotation use case is complete and testable now.
 * Notification is best-effort and must never fail the rotation: the client also detects
 * changed keys on the next fetch.
 */
public interface KeyChangeNotifier {

    void notifyContacts(KeyBundle bundle, List<UUID> contactIds);
}
