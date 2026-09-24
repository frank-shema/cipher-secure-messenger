package com.cipher.attachments.application.port.in;

import com.cipher.attachments.domain.Blob;

/**
 * Stores an encrypted blob for a conversation the uploader belongs to. Authorisation and the
 * size ceiling are checked before a single byte is written to storage.
 */
public interface UploadBlobUseCase {

    Blob upload(UploadBlobCommand command);
}
