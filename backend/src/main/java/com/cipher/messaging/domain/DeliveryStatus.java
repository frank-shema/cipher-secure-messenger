package com.cipher.messaging.domain;

/**
 * Lifecycle of a stored envelope as seen by the relay. The order matters: a status never moves
 * backwards, and {@code READ} implies {@code DELIVERED} even when the client skipped the ack.
 */
public enum DeliveryStatus {
    SENT,
    DELIVERED,
    READ;

    public boolean isBefore(DeliveryStatus other) {
        return ordinal() < other.ordinal();
    }
}
