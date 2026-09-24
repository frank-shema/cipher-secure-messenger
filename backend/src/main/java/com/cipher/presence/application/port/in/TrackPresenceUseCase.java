package com.cipher.presence.application.port.in;

import java.util.UUID;

/**
 * Lifecycle hooks the socket adapter calls when a user's first session opens and last session
 * closes. Presence is derived from sockets rather than declared by the client so it cannot be
 * spoofed and never goes stale when an app is killed.
 */
public interface TrackPresenceUseCase {

    void connected(UUID userId);

    void disconnected(UUID userId);
}
