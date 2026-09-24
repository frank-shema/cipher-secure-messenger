package com.cipher.keys.application.port.out;

import java.util.List;
import java.util.UUID;

/**
 * Who should learn about a user's key change.
 *
 * <p>Contacts are the users who share a conversation with the given user. Conversations do not
 * exist in this branch, so the only adapter returns nobody; the messaging branch replaces it
 * with a query over conversation participants. The port is kept explicit so that swap is a
 * one-class change and the rotation use case never has to move.
 */
public interface ContactDirectory {

    List<UUID> contactsOf(UUID userId);
}
