# Changelog

All notable changes to Cipher are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Scopes in commit subjects are `ios | backend | crypto | protocol | ci | docs | infra`.

## [Unreleased]

## [1.0.0] - 2026-09-24

Hardening, CI and documentation release.

### Added
- GitHub Actions: `backend.yml` (JDK 21, `mvn verify`, Docker image build) and `ios.yml`
  (`swift build`/`swift test` for every package on macOS, `xcodegen` + `xcodebuild` for the app,
  SwiftLint strict). Test steps are non-blocking until the deferred suites land.
- README with architecture, encryption, threat model, features, decisions, workflow and
  limitations; `docs/ARCHITECTURE.md` module tour; Mermaid sources under `docs/diagrams/`.
- Screenshot and GIF paths under `docs/screenshots/` and `docs/gifs/`.

### Changed
- `docs/PROTOCOL.md` corrected to match the relay: a rejected WebSocket handshake answers
  `401 application/problem+json` (code `4001` is reserved for a session without a principal),
  idle sessions close with `1001`, the inbound frame budget (240/min/user) is documented next to
  `4008`, `presence.update` is announced for the first socket only, the multipart part is named
  `file` (with `blob` accepted), `message.ack` carries at most 500 ids, envelope `v` is optional
  on send, and `urn:cipher:problem:forbidden` (403) is listed.

## [0.5.0] - 2026-09-24

Protect the human, part two: ephemerality, trust and duress.

### Added
- ios: disappearing messages with a per-conversation timer (30 s, 5 min, 1 h, 1 day) announced
  as an encrypted `disappearing_changed` system message; countdown ring per bubble;
  `ExpiryScheduler` sweeps every 5 s while a chat is visible and on foreground.
- ios: Time Capsules: `unlockAt` inside the ciphertext, sealed envelope with live countdown,
  reveal with the decrypt animation and the `capsuleUnlock` haptic.
- ios: Trust Ring around every contact and the "Why this chat is secure" sheet, scored on device
  from verification, key stability, disappearing timer and metadata stripping; a recent key change
  caps the level at low.
- ios: app lock with PIN and Face ID; duress PIN that opens a deterministic, in-memory decoy inbox.

## [0.4.0] - 2026-09-24

Protect the human, part one.

### Added
- ios: sensitive-content guard in the composer (passwords, card numbers, IBANs, one-time codes)
  using on-device scanners, `NSDataDetector` exclusions and `NLTagger` review; suggests view-once
  with a one-minute auto-delete.
- ios: whisper messages (blurred until held), flip-to-hide via Core Motion gravity with
  hysteresis, privacy curtain over the app-switcher snapshot.
- ios: haptic language: nine semantic patterns played through Core Haptics with a UIKit fallback.
- ios: photos downscaled and stripped of EXIF/GPS metadata before sealing.

## [0.3.0] - 2026-09-24

Make encryption visible.

### Added
- ios: decrypt animation for incoming text and scramble-on-send for outgoing text, with Reduce
  Motion alternatives.
- ios: Server's-Eye View: any bubble flips to the raw envelope; full-screen split of "what you
  see" against "what the server stores"; raw envelopes mirrored in the local store.
- ios: emoji safety fingerprint, safety number, QR verification with a camera scanner and paste
  fallback; key-change review with a red banner in the chat.
- crypto: `SafetyFingerprintGenerator`, curated 256-entry `EmojiTable`, `QRPayload`.

## [0.2.0] - 2026-09-24

Attachments and resilience.

### Added
- backend: encrypted attachment upload (multipart, 25 MiB, 20/min/user) and participant-only
  download behind a `BlobStorage` port with a filesystem adapter; scheduled purge of expired
  envelopes and blobs; optional MinIO profile in Docker Compose.
- ios: encrypted attachments with a random key per file, upload progress ring, digest check
  before decryption, thumbnails inside the ciphertext, view-once media.
- ios: durable outbox flushed oldest-first after reconnect; retry from the bubble; exponential
  backoff with full jitter; token refresh on `4001`; ping/pong heartbeat with dead-socket
  recycling.
- ios: delivered and read receipts, typing indicators, presence with last-seen, history sync.

## [0.1.0] - 2026-09-24

MVP: end-to-end encrypted text between two phones through a blind relay.

### Added
- backend: registration, login, rotating refresh tokens, logout; HS256 JWTs; RFC 7807 problems
  with correlation ids; token-bucket rate limits; Flyway schema; dev seed (`alice`, `bob`, `echo`).
- backend: public key directory with explicit rotation and `key.changed` fan-out.
- backend: deterministic 1:1 conversations, opaque envelope storage with idempotent send, paged
  history, raw WebSocket relay at `/ws` with `message.ack`, `receipt.read`, typing, presence and
  unacked-envelope replay on connect.
- ios: `CipherCore` domain, ports and use cases; `CipherCrypto` engine implementing PROTOCOL §4
  on CryptoKit with a Keychain key store and Secure Enclave wrapping; `CipherNetworking` API
  client and WebSocket client; `CipherPersistence` SwiftData store with outbox and replay guard;
  `CipherDesign` tokens and components.
- ios: onboarding (welcome, register/log in, animated key generation with conflict handling),
  conversation list, chat with optimistic sending, replies and reactions, settings with relay
  override and identity keys, DEBUG-only Echo companion.
- infra: Docker Compose for PostgreSQL and the relay, Makefile, pull request template,
  `docs/PROTOCOL.md` v1.

[Unreleased]: https://github.com/frank-shema/cipher-secure-messenger/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/frank-shema/cipher-secure-messenger/compare/v0.5.0...v1.0.0
[0.5.0]: https://github.com/frank-shema/cipher-secure-messenger/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/frank-shema/cipher-secure-messenger/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/frank-shema/cipher-secure-messenger/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/frank-shema/cipher-secure-messenger/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/frank-shema/cipher-secure-messenger/releases/tag/v0.1.0
