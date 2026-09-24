package com.cipher.presence.application.port.out;

import java.util.List;
import java.util.UUID;

/**
 * Who should see a user's presence: the members of their conversations. Owned by presence so
 * the feature never imports the messaging model; the messaging feature supplies the adapter.
 */
public interface ContactFinder {

    List<UUID> contactsOf(UUID userId);
}
