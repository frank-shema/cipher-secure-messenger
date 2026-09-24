package com.cipher.attachments.application;

import com.cipher.attachments.application.port.in.BlobContent;
import com.cipher.attachments.application.port.in.DownloadBlobUseCase;
import com.cipher.attachments.application.port.in.PurgeExpiredBlobsUseCase;
import com.cipher.attachments.application.port.in.UploadBlobCommand;
import com.cipher.attachments.application.port.in.UploadBlobUseCase;
import com.cipher.attachments.application.port.out.BlobRepository;
import com.cipher.attachments.application.port.out.BlobStorage;
import com.cipher.attachments.application.port.out.ConversationAccess;
import com.cipher.attachments.domain.Blob;
import com.cipher.shared.domain.ProblemException;
import com.cipher.shared.domain.ProblemType;
import java.io.InputStream;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

/**
 * Encrypted attachment lifecycle: upload, authorised download, expiry.
 *
 * <p>The relay treats a blob as bytes plus a conversation. Authorisation is the conversation's
 * membership, checked on every download rather than baked into an unguessable URL, because
 * ids leak (screenshots, logs) and a leaked id must not be a capability. Storage and the
 * bookkeeping row are written in that order and unwound together so a failed insert never
 * leaves an orphaned file behind.
 */
@Service
public class AttachmentService implements UploadBlobUseCase, DownloadBlobUseCase, PurgeExpiredBlobsUseCase {

    private static final Logger log = LoggerFactory.getLogger(AttachmentService.class);

    private final BlobRepository blobs;
    private final BlobStorage storage;
    private final ConversationAccess access;
    private final AttachmentProperties properties;
    private final Clock clock;

    public AttachmentService(BlobRepository blobs, BlobStorage storage, ConversationAccess access,
                             AttachmentProperties properties, Clock clock) {
        this.blobs = blobs;
        this.storage = storage;
        this.access = access;
        this.properties = properties;
        this.clock = clock;
    }

    @Override
    public Blob upload(UploadBlobCommand command) {
        requireAccess(command.conversationId(), command.uploaderId(), ProblemType.CONVERSATION_NOT_FOUND);
        if (command.declaredSize() <= 0) {
            throw new ProblemException(ProblemType.VALIDATION, "The uploaded blob must not be empty");
        }
        if (command.declaredSize() > properties.maxBytes()) {
            throw new ProblemException(ProblemType.PAYLOAD_TOO_LARGE,
                    "Attachments may not exceed " + properties.maxBytes() + " bytes");
        }
        Instant now = clock.instant();
        if (command.expiresAt() != null && !command.expiresAt().isAfter(now)) {
            throw new ProblemException(ProblemType.VALIDATION, "expiresAt must be null or in the future");
        }
        BlobStorage.StoredObject stored = storage.put(command.content(), properties.maxBytes());
        Blob blob = Blob.create(UUID.randomUUID(), command.conversationId(), command.uploaderId(), stored.size(),
                stored.storageKey(), command.expiresAt(), now);
        try {
            Blob saved = blobs.save(blob);
            log.info("Stored blob id={} conversation={} bytes={}", saved.id(), saved.conversationId(), saved.size());
            return saved;
        } catch (RuntimeException persistenceFailed) {
            storage.delete(stored.storageKey());
            throw persistenceFailed;
        }
    }

    @Override
    public BlobContent download(UUID userId, UUID blobId) {
        Blob blob = blobs.findById(blobId)
                .filter(candidate -> !candidate.isExpiredAt(clock.instant()))
                .orElseThrow(AttachmentService::blobNotFound);
        requireAccess(blob.conversationId(), userId, ProblemType.BLOB_NOT_FOUND);
        InputStream stream = storage.open(blob.storageKey()).orElseThrow(() -> {
            log.warn("Blob id={} has a row but no stored bytes", blob.id());
            return blobNotFound();
        });
        return new BlobContent(blob, stream);
    }

    @Override
    public int purgeExpired() {
        List<Blob> expired = blobs.findExpiredBefore(clock.instant());
        for (Blob blob : expired) {
            storage.delete(blob.storageKey());
            blobs.delete(blob.id());
        }
        if (!expired.isEmpty()) {
            log.info("Purged {} expired blobs", expired.size());
        }
        return expired.size();
    }

    private void requireAccess(UUID conversationId, UUID userId, ProblemType whenMissing) {
        switch (access.check(conversationId, userId)) {
            case NOT_FOUND -> throw new ProblemException(whenMissing, whenMissing == ProblemType.BLOB_NOT_FOUND
                    ? "No blob matches the given id" : "No conversation matches the given id");
            case NOT_A_PARTICIPANT -> throw new ProblemException(ProblemType.NOT_A_PARTICIPANT,
                    "You are not a participant of this conversation");
            case ALLOWED -> {
            }
        }
    }

    private static ProblemException blobNotFound() {
        return new ProblemException(ProblemType.BLOB_NOT_FOUND, "No blob matches the given id");
    }
}
