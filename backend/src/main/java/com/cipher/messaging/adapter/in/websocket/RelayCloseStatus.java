package com.cipher.messaging.adapter.in.websocket;

import org.springframework.web.socket.CloseStatus;

/**
 * Application close codes from PROTOCOL.md section 2, in the 4000-4999 range reserved for
 * private use so they can never collide with a container-generated code.
 */
final class RelayCloseStatus {

    static final CloseStatus UNAUTHENTICATED = new CloseStatus(4001, "unauthenticated");
    static final CloseStatus RATE_LIMITED = new CloseStatus(4008, "rate limited");
    static final CloseStatus IDLE = new CloseStatus(1001, "idle timeout");

    private RelayCloseStatus() {
    }
}
