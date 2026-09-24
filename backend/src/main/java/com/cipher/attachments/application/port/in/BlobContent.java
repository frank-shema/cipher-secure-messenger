package com.cipher.attachments.application.port.in;

import com.cipher.attachments.domain.Blob;
import java.io.InputStream;

/**
 * A blob ready to stream: its metadata (for {@code Content-Length}) and an open stream the
 * caller must close.
 */
public record BlobContent(Blob blob, InputStream stream) {
}
