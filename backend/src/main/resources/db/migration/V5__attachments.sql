-- Encrypted attachment blobs.
--
-- The relay stores only the encrypted bytes (on disk, addressed by storage_key) and the
-- bookkeeping needed to authorise downloads and purge expired blobs. Filename and MIME type
-- never reach this table: they travel inside the message ciphertext.

CREATE TABLE blobs (
    id              UUID         PRIMARY KEY,
    conversation_id UUID         NOT NULL REFERENCES conversations (id) ON DELETE CASCADE,
    uploader_id     UUID         NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    size            BIGINT       NOT NULL,
    storage_key     VARCHAR(255) NOT NULL,
    expires_at      TIMESTAMPTZ  NULL,
    created_at      TIMESTAMPTZ  NOT NULL,
    CONSTRAINT uk_blobs_storage_key UNIQUE (storage_key),
    CONSTRAINT ck_blobs_size_non_negative CHECK (size >= 0)
);

CREATE INDEX ix_blobs_conversation_id ON blobs (conversation_id);
CREATE INDEX ix_blobs_expires_at ON blobs (expires_at) WHERE expires_at IS NOT NULL;
