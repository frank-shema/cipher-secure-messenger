package com.cipher.shared.websocket;

/**
 * Event names on the wire, in one place so that a typo cannot silently create a new event.
 */
public final class FrameType {

    public static final String MESSAGE_NEW = "message.new";
    public static final String MESSAGE_ACK = "message.ack";
    public static final String RECEIPT_DELIVERED = "receipt.delivered";
    public static final String RECEIPT_READ = "receipt.read";
    public static final String TYPING_START = "typing.start";
    public static final String TYPING_STOP = "typing.stop";
    public static final String PRESENCE_UPDATE = "presence.update";
    public static final String KEY_CHANGED = "key.changed";
    public static final String ERROR = "error";
    public static final String PING = "ping";
    public static final String PONG = "pong";

    private FrameType() {
    }
}
