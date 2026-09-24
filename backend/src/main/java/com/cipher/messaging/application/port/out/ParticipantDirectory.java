package com.cipher.messaging.application.port.out;

import com.cipher.messaging.domain.Participant;
import java.util.Collection;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

/**
 * Read-only view of accounts for the messaging feature: existence checks when a conversation
 * is created and profile lookups for the inbox. Kept as a narrow port so messaging never
 * touches the auth aggregate and its password hash.
 */
public interface ParticipantDirectory {

    Optional<Participant> findById(UUID userId);

    Map<UUID, Participant> findAllById(Collection<UUID> userIds);
}
