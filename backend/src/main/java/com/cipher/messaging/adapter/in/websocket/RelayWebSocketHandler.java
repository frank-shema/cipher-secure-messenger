package com.cipher.messaging.adapter.in.websocket;

import com.cipher.messaging.adapter.wire.StoredEnvelopeDto;
import com.cipher.messaging.application.port.in.PendingForRecipientUseCase;
import com.cipher.messaging.domain.Envelope;
import com.cipher.presence.application.port.in.TrackPresenceUseCase;
import com.cipher.shared.config.CorrelationIdFilter;
import com.cipher.shared.domain.ProblemException;
import com.cipher.shared.domain.ProblemType;
import com.cipher.shared.ratelimit.RateLimitProperties;
import com.cipher.shared.ratelimit.TokenBucketRateLimiter;
import com.cipher.shared.ratelimit.UserRateLimiter;
import com.cipher.shared.security.AuthenticatedUser;
import com.cipher.shared.websocket.Frame;
import com.cipher.shared.websocket.FrameCodec;
import com.cipher.shared.websocket.FrameDecodingException;
import com.cipher.shared.websocket.FrameType;
import com.cipher.shared.websocket.SessionRegistry;
import java.time.Clock;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;

/**
 * The relay's single WebSocket endpoint.
 *
 * <p>The handler owns the session lifecycle (register, presence, replay of pending envelopes,
 * unregister) and the per-frame envelope of concerns (activity tracking, rate limiting,
 * decoding, dispatch, error reporting). Everything event-specific lives in a
 * {@link FrameHandler}. A malformed or unknown frame produces an {@code error} frame rather
 * than a disconnect, because dropping the socket would also drop every pending push for a
 * client whose only fault is a typo; abuse of the frame budget, by contrast, closes with 4008.
 */
@Component
public class RelayWebSocketHandler extends TextWebSocketHandler {

    private static final Logger log = LoggerFactory.getLogger(RelayWebSocketHandler.class);
    private static final String FRAME_KEY_PREFIX = "ws:";

    private final SessionRegistry registry;
    private final FrameCodec codec;
    private final Map<String, FrameHandler> handlers;
    private final TrackPresenceUseCase presence;
    private final PendingForRecipientUseCase pending;
    private final UserRateLimiter frameLimiter;

    public RelayWebSocketHandler(SessionRegistry registry, FrameCodec codec, List<FrameHandler> frameHandlers,
                                 TrackPresenceUseCase presence, PendingForRecipientUseCase pending,
                                 RateLimitProperties rateLimits, Clock clock) {
        this.registry = registry;
        this.codec = codec;
        this.handlers = frameHandlers.stream().collect(Collectors.toUnmodifiableMap(FrameHandler::type, Function.identity()));
        this.presence = presence;
        this.pending = pending;
        this.frameLimiter = new UserRateLimiter(FRAME_KEY_PREFIX, "frames", rateLimits.frames().capacity(),
                rateLimits.frames().refillPerMinute(), clock);
    }

    @Override
    public void afterConnectionEstablished(WebSocketSession session) {
        Object principal = session.getAttributes().get(JwtHandshakeInterceptor.PRINCIPAL_ATTRIBUTE);
        if (!(principal instanceof AuthenticatedUser user)) {
            log.warn("Session {} reached the handler without a principal; closing with 4001", session.getId());
            registry.close(session, RelayCloseStatus.UNAUTHENTICATED);
            return;
        }
        SessionRegistry.Arrival arrival = registry.register(session, user.id());
        if (arrival.firstSession()) {
            presence.connected(user.id());
        }
        List<Envelope> backlog = pending.pendingFor(user.id());
        for (Envelope envelope : backlog) {
            if (!registry.send(arrival.session(), codec.frame(FrameType.MESSAGE_NEW, StoredEnvelopeDto.from(envelope)))) {
                break;
            }
        }
        log.debug("Session {} opened for user {} (sessions={}, replayed={})", session.getId(), user.id(),
                registry.sessionCount(user.id()), backlog.size());
    }

    @Override
    protected void handleTextMessage(WebSocketSession session, TextMessage message) {
        Optional<UUID> owner = registry.userOf(session);
        if (owner.isEmpty()) {
            registry.close(session, RelayCloseStatus.UNAUTHENTICATED);
            return;
        }
        UUID userId = owner.get();
        registry.touch(session);
        String correlationId = UUID.randomUUID().toString();
        MDC.put(CorrelationIdFilter.MDC_KEY, correlationId);
        try {
            TokenBucketRateLimiter.Decision budget = frameLimiter.tryAcquire(userId);
            if (!budget.allowed()) {
                log.info("User {} exceeded the frame budget; closing session {} with 4008", userId, session.getId());
                sendError(session, ErrorPayload.RATE_LIMITED,
                        "Too many frames. Retry after " + budget.retryAfterSeconds() + " seconds.", correlationId);
                registry.close(session, RelayCloseStatus.RATE_LIMITED);
                return;
            }
            Frame frame;
            try {
                frame = codec.decode(message.getPayload());
            } catch (FrameDecodingException malformed) {
                sendError(session, ErrorPayload.INVALID_PAYLOAD, malformed.getMessage(), correlationId);
                return;
            }
            FrameHandler handler = handlers.get(frame.type());
            if (handler == null) {
                sendError(session, ErrorPayload.UNKNOWN_EVENT, "Unknown event type '" + frame.type() + "'", correlationId);
                return;
            }
            dispatch(handler, new FrameContext(userId, session, frame.payload(), correlationId));
        } finally {
            MDC.remove(CorrelationIdFilter.MDC_KEY);
        }
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
        registry.unregister(session).ifPresent(departure -> {
            if (!departure.stillOnline()) {
                presence.disconnected(departure.userId());
            }
            log.debug("Session {} closed for user {} with {} (stillOnline={})", session.getId(), departure.userId(),
                    status.getCode(), departure.stillOnline());
        });
    }

    @Override
    public void handleTransportError(WebSocketSession session, Throwable exception) {
        log.debug("Transport error on session {}: {}", session.getId(), exception.getMessage());
        registry.close(session, CloseStatus.SESSION_NOT_RELIABLE);
    }

    private void dispatch(FrameHandler handler, FrameContext context) {
        try {
            handler.handle(context);
        } catch (FrameDecodingException invalid) {
            sendError(context.session(), ErrorPayload.INVALID_PAYLOAD, invalid.getMessage(), context.correlationId());
        } catch (ProblemException problem) {
            String code = problem.type() == ProblemType.VALIDATION ? ErrorPayload.INVALID_PAYLOAD : ErrorPayload.FORBIDDEN;
            sendError(context.session(), code, problem.detail(), context.correlationId());
        } catch (RuntimeException unexpected) {
            log.error("Unhandled error while processing a {} frame from user {}", handler.type(), context.userId(),
                    unexpected);
            registry.close(context.session(), CloseStatus.SERVER_ERROR);
        }
    }

    private void sendError(WebSocketSession session, String code, String message, String correlationId) {
        registry.send(session, codec.frame(FrameType.ERROR, new ErrorPayload(code, message, correlationId)));
    }
}
