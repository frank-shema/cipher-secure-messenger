package com.cipher.auth.adapter.out.persistence;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserJpaRepository extends JpaRepository<UserEntity, UUID> {

    Optional<UserEntity> findByUsername(String username);

    boolean existsByUsername(String username);
}
