package com.cipher.messaging.application.port.in;

/**
 * Deletes envelopes whose {@code expiresAt} has passed. Disappearing messages are enforced by
 * the clients, but the relay must not keep ciphertext beyond the lifetime the sender chose.
 *
 * @return how many rows were removed, for the log line only
 */
public interface PurgeExpiredEnvelopesUseCase {

    int purgeExpired();
}
