# Cipher relay (backend)

The blind relay behind the Cipher messenger: it authenticates users, stores public keys, routes
opaque ciphertext envelopes and encrypted blobs, and pushes real-time events over a WebSocket.
It never receives a decryption key, plaintext, filename or MIME type. The wire contract lives in
[`../docs/PROTOCOL.md`](../docs/PROTOCOL.md) and is authoritative; this document covers how the
code is organised and how to run it.

Stack: Java 21, Spring Boot 3.5, Spring Security (HS256 resource server), Spring Data JPA,
Flyway, PostgreSQL 16, raw Spring WebSocket (no STOMP), springdoc-openapi. No Lombok.

## Layout: hexagonal, package by feature

Every feature under `com.cipher.<feature>` follows the same shape. Dependencies point inwards:
adapters depend on the application layer, the application layer depends on the domain, and the
domain depends on nothing but `shared/domain`.

```
com.cipher.<feature>
├── domain/                 plain records and small classes; no Spring
├── application/            use-case services (@Service, constructor injection)
│   └── port/in/            one interface per use case, plus command/result records
│   └── port/out/           what the feature needs from the outside (repositories, notifiers)
└── adapter/
    ├── in/web/             @RestController + request/response records (thin: DTO → command → use case → DTO)
    ├── in/websocket/       WebSocket handler, handshake auth, per-event FrameHandler strategies
    ├── in/scheduling/      @Scheduled drivers for purge use cases
    └── out/persistence/    JPA entities (separate from the domain), Spring Data repositories, adapters
        out/push/           WebSocket implementations of notifier ports
        out/storage/        blob storage implementations
```

| Feature | Responsibility | Notable pieces |
|---|---|---|
| `auth` | Registration, login, rotating refresh tokens, logout, demo seed | `AuthService`, `DemoSeeder` (dev profile only) |
| `keys` | Public identity key directory with explicit rotation | `KeyDirectoryService`, `WebSocketKeyChangeNotifier` (`key.changed`) |
| `messaging` | Conversations, envelopes, receipts, the `/ws` endpoint | `ConversationService`, `EnvelopeService`, `ReceiptService`, `RelayWebSocketHandler` + `FrameHandler`s, `JwtHandshakeInterceptor`, `IdleSessionSweeper` |
| `presence` | Online/offline fan-out, `last_seen_at`, typing relay | `PresenceService`, `TypingService` |
| `attachments` | Encrypted blob upload/download/expiry | `AttachmentService`, `BlobStorage` port, `FileSystemBlobStorage` |
| `shared` | Security, RFC 7807 problems, rate limiting, clock, WebSocket plumbing | `SecurityConfig`, `GlobalExceptionHandler`, `TokenBucketRateLimiter`, `SessionRegistry`, `FrameCodec` |

Cross-feature needs are expressed as ports owned by the consumer and implemented by the owner
of the data. For example `keys` and `presence` each declare a "who are this user's contacts"
port; `messaging` implements both in one adapter (`ConversationContactDirectory`) as "the other
members of the user's conversations". `attachments` and `presence` ask about conversation
membership the same way (`ConversationMembershipAdapter`). No feature imports another feature's
domain model.

### Errors

Every expected failure is a `ProblemException(ProblemType, detail)`; `GlobalExceptionHandler`
renders it as `application/problem+json` with `type = urn:cipher:problem:<slug>`, `status`,
`detail`, `instance` and a `correlationId` (also echoed in the `X-Correlation-Id` header).
Unexpected exceptions become an opaque `internal` problem; stack traces never reach a client.

### Logging

SLF4J with the correlation id in MDC. Ids, sizes, versions and counts are logged; ciphertext,
signatures, tokens, password hashes and key bytes never are.

## Database

Flyway migrations in `src/main/resources/db/migration`, applied on start-up
(`spring.jpa.hibernate.ddl-auto=validate` catches drift between entities and schema):

| Version | Contents |
|---|---|
| V1 | baseline (`pgcrypto`) |
| V2 | `users`, `refresh_tokens` |
| V3 | `identity_keys` |
| V4 | `conversations` (canonical sorted participant pair, deterministic id), `envelopes` (+ status/receipt columns and indexes) |
| V5 | `blobs` |

Conversation ids are `UUID.nameUUIDFromBytes("cipher/conv/" + a + "|" + b)` with `a < b` as
UUID strings, so the same pair of users always maps to the same row and the client can compute
the id offline.

