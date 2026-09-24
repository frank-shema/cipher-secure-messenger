package com.cipher.shared.ratelimit;

import static org.assertj.core.api.Assertions.assertThat;

import com.cipher.shared.config.CorrelationIdFilter;
import com.cipher.shared.web.ProblemDetailFactory;
import com.cipher.shared.web.ProblemResponseWriter;
import com.cipher.support.MutableClock;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Instant;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.slf4j.MDC;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.converter.json.Jackson2ObjectMapperBuilder;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

class RateLimitFilterTest {

    private final ObjectMapper objectMapper = Jackson2ObjectMapperBuilder.json().build();
    private RateLimitFilter filter;

    @BeforeEach
    void setUp() {
        MutableClock clock = new MutableClock(Instant.parse("2026-09-24T10:00:00Z"));
        TokenBucketRateLimiter limiter = new TokenBucketRateLimiter(2, 1, clock);
        filter = new RateLimitFilter(limiter, new ProblemDetailFactory(), new ProblemResponseWriter(objectMapper));
    }

    @AfterEach
    void tearDown() {
        MDC.clear();
    }

    @Test
    void passesRequestsWithinBudgetAndRejectsTheRest() throws Exception {
        assertThat(send("/api/v1/auth/login", "10.0.0.1").getStatus()).isEqualTo(200);
        assertThat(send("/api/v1/auth/register", "10.0.0.1").getStatus()).isEqualTo(200);

        MockHttpServletResponse limited = send("/api/v1/auth/login", "10.0.0.1");

        assertThat(limited.getStatus()).isEqualTo(429);
        assertThat(limited.getContentType()).startsWith(MediaType.APPLICATION_PROBLEM_JSON_VALUE);
        assertThat(limited.getHeader(HttpHeaders.RETRY_AFTER)).isEqualTo("30");
        JsonNode body = objectMapper.readTree(limited.getContentAsString());
        assertThat(body.get("type").asText()).isEqualTo("urn:cipher:problem:rate-limited");
        assertThat(body.get("status").asInt()).isEqualTo(429);
        assertThat(body.get("instance").asText()).isEqualTo("/api/v1/auth/login");
    }

    @Test
    void budgetsArePerClientAddress() throws Exception {
        send("/api/v1/auth/login", "10.0.0.1");
        send("/api/v1/auth/login", "10.0.0.1");
        assertThat(send("/api/v1/auth/login", "10.0.0.1").getStatus()).isEqualTo(429);

        assertThat(send("/api/v1/auth/login", "10.0.0.2").getStatus()).isEqualTo(200);
    }

    @Test
    void ignoresPathsOutsideTheAuthNamespace() throws Exception {
        send("/api/v1/auth/login", "10.0.0.1");
        send("/api/v1/auth/login", "10.0.0.1");
        assertThat(send("/api/v1/auth/login", "10.0.0.1").getStatus()).isEqualTo(429);

        assertThat(send("/api/v1/keys/me", "10.0.0.1").getStatus()).isEqualTo(200);
        assertThat(send("/actuator/health", "10.0.0.1").getStatus()).isEqualTo(200);
    }

    @Test
    void includesCorrelationIdFromMdcInTheProblemBody() throws Exception {
        MDC.put(CorrelationIdFilter.MDC_KEY, "trace-42");
        send("/api/v1/auth/login", "10.0.0.9");
        send("/api/v1/auth/login", "10.0.0.9");

        MockHttpServletResponse limited = send("/api/v1/auth/login", "10.0.0.9");

        JsonNode body = objectMapper.readTree(limited.getContentAsString());
        assertThat(body.get("correlationId").asText()).isEqualTo("trace-42");
    }

    private MockHttpServletResponse send(String path, String remoteAddr) throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("POST", path);
        request.setRequestURI(path);
        request.setRemoteAddr(remoteAddr);
        MockHttpServletResponse response = new MockHttpServletResponse();
        filter.doFilter(request, response, new MockFilterChain());
        return response;
    }
}
