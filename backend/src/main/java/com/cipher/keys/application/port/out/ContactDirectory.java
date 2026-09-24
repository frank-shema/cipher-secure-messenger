package com.cipher.keys.application.port.out;

import java.util.List;
import java.util.UUID;

/**
 * Who should learn about a user's key change.
 *
 * <p>Contacts are the users who share a conversation with the given user. The port is owned by
 * the keys feature and implemented by the messaging feature (a query over conversation
 * participants) so that rotation never depends on the messaging model directly.
 */
public interface ContactDirectory {

    List<UUID> contactsOf(UUID userId);
}
