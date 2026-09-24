package com.cipher.auth.adapter.in.seed;

import com.cipher.auth.application.port.in.RegisterUserCommand;
import com.cipher.auth.application.port.in.RegisterUserUseCase;
import com.cipher.auth.application.port.out.UserRepository;
import com.cipher.shared.config.SeedProperties;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

/**
 * Plants the three demo accounts the README and Makefile advertise (alice, bob, echo).
 *
 * <p>It goes through {@link RegisterUserUseCase} rather than the repository so seeded users
 * are indistinguishable from real sign-ups (same hashing, same normalisation). It is doubly
 * gated, on the {@code dev} profile and on {@code cipher.seed.enabled}, so that neither a
 * profile mix-up nor a flag alone can create well-known credentials on a real deployment.
 */
@Component
@Profile("dev")
public class DemoSeeder implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(DemoSeeder.class);

    static final List<RegisterUserCommand> DEMO_USERS = List.of(
            new RegisterUserCommand("alice", "cipher-alice", "Alice"),
            new RegisterUserCommand("bob", "cipher-bob", "Bob"),
            new RegisterUserCommand("echo", "cipher-echo", "Echo"));

    private final SeedProperties seedProperties;
    private final UserRepository users;
    private final RegisterUserUseCase registerUser;

    public DemoSeeder(SeedProperties seedProperties, UserRepository users, RegisterUserUseCase registerUser) {
        this.seedProperties = seedProperties;
        this.users = users;
        this.registerUser = registerUser;
    }

    @Override
    public void run(ApplicationArguments args) {
        if (!seedProperties.enabled()) {
            log.info("Demo seed disabled (cipher.seed.enabled=false)");
            return;
        }
        for (RegisterUserCommand demoUser : DEMO_USERS) {
            if (users.existsByUsername(demoUser.username())) {
                log.debug("Demo user '{}' already present", demoUser.username());
                continue;
            }
            registerUser.register(demoUser);
            log.info("Seeded demo user '{}'", demoUser.username());
        }
    }
}
