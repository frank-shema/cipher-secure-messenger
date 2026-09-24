package com.cipher;

import static org.assertj.core.api.Assertions.assertThat;

import com.fasterxml.jackson.databind.JsonNode;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.test.context.ActiveProfiles;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

/**
 * Pins the protocol's default auth budget (10 requests / minute / IP) through the real filter
 * chain. Runs in its own context so the exhausted bucket cannot leak into other flows.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
@Testcontainers(disabledWithoutDocker = true)
class AuthRateLimitIntegrationTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>("postgres:16-alpine");

    @Autowired
    private TestRestTemplate rest;

    @Test
    void eleventhAuthRequestWithinAMinuteIsRateLimited() {
        for (int attempt = 1; attempt <= 10; attempt++) {
            ResponseEntity<JsonNode> response = login();
            assertThat(response.getStatusCode()).as("attempt %d", attempt).isEqualTo(HttpStatus.UNAUTHORIZED);
        }

        ResponseEntity<JsonNode> limited = login();

        assertThat(limited.getStatusCode()).isEqualTo(HttpStatus.TOO_MANY_REQUESTS);
        assertThat(limited.getHeaders().getContentType().isCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON)).isTrue();
        assertThat(Long.parseLong(limited.getHeaders().getFirst(HttpHeaders.RETRY_AFTER))).isBetween(1L, 6L);
        assertThat(limited.getBody().get("type").asText()).isEqualTo("urn:cipher:problem:rate-limited");
        assertThat(limited.getBody().get("status").asInt()).isEqualTo(429);
        assertThat(limited.getBody().get("instance").asText()).isEqualTo("/api/v1/auth/login");
        assertThat(limited.getBody().get("correlationId").asText()).isNotBlank();

        ResponseEntity<JsonNode> unaffected = rest.getForEntity("/actuator/health", JsonNode.class);
        assertThat(unaffected.getStatusCode()).isEqualTo(HttpStatus.OK);
    }

    private ResponseEntity<JsonNode> login() {
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        return rest.exchange("/api/v1/auth/login", HttpMethod.POST,
                new HttpEntity<>("{\"username\":\"nobody_here\",\"password\":\"not-the-password\"}", headers),
                JsonNode.class);
    }
}
