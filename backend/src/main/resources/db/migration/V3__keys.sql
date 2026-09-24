-- Public identity key directory: one bundle per user, versioned on rotation.
-- The relay stores exactly the raw 32-byte X25519 and Ed25519 public keys the client uploads.

CREATE TABLE identity_keys (
    user_id      UUID        PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
    identity_key BYTEA       NOT NULL,
    signing_key  BYTEA       NOT NULL,
    version      INTEGER     NOT NULL DEFAULT 1,
    created_at   TIMESTAMPTZ NOT NULL,
    updated_at   TIMESTAMPTZ NOT NULL,
    CONSTRAINT ck_identity_keys_identity_key_length CHECK (octet_length(identity_key) = 32),
    CONSTRAINT ck_identity_keys_signing_key_length  CHECK (octet_length(signing_key) = 32),
    CONSTRAINT ck_identity_keys_version_positive    CHECK (version >= 1)
);
