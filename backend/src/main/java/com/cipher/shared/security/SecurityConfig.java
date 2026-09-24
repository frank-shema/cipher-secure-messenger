package com.cipher.shared.security;

import com.cipher.shared.web.ProblemDetailFactory;
import com.cipher.shared.web.ProblemResponseWriter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.web.SecurityFilterChain;

/**
 * Stateless resource-server configuration for the blind relay.
 *
 * <p>There are no sessions, cookies or CSRF tokens: the only credential is the HS256 access
 * token, and the iOS client stores it in the Keychain. The permit list is intentionally short:
 * auth endpoints (they issue the token), health and API docs, and the WebSocket handshake,
 * which performs its own token check because browsers and URLSession cannot always attach a
 * header there. Every other route requires a valid token and fails with problem+json.
 */
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    static final String[] PUBLIC_PATHS = {
            "/api/v1/auth/**",
            "/actuator/health/**",
            "/actuator/info",
            "/swagger-ui/**",
            "/swagger-ui.html",
            "/v3/api-docs/**",
            "/ws/**"
    };

    private final JwtDecoder jwtDecoder;
    private final ProblemDetailFactory problems;
    private final ProblemResponseWriter writer;

    public SecurityConfig(JwtDecoder jwtDecoder, ProblemDetailFactory problems, ProblemResponseWriter writer) {
        this.jwtDecoder = jwtDecoder;
        this.problems = problems;
        this.writer = writer;
    }

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        ProblemAuthenticationEntryPoint entryPoint = new ProblemAuthenticationEntryPoint(problems, writer);
        ProblemAccessDeniedHandler deniedHandler = new ProblemAccessDeniedHandler(problems, writer);
        http
                .csrf(AbstractHttpConfigurer::disable)
                .formLogin(AbstractHttpConfigurer::disable)
                .httpBasic(AbstractHttpConfigurer::disable)
                .logout(AbstractHttpConfigurer::disable)
                .requestCache(AbstractHttpConfigurer::disable)
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(authorize -> authorize
                        .requestMatchers(PUBLIC_PATHS).permitAll()
                        .anyRequest().authenticated())
                .oauth2ResourceServer(resourceServer -> resourceServer
                        .jwt(jwt -> jwt.decoder(jwtDecoder))
                        .authenticationEntryPoint(entryPoint)
                        .accessDeniedHandler(deniedHandler))
                .exceptionHandling(exceptions -> exceptions
                        .authenticationEntryPoint(entryPoint)
                        .accessDeniedHandler(deniedHandler))
                .anonymous(Customizer.withDefaults());
        return http.build();
    }
}
