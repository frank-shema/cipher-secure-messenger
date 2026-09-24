package com.cipher.shared.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;

/**
 * Controls the demo data seeder; off by default so a misconfigured profile can never plant
 * well-known credentials in a real deployment.
 */
@ConfigurationProperties(prefix = "cipher.seed")
public record SeedProperties(@DefaultValue("false") boolean enabled) {
}
