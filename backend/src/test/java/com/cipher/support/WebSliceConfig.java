package com.cipher.support;

import com.cipher.shared.security.JwtConfig;
import com.cipher.shared.security.SecurityConfig;
import com.cipher.shared.time.ClockConfig;
import com.cipher.shared.web.ProblemDetailFactory;
import com.cipher.shared.web.ProblemResponseWriter;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Import;

/**
 * Everything a {@code @WebMvcTest} slice needs besides the controller under test so that the
 * real security chain, JWT decoding and problem+json rendering are exercised.
 */
@TestConfiguration
@Import({SecurityConfig.class, JwtConfig.class, ClockConfig.class, ProblemDetailFactory.class, ProblemResponseWriter.class})
public class WebSliceConfig {
}
