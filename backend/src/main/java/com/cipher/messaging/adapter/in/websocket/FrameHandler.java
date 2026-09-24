package com.cipher.messaging.adapter.in.websocket;

import com.cipher.shared.websocket.FrameDecodingException;

/**
 * One client-to-server event type.
 *
 * <p>The relay handler dispatches on {@code type} to one of these so that adding an event is a
 * new small class rather than another branch in a growing switch. Implementations bind their
 * own payload and signal a malformed one with {@link FrameDecodingException}; authorisation
 * failures surface as {@code ProblemException} from the use cases and become {@code forbidden}.
 */
public interface FrameHandler {

    String type();

    void handle(FrameContext context);
}
