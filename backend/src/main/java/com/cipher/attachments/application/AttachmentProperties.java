package com.cipher.attachments.application;

import java.nio.file.Path;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;
import org.springframework.util.unit.DataSize;

/**
 * Attachment limits and storage location bound from {@code cipher.attachments.*}.
 *
 * <p>The 25 MiB ceiling is the protocol's number and is enforced twice: by the servlet
 * multipart limit (which rejects early without reading the body) and again while streaming to
 * storage, in case the two are ever configured apart.
 */
@ConfigurationProperties(prefix = "cipher.attachments")
public record AttachmentProperties(@DefaultValue("25MB") DataSize maxSize,
                                   @DefaultValue("./data/blobs") String storagePath) {

    public AttachmentProperties {
        if (maxSize == null || maxSize.toBytes() < 1) {
            throw new IllegalStateException("cipher.attachments.max-size must be a positive size");
        }
        if (storagePath == null || storagePath.isBlank()) {
            throw new IllegalStateException("cipher.attachments.storage-path must not be blank");
        }
    }

    public long maxBytes() {
        return maxSize.toBytes();
    }

    public Path storageDirectory() {
        return Path.of(storagePath).toAbsolutePath().normalize();
    }
}
