package com.cipher.shared.ratelimit;

import com.cipher.shared.domain.ProblemType;
import com.cipher.shared.web.ProblemDetailFactory;
import com.cipher.shared.web.ProblemResponseWriter;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.time.Clock;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpHeaders;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Applies the per-IP budget to {@code /api/v1/auth/**} before the security chain runs.
 *
 * <p>Auth endpoints are the only unauthenticated write surface, so they are where credential
 * stuffing lands; throttling them ahead of Spring Security means a rejected request never pays
 * for BCrypt or a database round trip. The key is {@link HttpServletRequest#getRemoteAddr()}
 * on purpose: {@code X-Forwarded-For} is client-controlled and trusting it blindly would make
 * the limit trivially bypassable. Deploy behind a proxy with
 * {@code server.forward-headers-strategy} configured so the container resolves the real
 * client address.
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 10)
public class RateLimitFilter extends OncePerRequestFilter {

    static final String AUTH_PATH_PREFIX = "/api/v1/auth/";
    private static final String KEY_PREFIX = "auth:";

    private static final Logger log = LoggerFactory.getLogger(RateLimitFilter.class);

    private final TokenBucketRateLimiter limiter;
    private final ProblemDetailFactory problems;
    private final ProblemResponseWriter writer;

    /**
     * The injection constructor; explicitly marked because the package-private one below exists
     * for tests and Spring refuses to guess between two candidates.
     */
    @Autowired
    public RateLimitFilter(RateLimitProperties properties, Clock clock,
                           ProblemDetailFactory problems, ProblemResponseWriter writer) {
        this(new TokenBucketRateLimiter(properties.auth().capacity(), properties.auth().refillPerMinute(), clock),
                problems, writer);
    }

    RateLimitFilter(TokenBucketRateLimiter limiter, ProblemDetailFactory problems, ProblemResponseWriter writer) {
        this.limiter = limiter;
        this.problems = problems;
        this.writer = writer;
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String path = request.getRequestURI().substring(request.getContextPath().length());
        return !path.startsWith(AUTH_PATH_PREFIX);
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {
        TokenBucketRateLimiter.Decision decision = limiter.tryAcquire(KEY_PREFIX + request.getRemoteAddr());
        if (decision.allowed()) {
            filterChain.doFilter(request, response);
            return;
        }
        long retryAfterSeconds = decision.retryAfterSeconds();
        log.debug("Auth rate limit exceeded for {} {}; retry after {}s", request.getMethod(), request.getRequestURI(),
                retryAfterSeconds);
        response.setHeader(HttpHeaders.RETRY_AFTER, Long.toString(retryAfterSeconds));
        writer.write(response, problems.create(ProblemType.RATE_LIMITED,
                "Too many authentication requests. Retry after " + retryAfterSeconds + " seconds.", request));
    }
}
