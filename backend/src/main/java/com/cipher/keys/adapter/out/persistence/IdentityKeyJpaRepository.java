package com.cipher.keys.adapter.out.persistence;

import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface IdentityKeyJpaRepository extends JpaRepository<IdentityKeyEntity, UUID> {
}
