package com.cipher;

import static org.assertj.core.api.Assertions.assertThat;

import com.cipher.shared.config.CorrelationIdFilter;
import java.util.Arrays;
import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.MigrationInfo;
import org.flywaydb.core.api.MigrationState;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.context.ApplicationContext;
import org.springframework.test.context.ActiveProfiles;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

@SpringBootTest
@ActiveProfiles("test")
@Testcontainers(disabledWithoutDocker = true)
class CipherRelayApplicationTests {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>("postgres:16-alpine");

    @Autowired
    private ApplicationContext context;

    @Autowired
    private Flyway flyway;

    @Test
    void contextLoads() {
        assertThat(context.getBean(CorrelationIdFilter.class)).isNotNull();
    }

    @Test
    void allMigrationsAreApplied() {
        MigrationInfo current = flyway.info().current();

        assertThat(current).isNotNull();
        assertThat(current.getVersion().getVersion()).isEqualTo("3");
        assertThat(current.getState()).isEqualTo(MigrationState.SUCCESS);
        assertThat(Arrays.stream(flyway.info().applied()).map(info -> info.getVersion().getVersion()))
                .containsExactly("1", "2", "3");
    }
}
