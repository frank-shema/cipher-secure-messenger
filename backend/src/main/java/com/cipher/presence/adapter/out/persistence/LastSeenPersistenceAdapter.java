package com.cipher.presence.adapter.out.persistence;

import com.cipher.presence.application.port.out.LastSeenRepository;
import java.time.Instant;
import java.util.UUID;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Component
public class LastSeenPersistenceAdapter implements LastSeenRepository {

    private final PresenceJpaRepository repository;

    public LastSeenPersistenceAdapter(PresenceJpaRepository repository) {
        this.repository = repository;
    }

    @Override
    @Transactional
    public void recordLastSeen(UUID userId, Instant at) {
        repository.recordLastSeen(userId, at);
    }
}
