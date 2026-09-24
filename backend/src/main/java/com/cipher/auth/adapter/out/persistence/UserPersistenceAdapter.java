package com.cipher.auth.adapter.out.persistence;

import com.cipher.auth.application.port.out.UserRepository;
import com.cipher.auth.domain.User;
import com.cipher.shared.domain.ProblemException;
import com.cipher.shared.domain.ProblemType;
import java.util.Optional;
import java.util.UUID;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * JPA implementation of {@link UserRepository}.
 *
 * <p>The domain {@link User} is deliberately separate from {@link UserEntity}: columns such as
 * {@code last_seen_at} belong to presence, not to the account aggregate, and must survive a
 * re-save of the user. The unique-constraint violation is translated here because only the
 * adapter knows it comes from the username index.
 */
@Component
public class UserPersistenceAdapter implements UserRepository {

    private final UserJpaRepository repository;

    public UserPersistenceAdapter(UserJpaRepository repository) {
        this.repository = repository;
    }

    @Override
    public Optional<User> findByUsername(String username) {
        return repository.findByUsername(username).map(UserPersistenceAdapter::toDomain);
    }

    @Override
    public Optional<User> findById(UUID id) {
        return repository.findById(id).map(UserPersistenceAdapter::toDomain);
    }

    @Override
    public boolean existsByUsername(String username) {
        return repository.existsByUsername(username);
    }

    @Override
    @Transactional
    public User save(User user) {
        UserEntity entity = repository.findById(user.id())
                .map(existing -> {
                    existing.setDisplayName(user.displayName());
                    existing.setPasswordHash(user.passwordHash());
                    return existing;
                })
                .orElseGet(() -> new UserEntity(user.id(), user.username(), user.displayName(),
                        user.passwordHash(), user.createdAt()));
        try {
            return toDomain(repository.saveAndFlush(entity));
        } catch (DataIntegrityViolationException duplicate) {
            throw new ProblemException(ProblemType.USERNAME_TAKEN,
                    "The username '" + user.username() + "' is already taken");
        }
    }

    static User toDomain(UserEntity entity) {
        return new User(entity.getId(), entity.getUsername(), entity.getDisplayName(), entity.getPasswordHash(),
                entity.getCreatedAt());
    }
}
