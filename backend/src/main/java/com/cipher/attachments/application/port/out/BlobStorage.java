package com.cipher.attachments.application.port.out;

import java.io.InputStream;
import java.util.Optional;

/**
 * Where encrypted bytes live.
 *
 * <p>The port is deliberately tiny (put, open, delete by opaque key) so the local filesystem
 * adapter can be swapped for an object store such as S3 or MinIO without touching the use
 * cases. Implementations choose the key; callers never influence the storage path.
 */
public interface BlobStorage {

    /**
     * Streams the content into storage, refusing anything larger than {@code maxBytes} with a
     * {@code payload-too-large} problem and leaving nothing behind in that case.
     */
    StoredObject put(InputStream content, long maxBytes);

    Optional<InputStream> open(String storageKey);

    void delete(String storageKey);

    record StoredObject(String storageKey, long size) {
    }
}
