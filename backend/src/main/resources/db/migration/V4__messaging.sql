-- Conversations and stored ciphertext envelopes.
--
-- A conversation is a 1:1 pair. The pair is stored canonically sorted (participant_a < participant_b
-- as UUID string comparison) and its id is derived deterministically from the pair
-- (UUID.nameUUIDFromBytes("cipher/conv/" + a + "|" + b)), so the same two users always resolve
-- to the same row without a lookup-then-insert race.
--
-- Envelopes are opaque: ciphertext and signature are stored byte-for-byte and never inspected.
-- expires_at is the only content-related field the relay may see; it exists so disappearing
-- messages can be purged server-side.

ALTER TABLE users ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ NULL;

CREATE TABLE conversations (
    id              UUID        PRIMARY KEY,
    participant_a   UUID        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    participant_b   UUID        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    created_at      TIMESTAMPTZ NOT NULL,
    last_message_at TIMESTAMPTZ NULL,
    CONSTRAINT uk_conversations_participants UNIQUE (participant_a, participant_b),
    CONSTRAINT ck_conversations_distinct_participants CHECK (participant_a <> participant_b)
);

CREATE INDEX ix_conversations_participant_a ON conversations (participant_a);
CREATE INDEX ix_conversations_participant_b ON conversations (participant_b);

CREATE TABLE envelopes (
    id               UUID        PRIMARY KEY,
    conversation_id  UUID        NOT NULL REFERENCES conversations (id) ON DELETE CASCADE,
    sender_id        UUID        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    recipient_id     UUID        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    counter          BIGINT      NOT NULL,
    client_timestamp BIGINT      NOT NULL,
    ciphertext       BYTEA       NOT NULL,
    signature        BYTEA       NOT NULL,
    expires_at       TIMESTAMPTZ NULL,
    status           VARCHAR(16) NOT NULL,
    created_at       TIMESTAMPTZ NOT NULL,
    delivered_at     TIMESTAMPTZ NULL,
    read_at          TIMESTAMPTZ NULL,
    CONSTRAINT ck_envelopes_counter_non_negative CHECK (counter >= 0),
    CONSTRAINT ck_envelopes_ciphertext_size CHECK (octet_length(ciphertext) <= 262144),
    CONSTRAINT ck_envelopes_signature_length CHECK (octet_length(signature) = 64),
    CONSTRAINT ck_envelopes_status CHECK (status IN ('SENT', 'DELIVERED', 'READ'))
);

CREATE INDEX ix_envelopes_conversation_created ON envelopes (conversation_id, created_at DESC);
CREATE INDEX ix_envelopes_recipient_status ON envelopes (recipient_id, status);
CREATE INDEX ix_envelopes_expires_at ON envelopes (expires_at) WHERE expires_at IS NOT NULL;
