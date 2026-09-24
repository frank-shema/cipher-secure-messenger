package com.cipher.messaging.adapter.in.websocket;

import com.cipher.shared.websocket.WebSocketProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.socket.config.annotation.EnableWebSocket;
import org.springframework.web.socket.config.annotation.WebSocketConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry;
import org.springframework.web.socket.server.standard.ServletServerContainerFactoryBean;

/**
 * Registers the raw (non-STOMP) relay endpoint at {@code /ws}.
 *
 * <p>All origins are allowed on purpose. The {@code Origin} check exists to protect browser
 * users from cross-site WebSocket hijacking, where a malicious page rides on the cookies the
 * browser attaches automatically. This relay has no cookies and no browser client: the only
 * credential is a bearer token the native iOS app attaches explicitly, and a page that does not
 * hold the token cannot open a session no matter what origin it claims. Restricting origins
 * would therefore add no security while breaking developer tooling that sends none.
 */
@Configuration
@EnableWebSocket
public class WebSocketConfig implements WebSocketConfigurer {

    public static final String ENDPOINT = "/ws";

    private final RelayWebSocketHandler handler;
    private final JwtHandshakeInterceptor handshakeInterceptor;
    private final WebSocketProperties properties;

    public WebSocketConfig(RelayWebSocketHandler handler, JwtHandshakeInterceptor handshakeInterceptor,
                           WebSocketProperties properties) {
        this.handler = handler;
        this.handshakeInterceptor = handshakeInterceptor;
        this.properties = properties;
    }

    @Override
    public void registerWebSocketHandlers(WebSocketHandlerRegistry registry) {
        registry.addHandler(handler, ENDPOINT)
                .addInterceptors(handshakeInterceptor)
                .setAllowedOrigins("*");
    }

    /**
     * Caps inbound frame size at the container so a client cannot make the relay buffer more
     * than one legitimate frame's worth of text before the handler even sees it.
     */
    @Bean
    public ServletServerContainerFactoryBean webSocketContainer() {
        ServletServerContainerFactoryBean container = new ServletServerContainerFactoryBean();
        int maxText = (int) properties.maxTextMessageSize().toBytes();
        container.setMaxTextMessageBufferSize(maxText);
        container.setMaxBinaryMessageBufferSize(maxText);
        return container;
    }
}
