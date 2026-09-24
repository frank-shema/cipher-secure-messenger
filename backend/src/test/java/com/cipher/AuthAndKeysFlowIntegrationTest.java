package com.cipher;

import static org.assertj.core.api.Assertions.assertThat;

import com.cipher.shared.config.CorrelationIdFilter;
import com.cipher.support.TestKeys;
import com.fasterxml.jackson.databind.JsonNode;
import java.util.UUID;
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
 * End-to-end over HTTP against a real PostgreSQL: the auth lifecycle and the key directory.
 * The auth rate limit is raised here so the long flows never trip it; the default budget is
 * pinned by {@link AuthRateLimitIntegrationTest}.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT, properties = {
        "cipher.ratelimit.auth.capacity=1000",
        "cipher.ratelimit.auth.refill-per-minute=1000"
})
@ActiveProfiles("test")
@Testcontainers(disabledWithoutDocker = true)
class AuthAndKeysFlowIntegrationTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>("postgres:16-alpine");

    @Autowired
    private TestRestTemplate rest;

    @Test
    void registerLoginRefreshRotationAndLogout() {
        String username = uniqueUsername("alice");

        ResponseEntity<JsonNode> registered = post("/api/v1/auth/register",
                "{\"username\":\"" + username + "\",\"password\":\"cipher-alice\",\"displayName\":\"Alice\"}", null);
        assertThat(registered.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(registered.getHeaders().getFirst(CorrelationIdFilter.HEADER_NAME)).isNotBlank();
        JsonNode registeredBody = registered.getBody();
        assertThat(registeredBody.get("user").get("username").asText()).isEqualTo(username);
        assertThat(registeredBody.get("user").get("displayName").asText()).isEqualTo("Alice");
        assertThat(UUID.fromString(registeredBody.get("user").get("id").asText())).isNotNull();
        assertThat(registeredBody.get("accessToken").asText()).isNotBlank();
        assertThat(registeredBody.get("refreshToken").asText()).isNotBlank();
        assertThat(registeredBody.get("accessTokenExpiresIn").asLong()).isEqualTo(900);

        ResponseEntity<JsonNode> duplicate = post("/api/v1/auth/register",
                "{\"username\":\"" + username + "\",\"password\":\"cipher-alice\"}", null);
        assertThat(duplicate.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
        assertProblem(duplicate, "username-taken", "/api/v1/auth/register");

        ResponseEntity<JsonNode> badLogin = post("/api/v1/auth/login",
                "{\"username\":\"" + username + "\",\"password\":\"wrong-password\"}", null);
        assertThat(badLogin.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertProblem(badLogin, "invalid-credentials", "/api/v1/auth/login");

        ResponseEntity<JsonNode> login = post("/api/v1/auth/login",
                "{\"username\":\"" + username.toUpperCase() + "\",\"password\":\"cipher-alice\"}", null);
        assertThat(login.getStatusCode()).isEqualTo(HttpStatus.OK);
        String loginRefresh = login.getBody().get("refreshToken").asText();
        assertThat(loginRefresh).isNotEqualTo(registeredBody.get("refreshToken").asText());

        ResponseEntity<JsonNode> refreshed = post("/api/v1/auth/refresh", "{\"refreshToken\":\"" + loginRefresh + "\"}", null);
        assertThat(refreshed.getStatusCode()).isEqualTo(HttpStatus.OK);
        String rotatedRefresh = refreshed.getBody().get("refreshToken").asText();
        String rotatedAccess = refreshed.getBody().get("accessToken").asText();
        assertThat(rotatedRefresh).isNotEqualTo(loginRefresh);

        ResponseEntity<JsonNode> reuse = post("/api/v1/auth/refresh", "{\"refreshToken\":\"" + loginRefresh + "\"}", null);
        assertThat(reuse.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertProblem(reuse, "invalid-refresh-token", "/api/v1/auth/refresh");

        ResponseEntity<JsonNode> protectedCall = get("/api/v1/keys/me", rotatedAccess);
        assertThat(protectedCall.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
        assertProblem(protectedCall, "keys-not-registered", "/api/v1/keys/me");

        ResponseEntity<JsonNode> logout = post("/api/v1/auth/logout", "{\"refreshToken\":\"" + rotatedRefresh + "\"}", null);
        assertThat(logout.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        ResponseEntity<JsonNode> logoutAgain = post("/api/v1/auth/logout", "{\"refreshToken\":\"" + rotatedRefresh + "\"}", null);
        assertThat(logoutAgain.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);

        ResponseEntity<JsonNode> afterLogout = post("/api/v1/auth/refresh", "{\"refreshToken\":\"" + rotatedRefresh + "\"}", null);
        assertThat(afterLogout.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertProblem(afterLogout, "invalid-refresh-token", "/api/v1/auth/refresh");
    }

    @Test
    void keyDirectoryUploadConflictRotateAndLookup() {
        String bobName = uniqueUsername("bob");
        String carolName = uniqueUsername("carol");
        JsonNode bob = register(bobName, "Bob");
        JsonNode carol = register(carolName, "Carol");
        String bobToken = bob.get("accessToken").asText();
        String carolToken = carol.get("accessToken").asText();
        String bobId = bob.get("user").get("id").asText();
        String carolId = carol.get("user").get("id").asText();

        String identity = TestKeys.randomKeyBase64();
        String signing = TestKeys.randomKeyBase64();

        ResponseEntity<JsonNode> first = put("/api/v1/keys/me", material(identity, signing), bobToken);
        assertThat(first.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(first.getBody().get("userId").asText()).isEqualTo(bobId);
        assertThat(first.getBody().get("username").asText()).isEqualTo(bobName);
        assertThat(first.getBody().get("displayName").asText()).isEqualTo("Bob");
        assertThat(first.getBody().get("identityKey").asText()).isEqualTo(identity);
        assertThat(first.getBody().get("signingKey").asText()).isEqualTo(signing);
        assertThat(first.getBody().get("version").asInt()).isEqualTo(1);
        long createdAt = first.getBody().get("createdAt").asLong();
        assertThat(createdAt).isGreaterThan(1_700_000_000_000L);

        ResponseEntity<JsonNode> identical = put("/api/v1/keys/me", material(identity, signing), bobToken);
        assertThat(identical.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(identical.getBody().get("version").asInt()).isEqualTo(1);

        ResponseEntity<JsonNode> conflict = put("/api/v1/keys/me",
                material(TestKeys.randomKeyBase64(), TestKeys.randomKeyBase64()), bobToken);
        assertThat(conflict.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
        assertProblem(conflict, "keys-already-registered", "/api/v1/keys/me");
        assertThat(conflict.getBody().get("detail").asText()).contains("/api/v1/keys/me/rotate");

        ResponseEntity<JsonNode> tooShort = put("/api/v1/keys/me",
                material(TestKeys.base64(new byte[31]), signing), carolToken);
        assertThat(tooShort.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertProblem(tooShort, "validation", "/api/v1/keys/me");

        String rotatedIdentity = TestKeys.randomKeyBase64();
        String rotatedSigning = TestKeys.randomKeyBase64();
        ResponseEntity<JsonNode> rotated = post("/api/v1/keys/me/rotate", material(rotatedIdentity, rotatedSigning), bobToken);
        assertThat(rotated.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(rotated.getBody().get("version").asInt()).isEqualTo(2);
        assertThat(rotated.getBody().get("identityKey").asText()).isEqualTo(rotatedIdentity);
        assertThat(rotated.getBody().get("createdAt").asLong()).isEqualTo(createdAt);

        ResponseEntity<JsonNode> mine = get("/api/v1/keys/me", bobToken);
        assertThat(mine.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(mine.getBody().get("version").asInt()).isEqualTo(2);
        assertThat(mine.getBody().get("signingKey").asText()).isEqualTo(rotatedSigning);

        ResponseEntity<JsonNode> byId = get("/api/v1/keys/" + bobId, carolToken);
        assertThat(byId.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(byId.getBody().get("username").asText()).isEqualTo(bobName);

        ResponseEntity<JsonNode> lookup = get("/api/v1/keys/lookup?username=" + bobName, carolToken);
        assertThat(lookup.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(lookup.getBody().get("userId").asText()).isEqualTo(bobId);
        assertThat(lookup.getBody().get("version").asInt()).isEqualTo(2);

        ResponseEntity<JsonNode> unknownUser = get("/api/v1/keys/lookup?username=" + uniqueUsername("ghost"), carolToken);
        assertThat(unknownUser.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
        assertProblem(unknownUser, "user-not-found", "/api/v1/keys/lookup");

        ResponseEntity<JsonNode> keyless = get("/api/v1/keys/" + carolId, bobToken);
        assertThat(keyless.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
        assertProblem(keyless, "keys-not-registered", "/api/v1/keys/" + carolId);

        ResponseEntity<JsonNode> rotateWithoutKeys = post("/api/v1/keys/me/rotate",
                material(TestKeys.randomKeyBase64(), TestKeys.randomKeyBase64()), carolToken);
        assertThat(rotateWithoutKeys.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
        assertProblem(rotateWithoutKeys, "keys-not-registered", "/api/v1/keys/me/rotate");
    }

    @Test
    void protectedRoutesRejectMissingAndForgedTokensWithProblemJson() {
        ResponseEntity<JsonNode> missing = get("/api/v1/keys/me", null);
        assertThat(missing.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(missing.getHeaders().getFirst(HttpHeaders.WWW_AUTHENTICATE)).isEqualTo("Bearer");
        assertProblem(missing, "unauthorized", "/api/v1/keys/me");

        ResponseEntity<JsonNode> forged = get("/api/v1/keys/me", "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ4In0.forged");
        assertThat(forged.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertProblem(forged, "unauthorized", "/api/v1/keys/me");
    }

    @Test
    void correlationIdIsEchoedAndPresentInProblemBodies() {
        HttpHeaders headers = jsonHeaders(null);
        headers.set(CorrelationIdFilter.HEADER_NAME, "it-trace.007");
        ResponseEntity<JsonNode> response = rest.exchange("/api/v1/auth/login", HttpMethod.POST,
                new HttpEntity<>("{\"username\":\"nobody_here\",\"password\":\"irrelevant-pw\"}", headers), JsonNode.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(response.getHeaders().getFirst(CorrelationIdFilter.HEADER_NAME)).isEqualTo("it-trace.007");
        assertThat(response.getBody().get("correlationId").asText()).isEqualTo("it-trace.007");
    }

    @Test
    void publicEndpointsAreReachableWithoutAToken() {
        ResponseEntity<JsonNode> health = get("/actuator/health", null);
        assertThat(health.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(health.getBody().get("status").asText()).isEqualTo("UP");

        ResponseEntity<JsonNode> apiDocs = get("/v3/api-docs", null);
        assertThat(apiDocs.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(apiDocs.getBody().get("components").get("securitySchemes").has("bearerAuth")).isTrue();
        assertThat(apiDocs.getBody().get("paths").has("/api/v1/keys/me")).isTrue();
    }

    private JsonNode register(String username, String displayName) {
        ResponseEntity<JsonNode> response = post("/api/v1/auth/register",
                "{\"username\":\"" + username + "\",\"password\":\"cipher-" + displayName.toLowerCase()
                        + "\",\"displayName\":\"" + displayName + "\"}", null);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return response.getBody();
    }

    private ResponseEntity<JsonNode> post(String path, String json, String bearer) {
        return rest.exchange(path, HttpMethod.POST, new HttpEntity<>(json, jsonHeaders(bearer)), JsonNode.class);
    }

    private ResponseEntity<JsonNode> put(String path, String json, String bearer) {
        return rest.exchange(path, HttpMethod.PUT, new HttpEntity<>(json, jsonHeaders(bearer)), JsonNode.class);
    }

    private ResponseEntity<JsonNode> get(String path, String bearer) {
        return rest.exchange(path, HttpMethod.GET, new HttpEntity<>(jsonHeaders(bearer)), JsonNode.class);
    }

    private static HttpHeaders jsonHeaders(String bearer) {
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        if (bearer != null) {
            headers.setBearerAuth(bearer);
        }
        return headers;
    }

    private static void assertProblem(ResponseEntity<JsonNode> response, String slug, String instance) {
        assertThat(response.getHeaders().getContentType()).isNotNull();
        assertThat(response.getHeaders().getContentType().isCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON)).isTrue();
        JsonNode body = response.getBody();
        assertThat(body.get("type").asText()).isEqualTo("urn:cipher:problem:" + slug);
        assertThat(body.get("status").asInt()).isEqualTo(response.getStatusCode().value());
        assertThat(body.get("title").asText()).isNotBlank();
        assertThat(body.get("detail").asText()).isNotBlank();
        assertThat(body.get("instance").asText()).isEqualTo(instance);
        assertThat(body.get("correlationId").asText()).isNotBlank();
        assertThat(body.get("correlationId").asText())
                .isEqualTo(response.getHeaders().getFirst(CorrelationIdFilter.HEADER_NAME));
    }

    private static String material(String identityKey, String signingKey) {
        return "{\"identityKey\":\"" + identityKey + "\",\"signingKey\":\"" + signingKey + "\"}";
    }

    private static String uniqueUsername(String prefix) {
        return prefix + "_" + UUID.randomUUID().toString().replace("-", "").substring(0, 12);
    }
}
