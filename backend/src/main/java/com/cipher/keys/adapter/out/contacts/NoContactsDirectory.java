package com.cipher.keys.adapter.out.contacts;

import com.cipher.keys.application.port.out.ContactDirectory;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Component;

/**
 * Until conversations exist there is no way to know who a user talks to, so nobody is
 * notified. This adapter exists purely to make the {@link ContactDirectory} seam concrete; the
 * messaging branch swaps it for a query over conversation participants.
 */
@Component
public class NoContactsDirectory implements ContactDirectory {

    @Override
    public List<UUID> contactsOf(UUID userId) {
        return List.of();
    }
}
