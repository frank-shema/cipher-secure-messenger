package com.cipher.shared.ratelimit;

import com.cipher.shared.domain.ProblemException;
import com.cipher.shared.domain.ProblemType;

/**
 * A {@code rate-limited} problem that also knows how long the caller should back off.
 *
 * <p>Per-user limits (message sends, uploads) are enforced inside controllers rather than in a
 * servlet filter because the key is the authenticated user id, which only exists after the
 * security chain ran. Carrying the retry hint on the exception lets the global handler emit the
 * same {@code Retry-After} header the auth filter emits, so the client has one backoff code path.
 */
public class RateLimitExceededException extends ProblemException {

    private final long retryAfterSeconds;

    public RateLimitExceededException(String detail, long retryAfterSeconds) {
        super(ProblemType.RATE_LIMITED, detail);
        this.retryAfterSeconds = Math.max(1, retryAfterSeconds);
    }

    public long retryAfterSeconds() {
        return retryAfterSeconds;
    }
}
