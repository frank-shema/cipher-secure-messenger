package com.cipher.attachments.application.port.in;

import java.util.UUID;

/**
 * Opens a blob for a participant of its conversation. Unknown, expired or missing-on-disk
 * blobs are all {@code blob-not-found}; a non-participant gets {@code not-a-participant}.
 */
public interface DownloadBlobUseCase {

    BlobContent download(UUID userId, UUID blobId);
}
