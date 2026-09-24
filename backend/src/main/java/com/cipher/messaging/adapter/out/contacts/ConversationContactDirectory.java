package com.cipher.messaging.adapter.out.contacts;

import com.cipher.keys.application.port.out.ContactDirectory;
import com.cipher.messaging.adapter.out.persistence.ConversationJpaRepository;
import com.cipher.presence.application.port.out.ContactFinder;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * "Contacts" in Cipher are simply the other members of a user's conversations: there is no
 * address book on the relay. One adapter serves both the keys feature ({@code key.changed}
 * fan-out) and the presence feature ({@code presence.update} fan-out) so the two can never
 * disagree about who counts as a contact.
 */
@Component
@Transactional(readOnly = true)
public class ConversationContactDirectory implements ContactDirectory, ContactFinder {

    private final ConversationJpaRepository conversations;

    public ConversationContactDirectory(ConversationJpaRepository conversations) {
        this.conversations = conversations;
    }

    @Override
    public List<UUID> contactsOf(UUID userId) {
        return conversations.findContactIds(userId);
    }
}
