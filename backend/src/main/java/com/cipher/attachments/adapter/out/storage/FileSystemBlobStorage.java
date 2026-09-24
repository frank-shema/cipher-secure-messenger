package com.cipher.attachments.adapter.out.storage;

import com.cipher.attachments.application.AttachmentProperties;
import com.cipher.attachments.application.port.out.BlobStorage;
import com.cipher.shared.domain.ProblemException;
import com.cipher.shared.domain.ProblemType;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.Optional;
import java.util.UUID;
import java.util.regex.Pattern;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

/**
 * Stores blobs as files named by a fresh UUID under {@code cipher.attachments.storage-path}.
 *
 * <p>The key is generated here and never derived from anything the client sent, so a crafted
 * filename cannot escape the directory and the directory listing reveals nothing about the
 * content. Uploads are written to a {@code .part} file and moved into place atomically so a
 * crash mid-upload can never leave a truncated blob that looks complete. The byte cap is
 * enforced while streaming, independent of whatever size the client declared.
 */
@Component
public class FileSystemBlobStorage implements BlobStorage {

    private static final Logger log = LoggerFactory.getLogger(FileSystemBlobStorage.class);
    private static final Pattern KEY_PATTERN = Pattern.compile("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$");
    private static final String PARTIAL_SUFFIX = ".part";
    private static final int BUFFER_SIZE = 64 * 1024;

    private final Path directory;

    public FileSystemBlobStorage(AttachmentProperties properties) {
        this.directory = properties.storageDirectory();
        try {
            Files.createDirectories(directory);
        } catch (IOException cannotCreate) {
            throw new IllegalStateException("Attachment storage directory " + directory + " cannot be created", cannotCreate);
        }
        log.info("Attachment storage ready at {}", directory);
    }

    @Override
    public StoredObject put(InputStream content, long maxBytes) {
        String key = UUID.randomUUID().toString();
        Path partial = directory.resolve(key + PARTIAL_SUFFIX);
        Path finalPath = directory.resolve(key);
        long written = 0;
        try (OutputStream out = Files.newOutputStream(partial)) {
            byte[] buffer = new byte[BUFFER_SIZE];
            int read;
            while ((read = content.read(buffer)) != -1) {
                written += read;
                if (written > maxBytes) {
                    throw new ProblemException(ProblemType.PAYLOAD_TOO_LARGE,
                            "Attachments may not exceed " + maxBytes + " bytes");
                }
                out.write(buffer, 0, read);
            }
        } catch (IOException | RuntimeException failed) {
            deleteQuietly(partial);
            if (failed instanceof IOException io) {
                throw new UncheckedIOException("Writing blob " + key + " failed", io);
            }
            throw (RuntimeException) failed;
        }
        try {
            Files.move(partial, finalPath, StandardCopyOption.ATOMIC_MOVE);
        } catch (IOException moveFailed) {
            deleteQuietly(partial);
            throw new UncheckedIOException("Finalising blob " + key + " failed", moveFailed);
        }
        return new StoredObject(key, written);
    }

    @Override
    public Optional<InputStream> open(String storageKey) {
        Path path = resolve(storageKey);
        if (!Files.isRegularFile(path)) {
            return Optional.empty();
        }
        try {
            return Optional.of(Files.newInputStream(path));
        } catch (IOException openFailed) {
            throw new UncheckedIOException("Opening blob " + storageKey + " failed", openFailed);
        }
    }

    @Override
    public void delete(String storageKey) {
        deleteQuietly(resolve(storageKey));
    }

    private Path resolve(String storageKey) {
        if (storageKey == null || !KEY_PATTERN.matcher(storageKey).matches()) {
            throw new IllegalArgumentException("Storage key is not a blob key");
        }
        return directory.resolve(storageKey);
    }

    private static void deleteQuietly(Path path) {
        try {
            Files.deleteIfExists(path);
        } catch (IOException deleteFailed) {
            log.warn("Deleting {} failed: {}", path.getFileName(), deleteFailed.getMessage());
        }
    }
}
