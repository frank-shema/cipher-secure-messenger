# Architecture

A module-by-module tour of both applications, with file pointers. The wire contract they share is
[PROTOCOL.md](PROTOCOL.md); the product-level overview, diagrams and threat model are in the
[README](../README.md). Diagram sources are in [`diagrams/`](diagrams/).

```
cipher-secure-messenger/
├── backend/                      Java 21 · Spring Boot 3.5 · hexagonal, package by feature
│   ├── src/main/java/com/cipher/{auth,keys,messaging,presence,attachments,shared}
│   ├── src/main/resources/{application.yml, db/migration/V1..V5}
│   └── src/test/java/com/cipher   unit · @WebMvcTest slices · Testcontainers integration
├── ios/
│   ├── project.yml               xcodegen source of truth for Cipher.xcodeproj (Info.plist included)
│   ├── Cipher/                   app target: App · Data · Features · Resources
│   ├── CipherTests/
│   └── Packages/                 CipherCore · CipherCrypto · CipherNetworking · CipherPersistence · CipherDesign
├── docs/                         PROTOCOL.md · ARCHITECTURE.md · diagrams/ · screenshots/ · gifs/
├── docker-compose.yml            postgres · backend · (minio profile)
└── Makefile                      up · seed · ios-open · test · lint
```

---

## Backend (`backend/`)

Stack: Java 21 with virtual threads, Spring Boot 3.5, Spring Security as an HS256 resource server,
Spring Data JPA, Flyway, PostgreSQL 16, raw Spring WebSocket (no STOMP), springdoc-openapi. No
Lombok; records for every DTO, command and domain value.

### One feature, one shape

```
com.cipher.<feature>
├── domain/            records and small classes; no Spring imports
├── application/       @Service use cases, constructor injection
│   ├── port/in/       one interface per use case + command/result records
│   └── port/out/      what the feature needs from outside (repositories, notifiers, storage)
└── adapter/
    ├── in/web         @RestController + request/response records
    ├── in/websocket   FrameHandler strategies (messaging only)
    ├── in/scheduling  @Scheduled drivers for purge use cases
    └── out/…          JPA entities + adapters, WebSocket pushers, storage, security
```

Dependencies point inwards. Adapters know the application layer; the application layer knows the
domain; the domain knows only `shared/domain`. JPA entities are never domain objects: each
persistence adapter maps in both directions.

### `auth` — accounts and sessions

| What | Where |
|---|---|
| `POST /auth/register` · `login` · `refresh` · `logout` | `auth/adapter/in/web/AuthController.java`, request records alongside |
| Use cases | `auth/application/AuthService.java` implements `RegisterUserUseCase`, `LoginUseCase`, `RefreshSessionUseCase`, `LogoutUseCase` |
| Refresh token secrets (32 random bytes, SHA-256 hex stored, rotate on use) | `auth/application/RefreshTokenSecrets.java`, `auth/domain/RefreshToken.java` |
| Password hashing | `auth/adapter/out/security/BCryptPasswordHasher.java` |
| JWT issuing (`sub`, `username`, `iss=cipher-relay`, 15 min) | `auth/adapter/out/security/JwtAccessTokenIssuer.java`, `shared/security/JwtIssuer.java`, `JwtProperties.java` (fails fast on a short secret) |
| Persistence | `auth/adapter/out/persistence/{UserEntity, RefreshTokenEntity, *JpaRepository, *PersistenceAdapter}.java` |
| Demo seed (`dev` profile, `cipher.seed.enabled`) | `auth/adapter/in/seed/DemoSeeder.java` |

### `keys` — public key directory

| What | Where |
|---|---|
| `PUT /keys/me` (201 / 200 / 409), `POST /keys/me/rotate`, `GET /keys/me`, `GET /keys/{userId}`, `GET /keys/lookup` | `keys/adapter/in/web/KeyController.java`; base64 undone at the edge in `KeyMaterialDecoder.java` |
| Use cases and the 32-byte invariant | `keys/application/KeyDirectoryService.java`, `keys/domain/KeyBundle.java` |
| "Who are this user's contacts" port (implemented by `messaging`) | `keys/application/port/out/ContactDirectory.java` ← `messaging/adapter/out/contacts/ConversationContactDirectory.java` |
| `key.changed` fan-out | `keys/adapter/out/notify/WebSocketKeyChangeNotifier.java`, payload `KeyChangedDto.java` |

