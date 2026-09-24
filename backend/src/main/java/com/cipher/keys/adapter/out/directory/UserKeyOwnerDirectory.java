package com.cipher.keys.adapter.out.directory;

import com.cipher.auth.application.port.out.UserRepository;
import com.cipher.auth.domain.User;
import com.cipher.keys.application.port.out.KeyOwnerDirectory;
import com.cipher.keys.domain.KeyOwner;
import java.util.Optional;
import java.util.UUID;
import org.springframework.stereotype.Component;

/**
 * Bridges the keys feature to accounts through the auth feature's outbound port, projecting
 * the aggregate down to the public fields so the password hash never crosses the boundary.
 */
@Component
public class UserKeyOwnerDirectory implements KeyOwnerDirectory {

    private final UserRepository users;

    public UserKeyOwnerDirectory(UserRepository users) {
        this.users = users;
    }

    @Override
    public Optional<KeyOwner> findById(UUID userId) {
        return users.findById(userId).map(UserKeyOwnerDirectory::toOwner);
    }

    @Override
    public Optional<KeyOwner> findByUsername(String username) {
        return users.findByUsername(username).map(UserKeyOwnerDirectory::toOwner);
    }

    private static KeyOwner toOwner(User user) {
        return new KeyOwner(user.id(), user.username(), user.displayName());
    }
}
