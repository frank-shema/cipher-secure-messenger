package com.cipher.shared.websocket;

/**
 * Raised when an inbound text message is not a well-formed {@link Frame}. The handler answers
 * with an {@code invalid_payload} error frame instead of dropping the connection, because a
 * single malformed frame from a buggy client build should not log the user out.
 */
public class FrameDecodingException extends RuntimeException {

    public FrameDecodingException(String message) {
        super(message);
    }

    public FrameDecodingException(String message, Throwable cause) {
        super(message, cause);
    }
}