### `messaging` — conversations, envelopes, receipts, the socket

| What | Where |
|---|---|
| `POST /conversations` (deterministic id), `GET /conversations`, `POST /{id}/messages` (201 / 200 duplicate), `GET /{id}/messages?before=&limit=` | `messaging/adapter/in/web/ConversationController.java`, `EnvelopeRequest.java` (shape only; routing rules live in the use case) |
| Conversation id = `nameUUIDFromBytes("cipher/conv/" + a + "\|" + b)` over the sorted pair | `messaging/domain/Conversation.java`, `ConversationService.java` |
| Envelope acceptance: sender = caller, recipient = other participant, sizes, `expiresAt` in the future, store *then* push | `messaging/application/EnvelopeService.java`, `messaging/domain/Envelope.java` |
| Receipts: `message.ack` → `DELIVERED` + `receipt.delivered`; `receipt.read` → `READ` + `receipt.read`; only the recipient's own ids ever change state | `messaging/application/ReceiptService.java` |
| Unacked replay on connect, oldest first | `EnvelopeService.pendingFor`, called from `RelayWebSocketHandler.afterConnectionEstablished` |
| `/ws` endpoint, handshake auth (`Authorization: Bearer` or `?token=`), per-user frame budget → `4008`, error frames instead of disconnects | `messaging/adapter/in/websocket/{WebSocketConfig, JwtHandshakeInterceptor, RelayWebSocketHandler}.java` |
| One handler per client event | `MessageAckFrameHandler`, `ReceiptReadFrameHandler`, `TypingStartFrameHandler`, `TypingStopFrameHandler`, `PingFrameHandler` (all implement `FrameHandler`); payload shapes in `Payloads.java` |
| Close codes `4001` / `4008` / `1001` | `RelayCloseStatus.java`; idle sweep in `IdleSessionSweeper.java` |
| Push adapters | `messaging/adapter/out/push/{WebSocketEnvelopePusher, WebSocketReceiptNotifier}.java` |
| Wire shapes shared by REST and WS (`StoredEnvelope`, receipts) | `messaging/adapter/wire/{StoredEnvelopeDto, ReceiptDto}.java` |
| Expired envelope purge (`cipher.purge.interval`) | `messaging/adapter/in/scheduling/ExpiredEnvelopePurgeJob.java` |

### `presence` — online state and typing

| What | Where |
|---|---|
| First-socket / last-socket transitions → `presence.update` to contacts, `last_seen_at` | `presence/application/PresenceService.java`, `presence/adapter/out/persistence/LastSeenPersistenceAdapter.java` |
| Typing relay with a membership check (so nobody can make "Alice is typing" appear where Alice is not) | `presence/application/TypingService.java`, `presence/adapter/out/push/WebSocketTypingRelay.java` |
| Membership port implemented by `messaging` | `presence/application/port/out/ConversationMembership.java` ← `messaging/adapter/out/contacts/ConversationMembershipAdapter.java` |

### `attachments` — encrypted blobs

