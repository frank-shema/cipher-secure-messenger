package com.cipher.attachments.adapter.in.web;

import com.cipher.attachments.domain.Blob;
import io.swagger.v3.oas.annotations.media.Schema;
import java.util.UUID;

@Schema(name = "BlobDescriptor")
public record BlobDescriptorResponse(UUID blobId, long size, long createdAt, Long expiresAt) {

    static BlobDescriptorResponse from(Blob blob) {
        return new BlobDescriptorResponse(blob.id(), blob.size(), blob.createdAt().toEpochMilli(),
                blob.expiresAt() == null ? null : blob.expiresAt().toEpochMilli());
    }
}
