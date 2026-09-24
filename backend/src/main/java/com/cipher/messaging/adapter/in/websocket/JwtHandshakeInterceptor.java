package com.cipher.messaging.adapter.in.websocket;

import com.cipher.shared.domain.ProblemException;
import com.cipher.shared.domain.ProblemType;
import com.cipher.shared.security.AuthenticatedUser;
import com.cipher.shared.security.CurrentUserArgumentResolver;
import com.cipher.shared.web.ProblemDetailFactory;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.http.HttpServletRequest;
import java.io.IOException;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ProblemDetail;
import org.springframework.http.server.ServerHttpRequest;
import org.springframework.http.server.ServerHttpResponse;
import org.springframework.http.server.ServletServerHttpRequest;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtException;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.WebSocketHandler;
import org.springframework.web.socket.server.HandshakeInterceptor;
import org.springframework.web.util.UriComponentsBuilder;

/**
 * Authenticates the WebSocket upgrade request.
 *
 * <p>{@code /ws} is outside the resource-server filter chain because a browser's WebSocket API
 * cannot set headers and URLSession's support is uneven, so the token is accepted from the
 * {@code Authorization} header (preferred: it stays out of access logs) or a {@code token}
 * query parameter. The very same {@link JwtDecoder} and principal extraction as the REST layer
 * are used, so there is exactly one definition of "a valid token". A rejected handshake answers
 * {@code 401 application/problem+json} like every other unauthenticated request.
 */
@Component
public class JwtHandshakeInterceptor implements HandshakeInterceptor {

    public static final String PRINCIPAL_ATTRIBUTE = "cipher.principal";

    private static final Logger log = LoggerFactory.getLogger(JwtHandshakeInterceptor.class);
    private static final String BEARER_PREFIX = "Bearer ";
    private static final String TOKEN_PARAMETER = "token";

    private final JwtDecoder jwtDecoder;
    private final ProblemDetailFactory problems;
    private final ObjectMapper objectMapper;

    public JwtHandshakeInterceptor(JwtDecoder jwtDecoder, ProblemDetailFactory problems, ObjectMapper objectMapper) {
        this.jwtDecoder = jwtDecoder;
        this.problems = problems;
        this.objectMapper = objectMapper;
    }

    @Override
    public boolean beforeHandshake(ServerHttpRequest request, ServerHttpResponse response, WebSocketHandler wsHandler,
                                   Map<String, Object> attributes) throws IOException {
        String token = extractToken(request);
        if (token == null) {
            return reject(request, response, "A bearer access token is required to open the relay socket");
        }
        try {
            Jwt jwt = jwtDecoder.decode(token);
            AuthenticatedUser user = CurrentUserArgumentResolver.fromJwt(jwt);
            attributes.put(PRINCIPAL_ATTRIBUTE, user);
            return true;
        } catch (JwtException | ProblemException rejected) {
            log.debug("WebSocket handshake rejected: {}", rejected.getMessage());
            return reject(request, response, "The access token is invalid or has expired");
        }
    }

    @Override
    public void afterHandshake(ServerHttpRequest request, ServerHttpResponse response, WebSocketHandler wsHandler,
                               Exception exception) {
        // Nothing to clean up: the principal now lives in the session attributes.
    }

    private static String extractToken(ServerHttpRequest request) {
        String authorization = request.getHeaders().getFirst(HttpHeaders.AUTHORIZATION);
        if (authorization != null && authorization.regionMatches(true, 0, BEARER_PREFIX, 0, BEARER_PREFIX.length())) {
            String value = authorization.substring(BEARER_PREFIX.length()).trim();
            return value.isEmpty() ? null : value;
        }
        String fromQuery = UriComponentsBuilder.fromUri(request.getURI()).build().getQueryParams().getFirst(TOKEN_PARAMETER);
        return fromQuery == null || fromQuery.isBlank() ? null : fromQuery;
    }

    private boolean reject(ServerHttpRequest request, ServerHttpResponse response, String detail) throws IOException {
        HttpServletRequest servletRequest = request instanceof ServletServerHttpRequest servlet
                ? servlet.getServletRequest() : null;
        ProblemDetail problem = problems.create(ProblemType.UNAUTHORIZED, detail, servletRequest);
        response.setStatusCode(HttpStatus.UNAUTHORIZED);
        response.getHeaders().set(HttpHeaders.WWW_AUTHENTICATE, "Bearer");
        response.getHeaders().setContentType(MediaType.APPLICATION_PROBLEM_JSON);
        objectMapper.writeValue(response.getBody(), problem);
        response.flush();
        return false;
    }
}