| What | Where |
|---|---|
| `POST /attachments` (multipart `file`, 25 MiB, 20/min/user), `GET /attachments/{blobId}` (participants only, `application/octet-stream`, `no-store`) | `attachments/adapter/in/web/AttachmentController.java` |
| Use cases: upload, download, purge; `expiresAt` validation | `attachments/application/AttachmentService.java`, `attachments/domain/Blob.java` |
| `BlobStorage` port and the filesystem adapter (UUID-named files, `.part` then atomic move; never the client's name or type) | `attachments/application/port/out/BlobStorage.java`, `attachments/adapter/out/storage/FileSystemBlobStorage.java` |
| Expired blob purge | `attachments/adapter/in/scheduling/ExpiredBlobPurgeJob.java` |

### `shared`

| What | Where |
|---|---|
| Stateless security chain, permit list, problem+json entry point and access-denied handler | `shared/security/SecurityConfig.java`, `ProblemAuthenticationEntryPoint.java`, `ProblemAccessDeniedHandler.java` |
| `@CurrentUser AuthenticatedUser` argument resolver | `shared/security/{CurrentUser, AuthenticatedUser, CurrentUserArgumentResolver}.java` |
| RFC 7807: `ProblemType` catalogue, `ProblemException`, global handler, response writer | `shared/domain/{ProblemType, ProblemException}.java`, `shared/web/{GlobalExceptionHandler, ProblemDetailFactory, ProblemResponseWriter}.java` |
| Correlation ids (`X-Correlation-Id` header, MDC) | `shared/config/CorrelationIdFilter.java` |
| Token buckets: auth 10/min/IP (filter before security), messages 60, uploads 20, frames 240 per user | `shared/ratelimit/{TokenBucketRateLimiter, RateLimitFilter, UserRateLimiter, RateLimitProperties}.java` |
| WebSocket plumbing: frame record, codec, session registry with concurrent send decorators | `shared/websocket/{Frame, FrameType, FrameCodec, SessionRegistry, WebSocketProperties}.java` |
| Injected `Clock` (never `Instant.now()` in features) | `shared/time/ClockConfig.java` |
| OpenAPI bearer scheme | `shared/config/OpenApiConfig.java` |

### Configuration and schema

`src/main/resources/application.yml` holds the defaults and the `dev` / `test` / `prod` profiles
(`prod` has no defaults for the datasource or `JWT_SECRET`). Flyway migrations:
`V1__baseline.sql` (pgcrypto), `V2__auth.sql`, `V3__keys.sql`, `V4__messaging.sql`,
`V5__attachments.sql`. Hibernate runs with `ddl-auto=validate` so an entity that drifts from the
schema fails at start-up.

### Tests (`src/test/java/com/cipher`)

Unit tests next to what they test (`auth/application/AuthServiceTest`, `keys/application/KeyDirectoryServiceTest`,
`shared/ratelimit/TokenBucketRateLimiterTest`, …), `@WebMvcTest` slices with `support/WebSliceConfig`
(`AuthControllerTest`, `KeyControllerTest`, `RateLimitFilterTest`), and `@SpringBootTest` +
Testcontainers integration tests at the root (`AuthAndKeysFlowIntegrationTest`,
`AuthRateLimitIntegrationTest`, `CipherRelayApplicationTests`). `support/MutableClock` and
`support/TestKeys` are the shared fixtures. Messaging, presence, WebSocket and attachment suites
are the next hardening step.

---

## iOS (`ios/`)

Swift 6 language mode with strict concurrency everywhere, iOS 17 deployment target, SwiftUI with
the Observation framework, and no third-party dependencies. The project file is generated:
`ios/project.yml` is the source of truth (targets, packages, `Info.plist` keys, entitlements), and
`make ios-generate` runs `xcodegen`.

### `Packages/CipherCore` — the domain (Foundation only)

| Folder | Contents |
|---|---|
| `Identifiers/` | `Identifier<Tag>` with `UserID`, `ConversationID`, `MessageID`, `BlobID` |
| `Entities/` | `User`, `PublicKeyBundle`, `Contact`, `TrustState` (`unverified / verified(at:) / keyChanged(previousVersion:at:)`), `Presence`, `Conversation`, `Message`, `MessageContent` (`text / attachment / reaction / system / tampered(TamperReason)`), `MessageFlags` (`viewOnce`, `whisper`, `disappearAfter`, `unlockAt`), `MessageStatus` with `shouldAdvance(to:)` (receipts never downgrade), `Attachment`, `Reaction`, `SystemEvent` |
| `Wire/` | `Envelope` and `StoredEnvelope` with hand-written `Codable` for the exact PROTOCOL keys, `EnvelopeHeader`, `AssociatedData.canonical(...)` (the AAD string, shared with the crypto engine and tests), `WireJSON` (sorted keys, no escaped slashes) |
| `Payload/` | `MessagePayload` (the JSON inside the ciphertext, explicit `null`s, `validate()` checks type/field consistency), `MessagePayloadCodec` |
| `Ports/` | `AuthGateway`, `SessionStore`, `KeyDirectoryGateway`, `ConversationGateway`, `RealtimeGateway` (+ `ServerEvent`, `ClientEvent`, `ConnectionState`), `IdentityKeyStore` (public halves only), `MessageCryptoService`, `ReplayGuard`, `MessageRepository`, `ConversationRepository`, `ContactRepository`, `OutboxRepository`, `Clock`, `UUIDGenerator` |
| `UseCases/` | `StartConversationUseCase` (lookup → create/get → pin keys), `SendMessageUseCase` (optimistic row → seal → outbox → send; `retry` reuses the same id/counter), `ReceiveEnvelopeUseCase` (resolve/pin peer → replay check → open → persist; failures become `tampered` rows), `SyncConversationUseCase` (newest-first paging until known ids; own history decrypted), `HandleRealtimeEventUseCase` (routes every server event; acks after persist), `FlushOutboxUseCase` (oldest first, stops at the first transient failure), `MarkConversationReadUseCase`, `VerifyContactUseCase`, `ObserveUseCases`, `AckReconciler`, `ContactPinning`, `ReactionApplier`, `CipherCoreError` |
| `Attachments/` | `SendAttachmentUseCase` (placeholder row → seal → upload → send with the same id; in-memory `PendingAttachmentSends` for retry), `FetchAttachmentUseCase` (download → digest check → decrypt), `AttachmentDraft`, `AttachmentLimits`, `AttachmentBlobGateway`, `BlobHashing`, transfer phases |
| `Policies/` | `DisappearingTimer` presets, `TimeCapsuleState`, `MessageVisibilityPolicy` (expired → sealed capsule → view-once → whisper → revealed), `SafetyNumberFormatter` |
| `Security/SensitiveContent/` | `SensitiveContentDetector` with `IBANScanner` (mod-97), `CardNumberScanner` (Luhn), `PasswordScanner` (keywords + entropy), `OneTimeCodeScanner`; `DetectSensitiveContentUseCase` hops off the main actor |
| `Security/Trust/` | `TrustSignals`, `TrustEvaluator` (weighted, explainable), `TrustReport` / `TrustReason` / `TrustAction`, `EvaluateTrustUseCase`, `PrivacyPreferencesReader` |
| `Security/Duress/` | `AppLockMode`, `PINVerifier` + `PINRules` (constant-time compare, predictable-PIN rejection) + `PINAttemptPolicy`, `DecoyInboxGenerator` + `DecoyScripts` + `SplitMix64` |
| `Support/` | `Base64Coding`, `Date+EpochMillis`, `FailureClassifier` (transient vs permanent through `RetryableError`) |

### `Packages/CipherCrypto` — PROTOCOL §4 on CryptoKit

| File | Role |
|---|---|
| `Engine/CipherCryptoEngine.swift` | Actor implementing `MessageCryptoService`: seal, open (verify signature **first**, then replay-agnostic derive and open), own-history verification with this device's key |
| `Engine/KeyDerivation.swift` | The two HKDF steps, byte-exact labels `cipher/v1/root` and `cipher/v1/msg\|<senderId>` |
| `Engine/AttachmentCipher.swift` | Random 256-bit key, ChaChaPoly combined form, SHA-256 hex |
| `KeyStore/KeychainIdentityKeyStore.swift` | Actor; data-protection Keychain, `WhenUnlockedThisDeviceOnly`, parameterised service name, refuses to overwrite, rolls back half-written identities |
| `KeyStore/SecureEnclaveWrapper.swift` | ECIES-style wrapping of raw keys with a Secure Enclave P-256 key (ephemeral P-256 → HKDF → AES-GCM); transparently skipped where no enclave exists |
| `KeyStore/IdentityPrivateKeys.swift`, `InMemoryIdentityKeyStore.swift`, `KeychainClient.swift`, `KeyStoreError.swift` | Private-key value type (never `CustomStringConvertible`), preview store, `SecItem` wrapper, typed errors |
| `Fingerprint/SafetyFingerprintGenerator.swift`, `EmojiTable.swift`, `QRPayload.swift` | Symmetric fingerprint, curated 256 single-code-point emoji, `cipher:verify?...` encode/decode |
| `Replay/InMemoryReplayGuard.swift` | For previews and the demo bot; the persisted guard lives in CipherPersistence |

### `Packages/CipherNetworking` — REST and realtime over URLSession

| Folder | Contents |
|---|---|
| `Client/` | `APIClient` (Bearer injection, fresh `X-Correlation-Id`, one 401 refresh-and-retry, problem+json → `ProblemDetail` → typed `APIError`), `Endpoint` / `HTTPTransport` / `ResponseValidator`, `MultipartFormData` (part `file`, filename `blob`, `application/octet-stream`), `TransferProgress`, `AuthTokenProvider` + `CoalescingAuthTokenProvider` (single-flight refresh shared by REST and WS) |
| `Configuration/APIConfiguration.swift` | Base and socket URLs; derives `ws`/`wss` from `http`/`https`; `isTransportSecure`, `isLoopback` |
| `DTO/` | Wire records with `toDomain()` (epoch millis → `Date`, `Base64Data` → `Data`); `MessagePageDTO` decodes straight into Core's `StoredEnvelope` |
| `Endpoints/` | One struct per route in PROTOCOL §1 (`RegisterEndpoint`, `UploadKeysEndpoint`, `SendMessageEndpoint`, `FetchMessagesEndpoint` with limit clamped to 1…200, `UploadAttachmentEndpoint`, …) |
| `Gateways/` | `RemoteAuthGateway`, `RemoteKeyDirectoryGateway`, `RemoteConversationGateway`, `RemoteAttachmentGateway` (+ `AttachmentGateway` port with real upload/download progress) |
| `Realtime/` | `WebSocketClient` actor (`RealtimeGateway`): supervisor loop, ping every 25 s, recycle after two missed pongs, `ReconnectPolicy` (1 s → 30 s, factor 2, full jitter), refresh on `4001`/handshake `401`, unbounded event fan-out; `RealtimeFrameCodec` for every §2 event; `WebSocketConnection` seam over `URLSessionWebSocketTask` |

### `Packages/CipherPersistence` — SwiftData behind the Core ports

| File | Role |
|---|---|
| `Store/PersistenceStore.swift` (+ `+Messages`, `+Conversations`, `+Contacts`, `+Outbox`, `+ReplayGuard`, `+Lifecycle`, `+Observation`) | One `ModelActor` implementing `MessageRepository`, `ConversationRepository`, `ContactRepository`, `OutboxRepository`, `ReplayGuard`; `@Model` objects never leave the actor |
| `Models/Stored*.swift` | `StoredMessage` (decrypted payload **and** raw envelope bytes for the Server's-Eye View), `StoredConversation`, `StoredConversationSettings` (disappearing timer survives sync), `StoredContact`, `StoredOutboxItem`, `StoredSeenCounter`, `StoredSendCounter` |
| `PersistenceConfiguration.swift` | In-memory or on-disk under `Application Support/Cipher/<accountId>/cipher.store`, `NSFileProtectionComplete`, excluded from backup |
| `PersistenceSchema.swift` | Versioned schema + migration plan |
| `Observation/ChangeNotifier.swift` | Re-query streams that end when the consumer cancels |

Notable behaviours: `nextCounter` is seeded past the highest stored outgoing counter (safe after
reinstall + sync); send and seen counters survive message deletion (never reuse a key, never
re-accept an old envelope); status updates go through `MessageStatus.shouldAdvance`; `markRead`
skips still-sealed Time Capsules; `deleteExpired(now:)` is the only thing that removes a
disappearing message.

### `Packages/CipherDesign` — the design system (SwiftUI only)

| Folder | Contents |
|---|---|
| `Tokens/` | `CipherColor` (+ semantic), `CipherGradient`, `CipherTypography`, `CipherSpacing`, `CipherRadius`, `CipherShadow` |
| `Components/` | `InitialsAvatar`, `PresenceDot`, `MessageBubbleShape`, `BubbleStatusGlyph`, `ConnectionBanner`, `CipherButtonStyle`, `CipherTextField`, `GlyphText` + `GlyphAlphabet`, `ToastCenter` / `ToastHost`, `SkeletonView`, `EmptyStateView`, `ShieldBadge`, `UnreadBadge`, `DaySeparator`, `TypingIndicator`, `QRCodeView`, `EmojiFingerprintView`, `SectionCard`, `AttachmentProgressRing`, `ViewOnceOverlay` |
| `Motion/` | `CipherMotion` (springs, durations, `reduced(_:)`), `CipherGlyphs`, `DecryptSchedule`, `DecryptText`, `DecryptTextRenderer` (iOS 18 `TextRenderer`), `ScrambleOnSend`, `FlipCard`, `CountdownRing`, `SealedCapsuleView`, `SealedEnvelope` |
| `Security/` | `ServerEyeRawView`, `TrustRing`, `WhisperBlur`, `FlipToHideOverlay`, `GlyphRain`, `PrivacyCurtain`, `LockScreenView`, `PINPadView`, `PINKey`, `SensitiveContentChip`, `KeyChangeWarningBanner` |
| `Haptics/` | `HapticPattern` (nine semantic patterns), `HapticPatternLibrary` (AHAP-like events), `HapticEngine` protocol, `CoreHapticsEngine`, `NoopHapticEngine` |

Every animation checks `accessibilityReduceMotion` and has a crossfade or static alternative.

### App target (`ios/Cipher`)

| Folder | Contents |
|---|---|
| `App/` | `CipherApp` (`@main`), `AppContainer` (composition root; `live()` and `mock()`; `messagingStackFactory` extension point), `MessagingStack` (per-account ports and use cases), `AppSession` (state machine `restoring → signedOut → bootstrappingKeys → ready`, identity bootstrap with `409` conflict handling, scene-phase hooks), `Router` + `Route` (all screens keyed by domain ids), `RootView`, `RouteDestinationView`, `RealtimeLifecycle` |
| `Data/` | `KeychainSessionStore` + `KeychainStore`, `AuthTokenProviderAdapter` (single-flight refresh, writes the Keychain before any caller sees the token, reports a rejected refresh exactly once), `SessionEventRelay`, `IdentityBootstrapper`, `ServerEndpoints` + `AppPreferences` (relay override, demo companion switch, published-identity registry), `PresentableProblem`, `Integration/ProductionFactories` (the single wiring point for the real gateways, key store and realtime lifecycle), `Mocks/` (in-memory fakes and fixtures for every `#Preview`) |
| `Features/Onboarding/` | `WelcomeView` (animated lock emblem, glyph rain, decrypting tagline), `AuthView` + `AuthViewModel` + `AuthValidation` (protocol rules inline), `KeyGenerationView` (three paced steps driven by the real bootstrap, conflict card, retry) |
| `Features/Conversations/` | `ConversationListView` / `ViewModel` / `Row` (search over names and decrypted previews, swipe actions, pull-to-refresh sync), `NewConversationView` |
| `Features/Chat/` | `ChatViewModel` (+ `Actions`), `Ports/` (narrow protocols the Core use cases adopt retroactively, `ChatDependencies`, `AttachmentSending`), `Views/` (`ChatView`, `MessageList` with smart auto-scroll, `MessageRow`, bubbles: text with decrypt reveal, attachment, reply quote, reactions, tampered, system, sealed capsule; `Composer/` with whisper, view-once and capsule toggles, `TimeCapsulePickerSheet`), `ServersEye/` (`ServersEyeView`, `ServersEyeRow`), `Support/` (`MessageGrouper`, `TypingDebouncer`, `ComposerOptions`, `MessageFormatting`) |
| `Features/Verify/` | `VerifyContactViewModel` (observes the contact so a `key.changed` recomputes the fingerprint mid-screen), `VerifyDependencies`, `VerificationOutcome`, `Scanner/` (`CameraCaptureSession`, `QRScannerView`, `QRScannerScreen`, `ViewfinderOverlay`, `PastePayloadSheet`, `CameraAuthorization`) |
| `Features/Trust/` | `TrustRingViewModel`, `TrustRingAvatar`, `TrustSheetView` / `Header` / `ReasonRow` / `LoaderView`, `TrustCopy` (plain-English reasons with real dates), `TrustDependencies` (`AlwaysOnMetadataStripping`) |
| `Features/Ephemeral/` | `Disappearing/` (`ChangeDisappearingTimerUseCase` sends the encrypted notice, `DisappearingTimerSync` applies the other side's, menu and notice views), `Expiry/` (`ExpiryPolicyApplier`, `ExpiryScheduler` actor, `ExpirySweepModifier`, countdown views), `TimeCapsule/` (composer sheet, presets, reveal view, unlock coordinator), `Ports/EphemeralPorts` |
| `Features/SensitiveGuard/` | `SensitiveContentGuard` actor (debounce → Core detector → `DataDetectorExclusions` veto → `LexicalHints` review → rank), `SensitiveSuggestion` (copy and flags on one value), `SensitiveGuardConfiguration`, `SensitiveGuardPreferences`, chip and settings section |
| `Features/Privacy/` | `FlipToHideMonitor` (Core Motion gravity at 10 Hz, hysteresis 0.8/0.5), `GravitySource` (device and preview), `PrivacyGuardModifier` (`flipToHide` + `PrivacyCurtain` when the scene is inactive) |
| `Features/Lock/`, `Features/Attachments/`, `DemoBot/` | App lock (PIN + Face ID, duress PIN → decoy inbox), the attachment picking/processing pipeline (downscale, metadata strip, thumbnail) over `SendAttachmentUseCase`, and the DEBUG-only Echo companion |
| `Features/Settings/` | Account card, identity public keys (copyable), relay override with restart hint, app lock entry, DEBUG demo companion toggle, sign out |
| `Resources/` | `Assets.xcassets`, `Localizable.xcstrings` (every user-facing string), `Info.plist` (generated from `project.yml`: camera, photo library and Face ID usage strings, `NSAllowsLocalNetworking`), entitlements (`NSFileProtectionComplete` default) |

### Data flow in one paragraph each

**Send.** `ChatViewModel.send()` builds a `MessagePayload` (text, reply, reaction or attachment)
and the flags from `ComposerOptions`; `SendMessageUseCase` reserves the next counter, persists the
row as `sending`, asks `CipherCryptoEngine` to seal it for the recipient's pinned bundle, enqueues
the envelope in the outbox (which also mirrors the JSON onto the message for the Server's-Eye
View), then `AckReconciler` posts it through `RemoteConversationGateway`. A `201`/`200` ack moves
the row to `sent` and clears the outbox item; a transient failure leaves it queued for
`FlushOutboxUseCase`; a permanent one marks it `failed` with a retry button.

**Receive.** `WebSocketClient` decodes a `message.new` frame into `ServerEvent.messageNew`;
`HandleRealtimeEventUseCase` hands the `StoredEnvelope` to `ReceiveEnvelopeUseCase`, which resolves
and pins the sender's keys, checks the persisted replay guard, verifies and opens through the
engine, persists the message (or a `tampered` row naming the reason), bumps the unread count, and
only then sends `message.ack`. The relay marks it `DELIVERED` and relays `receipt.delivered` to the
sender, whose `HandleRealtimeEventUseCase` updates the status without ever downgrading it.

**Verify.** `VerifyContactViewModel` computes the fingerprint from this device's public keys and
the contact's pinned bundle; scanning the contact's QR decodes a `QRPayload`, and only a byte-exact
match against the *pinned* keys (not the directory's current answer) calls `VerifyContactUseCase`.

### Logging rules (both sides)

`os.Logger` per module with categories on iOS, SLF4J with the correlation id in MDC on the relay.
Logged: identifiers, counts, byte sizes, versions, phases, levels. Never logged: plaintext, drafts,
ciphertext, signatures, tokens, password hashes, key bytes, filenames, MIME types.