## Running

Prerequisites: JDK 21, Maven 3.9, Docker.

Everything with one command from the repository root (PostgreSQL + relay, dev profile):

```sh
docker compose up -d --build        # or: make up
curl http://localhost:8080/actuator/health
```

Relay only, against a local PostgreSQL:

```sh
docker compose up -d postgres                                   # from the repository root
cd backend
mvn -B -ntp -DskipTests package
SPRING_PROFILES_ACTIVE=dev JWT_SECRET='<at least 32 bytes>' java -jar target/cipher-relay-*.jar
```

Swagger UI: `http://localhost:8080/swagger-ui.html`. Health: `/actuator/health`.

### Profiles

| Profile | Purpose | Behaviour |
|---|---|---|
| `dev` | Local development | Seeds `alice` / `cipher-alice`, `bob` / `cipher-bob`, `echo` / `cipher-echo`; `com.cipher` logs at DEBUG; falls back to a built-in `JWT_SECRET` if none is set |
| `test` | Automated tests | Testcontainers PostgreSQL, fixed test secret, seed disabled |
| `prod` | Deployment | Everything from the environment; no defaults for `DATABASE_URL`, `DATABASE_USERNAME`, `DATABASE_PASSWORD`, `JWT_SECRET`; the relay refuses to start with a blank or short secret |

### Configuration

| Property | Env | Default | Meaning |
|---|---|---|---|
| `spring.datasource.url` | `DATABASE_URL` | `jdbc:postgresql://localhost:5432/cipher` | PostgreSQL JDBC URL |
| `cipher.jwt.secret` | `JWT_SECRET` | none (required) | HS256 key, at least 32 bytes |
| `cipher.jwt.access-token-ttl` / `refresh-token-ttl` | | `15m` / `30d` | Token lifetimes |
| `cipher.ratelimit.auth` | | 10/min per IP | Auth endpoints |
| `cipher.ratelimit.messages` | | 60/min per user | `POST /conversations/{id}/messages` |
| `cipher.ratelimit.uploads` | | 20/min per user | `POST /attachments` |
| `cipher.ratelimit.frames` | | 240/min per user | Inbound WebSocket frames; exceeding closes with 4008 |
| `cipher.attachments.max-size` | | `25MB` | Blob ceiling (413 above it) |
| `cipher.attachments.storage-path` | `ATTACHMENTS_PATH` | `./data/blobs` | Directory for blob files, created on start-up |
| `cipher.websocket.idle-timeout` | | `90s` | Sessions silent for this long are closed |
| `cipher.websocket.idle-sweep-interval` | | `PT15S` | How often idle sessions are swept (ISO-8601, consumed by `@Scheduled`) |
| `cipher.purge.interval` | | `PT60S` | How often expired envelopes and blobs are deleted (ISO-8601) |

### Tests

```sh
mvn -B -ntp verify        # unit + web-slice + Testcontainers integration tests (Docker required)
```

## WebSocket

`GET /ws` with `Authorization: Bearer <accessToken>` (or `?token=` for tools that cannot set
headers). A bad or missing token fails the handshake with `401 application/problem+json`;
a session that somehow reaches the handler without a principal is closed with `4001`. On
connect the relay marks the user online, broadcasts `presence.update` to their contacts and
replays every unacknowledged envelope as `message.new`, oldest first. Frames are
`{"v":1,"type":"…","payload":{…}}`; the full event table, payload shapes and error codes are in
[`../docs/PROTOCOL.md` section 2](../docs/PROTOCOL.md#2-websocket).

All origins are allowed on the endpoint deliberately: the `Origin` check defends browsers that
attach cookies automatically, and this relay has neither cookies nor a browser client; the only
credential is a bearer token the native app attaches explicitly (see `WebSocketConfig`).

## Attachments

Blobs are stored by `FileSystemBlobStorage` as files named by a freshly generated UUID under
`cipher.attachments.storage-path`; the client's filename and content type are ignored and never
persisted. Uploads stream to a `.part` file and are moved into place atomically. The
`BlobStorage` port (`put`, `open`, `delete`) is the seam for an object store: an S3 or MinIO
adapter (`docker compose --profile minio up` starts a MinIO for that purpose) can replace the
filesystem adapter without touching the use cases.
