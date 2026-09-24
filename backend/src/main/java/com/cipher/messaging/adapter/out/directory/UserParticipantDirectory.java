package com.cipher.messaging.adapter.out.directory;

import com.cipher.messaging.application.port.out.ParticipantDirectory;
import com.cipher.messaging.domain.Participant;
import java.util.Collection;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Bridges messaging to accounts without depending on the auth feature's ports: the projection
 * query is the whole contract, and it exposes exactly the three public fields a contact sees.
 */
@Component
@Transactional(readOnly = true)
public class UserParticipantDirectory implements ParticipantDirectory {

    private final ParticipantJpaRepository repository;

    public UserParticipantDirectory(ParticipantJpaRepository repository) {
        this.repository = repository;
    }

    @Override
    public Optional<Participant> findById(UUID userId) {
        return repository.findParticipantById(userId);
    }

    @Override
    public Map<UUID, Participant> findAllById(Collection<UUID> userIds) {
        if (userIds.isEmpty()) {
            return Map.of();
        }
        return repository.findParticipantsById(userIds).stream()
                .collect(Collectors.toMap(Participant::userId, Function.identity()));
    }
}
