# Cipher Protocol — v1

This document is the single shared contract between the iOS client and the relay.
Both sides are built against it. Every request, response, and event carries `"v": 1`
where a version field is meaningful; breaking changes bump the version.

The relay is a **blind relay**: it authenticates users, stores public keys, and routes
opaque ciphertext. It never receives a decryption key, plaintext, filename, or MIME type.

Conventions

- All timestamps are **Unix epoch milliseconds** (`int64`). This avoids ISO-8601 formatting
  ambiguity and lets the `timestamp` field round-trip byte-for-byte into the AEAD's
  associated data.
- IDs are UUIDs (lowercase, hyphenated). Message IDs are **client-generated** so the client
  can reconcile optimistic UI with the server acknowledgement and so retries are idempotent.
- Binary fields (`identityKey`, `signingKey`, `ciphertext`, `signature`) are **standard
  base64** with padding.
- Errors are [RFC 7807](https://www.rfc-editor.org/rfc/rfc7807) `application/problem+json`
  with `type` = `urn:cipher:problem:<slug>` and a `correlationId` extension. Every response
  also carries an `X-Correlation-Id` header (echoed if supplied, generated otherwise).
- Authentication is a Bearer JWT (HS256) in the `Authorization` header. Access tokens live
  15 minutes; refresh tokens 30 days and rotate on every use.

---

## 1. REST

Base path: `/api/v1`. Swagger UI is served at `/swagger-ui.html`.

### 1.1 Auth — `/api/v1/auth/*`

Rate limit: 10 requests / minute / IP → `429` with `Retry-After`.

| Method | Path | Auth | Success |
|---|---|---|---|
| POST | `/auth/register` | none | 201 `AuthResponse` |
| POST | `/auth/login` | none | 200 `AuthResponse` |
| POST | `/auth/refresh` | none | 200 `AuthResponse` |
| POST | `/auth/logout` | none | 204 |

**Register request**

```json
{ "username": "alice", "password": "cipher-alice", "displayName": "Alice" }
```

Validation: `username` 3–32 chars, `^[a-z0-9_]+$`; `password` 8–128 chars; `displayName`
optional, 1–64 chars (defaults to username).

**AuthResponse**

```json
{
  "user": { "id": "5f3a7c1e-8b2d-4e6f-9a0b-1c2d3e4f5a6b", "username": "alice", "displayName": "Alice" },
  "accessToken": "eyJhbGciOiJIUzI1NiJ9...",
  "refreshToken": "c3VwZXItcmFuZG9tLXJlZnJlc2gtdG9rZW4...",
  "accessTokenExpiresIn": 900
}
```

**Login request** `{ "username": "alice", "password": "cipher-alice" }` → 200 `AuthResponse`,
or `401 urn:cipher:problem:invalid-credentials`.

**Refresh request** `{ "refreshToken": "…" }` → 200 `AuthResponse` with a *new* refresh token.
The old token is revoked. `401 urn:cipher:problem:invalid-refresh-token` if unknown, expired
or already used.

**Logout request** `{ "refreshToken": "…" }` → 204 (idempotent).

Errors: `409 urn:cipher:problem:username-taken`, `400 urn:cipher:problem:validation`.

JWT claims: `sub` = user id, `username`, `iat`, `exp`, `iss` = `cipher-relay`.

### 1.2 Key directory — `/api/v1/keys/*`

Public identity keys only. The relay stores exactly what the client uploads.

| Method | Path | Auth | Success |
|---|---|---|---|
| PUT | `/keys/me` | Bearer | 201 `KeyBundle` (first upload) · 200 if identical re-upload |
| POST | `/keys/me/rotate` | Bearer | 200 `KeyBundle` (version + 1, emits `key.changed`) |
| GET | `/keys/me` | Bearer | 200 `KeyBundle` |
| GET | `/keys/{userId}` | Bearer | 200 `KeyBundle` |
| GET | `/keys/lookup?username=bob` | Bearer | 200 `KeyBundle` |

**Upload / rotate request**

```json
{
  "identityKey": "kQ2Zl0Y4wq7c8r6bE1dH0yF2tG9pL3nM4oP5qR6sT7U=",
  "signingKey":  "aB3cD4eF5gH6iJ7kL8mN9oP0qR1sT2uV3wX4yZ5aB6c="
}
```

`identityKey` is a raw 32-byte X25519 public key; `signingKey` a raw 32-byte Ed25519 public key.

**KeyBundle**

```json
{
  "userId": "5f3a7c1e-8b2d-4e6f-9a0b-1c2d3e4f5a6b",
  "username": "bob",
  "displayName": "Bob",
  "identityKey": "kQ2Zl0Y4wq7c8r6bE1dH0yF2tG9pL3nM4oP5qR6sT7U=",
  "signingKey":  "aB3cD4eF5gH6iJ7kL8mN9oP0qR1sT2uV3wX4yZ5aB6c=",
  "version": 1,
  "createdAt": 1758708000000
}
```

Errors: `409 urn:cipher:problem:keys-already-registered` (PUT when different keys already
exist — silent overwrite is refused; use `/rotate`), `404 urn:cipher:problem:user-not-found`,
`404 urn:cipher:problem:keys-not-registered`.

### 1.3 Conversations & messages — `/api/v1/conversations/*`

| Method | Path | Auth | Success |
|---|---|---|---|
| POST | `/conversations` | Bearer | 201 `Conversation` (created) · 200 (already existed) |
| GET | `/conversations` | Bearer | 200 `Conversation[]` |
| POST | `/conversations/{id}/messages` | Bearer | 201 `MessageAck` · 200 (duplicate id, no-op) |
| GET | `/conversations/{id}/messages?before=&limit=` | Bearer | 200 `MessagePage` |

Rate limit on sending: 60 messages / minute / user.

**Create request** `{ "participantId": "9d4e…" }`. Conversations are 1:1 and deterministic:
the same pair of users always resolves to the same conversation. Creating a conversation
with yourself → `400 urn:cipher:problem:validation`.

**Conversation**

```json
{
  "id": "0c9f2b7e-1a2b-4c3d-8e9f-0a1b2c3d4e5f",
  "participants": [
    { "userId": "5f3a…", "username": "alice", "displayName": "Alice" },
    { "userId": "9d4e…", "username": "bob",   "displayName": "Bob" }
  ],
  "createdAt": 1758708000000,
  "lastMessageAt": 1758708123456
}
```

**Envelope** (send request body). Everything about *content* is inside `ciphertext`.

```json
{
  "v": 1,
  "id": "6f1c0a2e-3b4d-4c5e-9f6a-7b8c9d0e1f2a",
  "conversationId": "0c9f2b7e-1a2b-4c3d-8e9f-0a1b2c3d4e5f",
  "senderId": "5f3a7c1e-8b2d-4e6f-9a0b-1c2d3e4f5a6b",
  "recipientId": "9d4e5f6a-7b8c-4d9e-0f1a-2b3c4d5e6f7a",
  "counter": 42,
  "timestamp": 1758708123456,
  "ciphertext": "Zm9vYmFy…",
  "signature": "c2lnbmF0dXJl…",
  "expiresAt": null
}
```

Server-side validation: `v` may be omitted and must be `1` when present; `senderId` must equal
the authenticated user; `conversationId` must equal the path id; `recipientId` must be the other
participant; `counter ≥ 0`; `ciphertext` ≤ 256 KiB decoded; `signature` exactly 64 bytes decoded;
`expiresAt` null or in the future. A duplicate `id` is only a no-op when the stored envelope has
the same sender and conversation; otherwise `400 urn:cipher:problem:validation`.
`expiresAt` is the **only** content-related field the relay can see; it exists so the relay
can purge disappearing messages. `unlockAt`, `viewOnce`, `whisper` live inside the ciphertext.

**MessageAck**

```json
{ "id": "6f1c0a2e-…", "status": "SENT", "createdAt": 1758708123500 }
```

`status` ∈ `SENT | DELIVERED | READ`. A duplicate `id` returns the *stored* status with 200.

**MessagePage** — `limit` default 50, max 200; `before` excludes messages with
`createdAt ≥ before`. Items are ordered **newest first**.

```json
{
  "items": [ { "…Envelope fields…", "status": "READ", "createdAt": 1758708123500, "deliveredAt": 1758708124000, "readAt": 1758708130000 } ],
  "hasMore": false
}
```

The item shape (`Envelope` + `status`, `createdAt`, `deliveredAt?`, `readAt?`) is called
**StoredEnvelope** and is the same object pushed in `message.new`.

Errors: `403 urn:cipher:problem:not-a-participant`, `404 urn:cipher:problem:conversation-not-found`,
`413 urn:cipher:problem:payload-too-large`, `429 urn:cipher:problem:rate-limited`.

### 1.4 Attachments — `/api/v1/attachments/*`

| Method | Path | Auth | Success |
|---|---|---|---|
| POST | `/attachments` (multipart/form-data) | Bearer | 201 `BlobDescriptor` |
| GET | `/attachments/{blobId}` | Bearer | 200 `application/octet-stream` |

Rate limit on upload: 20 / minute / user. Size limit 25 MiB → `413`.

Multipart parts: `file` (the encrypted bytes; the relay also accepts the part name `blob`, with or
without a filename), `conversationId` (UUID), `expiresAt` (optional, epoch ms, must be in the
future). The client sends the bytes part as `application/octet-stream` with the fixed filename
`blob`; the relay ignores any filename or content type and stores bytes only.

**BlobDescriptor**

```json
{ "blobId": "3e2d1c0b-…", "size": 184320, "createdAt": 1758708200000, "expiresAt": null }
```

Download is allowed only for participants of the conversation the blob was uploaded to:
`403 urn:cipher:problem:not-a-participant`, `404 urn:cipher:problem:blob-not-found`.

---

## 2. WebSocket

Endpoint: `GET /ws`. Authenticate with `Authorization: Bearer <accessToken>` (preferred; keeps
tokens out of access logs) or `?token=<accessToken>` for tools that cannot set headers.
A missing, invalid or expired token is rejected **before the upgrade** with
`401 application/problem+json` (`urn:cipher:problem:unauthorized`); a session that somehow reaches
the handler without a principal is closed with code **4001**. Clients treat both as "token
rejected": refresh, then reconnect. Inbound frames are budgeted at 240 per minute per user;
exceeding it answers an `error` frame with code `rate_limited` and closes with **4008**. Sessions
idle for 90 s are closed with **1001**.

Every frame is a JSON text message:

```json
{ "v": 1, "type": "message.new", "payload": { } }
```

On connect the relay (1) marks the user online and broadcasts `presence.update` to their
contacts (for the user's first open socket only; further sockets of the same user do not
re-announce, and `online: false` is sent when the last one closes), then (2) pushes every
envelope addressed to the user that has not been acknowledged and has not expired, oldest first,
as `message.new`.

Heartbeat: the client sends `ping` every 25 s; the relay answers `pong` and closes sessions
idle for 90 s.

### 2.1 Server → client

| type | payload |
|---|---|
| `message.new` | `StoredEnvelope` |
| `receipt.delivered` | `{ "conversationId", "messageIds": [uuid], "byUserId", "at" }` |
| `receipt.read` | `{ "conversationId", "messageIds": [uuid], "byUserId", "at" }` |
| `typing.start` | `{ "conversationId", "userId" }` |
| `typing.stop` | `{ "conversationId", "userId" }` |
| `presence.update` | `{ "userId", "online": true, "lastSeenAt": 1758708000000 }` |
| `key.changed` | `{ "userId", "version": 2, "identityKey", "signingKey", "changedAt" }` |
| `error` | `{ "code": "unknown_event", "message": "…", "correlationId": "…" }` |
| `pong` | `{}` |

Example:

```json
{ "v": 1, "type": "receipt.read",
  "payload": { "conversationId": "0c9f…", "messageIds": ["6f1c…", "7a2d…"], "byUserId": "9d4e…", "at": 1758708130000 } }
```

### 2.2 Client → server

| type | payload | effect |
|---|---|---|
| `message.ack` | `{ "messageIds": [uuid] }` (1–500 ids) | Recipient confirms it received the push. Relay marks `DELIVERED` (only for ids addressed to the caller that are still `SENT`) and relays `receipt.delivered` to the sender, one receipt per conversation. Unacked envelopes are re-pushed on the next connect. |
| `receipt.read` | `{ "conversationId", "messageIds": [uuid] }` (1–500 ids) | Relay marks `READ` (only ids of that conversation addressed to the caller), relays `receipt.read` to the sender. `403 not-a-participant` semantics apply as an `error` frame with code `forbidden`. |
| `typing.start` | `{ "conversationId" }` | Relayed (with `userId`) to the other participant. Ephemeral; never stored. |
| `typing.stop` | `{ "conversationId" }` | As above. |
| `ping` | `{}` | Relay answers `pong`. |

Error codes on `error` frames: `unknown_event`, `invalid_payload`, `forbidden`, `rate_limited`.

---

## 3. What lives inside the ciphertext

Encrypted payload, versioned. Decoded by the recipient only.

```json
{
  "v": 1,
  "type": "text",
  "body": "Meet at 7?",
  "replyToId": null,
  "flags": { "viewOnce": false, "whisper": false, "disappearAfter": null, "unlockAt": null },
  "attachment": null,
  "reaction": null,
  "system": null
}
```

- `type` ∈ `text | attachment | reaction | reply | system`
- `flags.disappearAfter` — seconds after *read* until both clients delete the message.
- `flags.unlockAt` — Time Capsule: recipient keeps the message sealed until this instant.
  Enforced client-side only (the relay cannot see it).
- `attachment`: `{ "blobId", "key" (base64, 32 bytes), "sha256" (hex over the encrypted blob),
  "mimeType", "filename", "size", "width", "height", "thumbnail" (base64 JPEG ≤ 24 KiB) }`.
  The blob is `ChaChaPoly.seal(fileBytes, key)` in combined form (`nonce ‖ ciphertext ‖ tag`).
- `reaction`: `{ "targetId", "emoji", "remove": false }`
- `system`: `{ "kind": "screenshot_taken | view_once_opened | disappearing_changed | key_verified", "refId" }`

---

## 4. Envelope cryptography (client only)

Primitives are Apple CryptoKit; nothing is home-grown.

```
root      = HKDF-SHA256(ikm = X25519(myIdentityPriv, theirIdentityPub),
                        salt = utf8(conversationId),
                        info = utf8("cipher/v1/root"), 32 bytes)
msgKey    = HKDF-SHA256(ikm = root,
                        salt = bigEndian64(counter),
                        info = utf8("cipher/v1/msg|" + senderId), 32 bytes)
aad       = utf8("cipher/v1|" + senderId + "|" + conversationId + "|" + recipientId
                 + "|" + counter + "|" + timestampMillis)
ciphertext = ChaChaPoly.seal(payloadJSON, key: msgKey, aad: aad).combined
signature  = Ed25519.sign(aad ‖ ciphertext, mySigningPriv)
```

Receiving: verify `signature` with the sender's **pinned** signing key → reject duplicates of
`(senderId, conversationId, counter)` → derive `msgKey` → `ChaChaPoly.open` with the same
`aad`. Any failure marks the message as tampered and shows a warning; nothing is decrypted.

Each sender keeps their own monotonically increasing `counter` per conversation; including
`senderId` in the HKDF info makes the two directions of a conversation use disjoint keys.

Safety fingerprint: `SHA-256( sorted([ikA ‖ skA, ikB ‖ skB]) joined )`, first 8 bytes, each
mapped onto a curated table of 256 visually distinct emoji. QR payload:
`cipher:verify?v=1&uid=<userId>&ik=<base64url>&sk=<base64url>`.

---

## 5. Problem types

| type | HTTP |
|---|---|
| `urn:cipher:problem:validation` | 400 |
| `urn:cipher:problem:invalid-credentials` | 401 |
| `urn:cipher:problem:invalid-refresh-token` | 401 |
| `urn:cipher:problem:unauthorized` | 401 |
| `urn:cipher:problem:forbidden` | 403 (generic access denial from the security layer) |
| `urn:cipher:problem:not-a-participant` | 403 |
| `urn:cipher:problem:user-not-found` | 404 |
| `urn:cipher:problem:keys-not-registered` | 404 |
| `urn:cipher:problem:conversation-not-found` | 404 |
| `urn:cipher:problem:blob-not-found` | 404 |
| `urn:cipher:problem:username-taken` | 409 |
| `urn:cipher:problem:keys-already-registered` | 409 |
| `urn:cipher:problem:payload-too-large` | 413 |
| `urn:cipher:problem:rate-limited` | 429 |
| `urn:cipher:problem:internal` | 500 |

Example:

```json
{
  "type": "urn:cipher:problem:keys-already-registered",
  "title": "Keys already registered",
  "status": 409,
  "detail": "Identity keys exist for this user. Use POST /api/v1/keys/me/rotate to rotate explicitly.",
  "instance": "/api/v1/keys/me",
  "correlationId": "8e1f2a3b-…"
}
```
