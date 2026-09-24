package com.cipher.shared.time;

import java.time.Clock;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Single source of "now" for the whole relay.
 *
 * <p>Token expiry, key rotation timestamps and rate-limit refills all depend on time, and all
 * of them are far easier to test deterministically when the clock is injected rather than read
 * from {@code Instant.now()} at the call site.
 */
@Configuration
public class ClockConfig {

    @Bean
    public Clock clock() {
        return Clock.systemUTC();
    }
}
