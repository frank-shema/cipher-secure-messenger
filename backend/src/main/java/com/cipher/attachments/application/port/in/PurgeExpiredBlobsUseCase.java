package com.cipher.attachments.application.port.in;

/**
 * Removes blobs whose {@code expiresAt} has passed, bytes and row alike.
 *
 * @return how many blobs were removed, for the log line only
 */
public interface PurgeExpiredBlobsUseCase {

    int purgeExpired();
}
