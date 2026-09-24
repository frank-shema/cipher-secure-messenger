<div align="center">

# Cipher

### Security you can see and feel

End-to-end encrypted iOS messenger built with SwiftUI and CryptoKit, backed by a zero-knowledge
Spring Boot relay that never sees your messages.

[![Backend CI](https://github.com/frank-shema/cipher-secure-messenger/actions/workflows/backend.yml/badge.svg)](https://github.com/frank-shema/cipher-secure-messenger/actions/workflows/backend.yml)
[![iOS CI](https://github.com/frank-shema/cipher-secure-messenger/actions/workflows/ios.yml/badge.svg)](https://github.com/frank-shema/cipher-secure-messenger/actions/workflows/ios.yml)
![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)
![iOS 17+](https://img.shields.io/badge/iOS-17%2B-000000?logo=apple&logoColor=white)
![Java 21](https://img.shields.io/badge/Java-21-007396?logo=openjdk&logoColor=white)
![Spring Boot 3.5](https://img.shields.io/badge/Spring%20Boot-3.5-6DB33F?logo=springboot&logoColor=white)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

</div>

> **Status: Phase 0 — scaffold.** The repository builds on both sides; features arrive phase by
> phase through pull requests. See [CHANGELOG.md](CHANGELOG.md) and the roadmap below.

## Quick start

Prerequisites: Xcode 16+ (tested on Xcode 27), JDK 21, Docker.

```sh
make up          # PostgreSQL + relay on :8080 (dev profile seeds alice, bob, echo)
make ios-open    # open the Xcode project; run the Cipher scheme on a simulator
make test        # backend + iOS test suites
```

## Roadmap

| Phase | Scope | Tag |
|---|---|---|
| 0 | Scaffold, protocol contract | — |
| 1 | Auth, key directory, WebSocket relay, E2EE text messaging, Echo | v0.1.0 |
| 2 | Encrypted attachments, offline outbox, receipts & typing | v0.2.0 |
| 3 | Decrypt animation, Server's-Eye View, emoji safety fingerprint | v0.3.0 |
| 4 | Sensitive-content guard, whisper & flip-to-hide, haptic language | v0.4.0 |
| 5 | Disappearing messages & Time Capsules, Trust Ring, duress PIN | v0.5.0 |
| 6 | Hardening, CI, docs, GIFs | v1.0.0 |

## Documents

- [docs/PROTOCOL.md](docs/PROTOCOL.md) — REST + WebSocket contract, envelope cryptography
- [CHANGELOG.md](CHANGELOG.md)
- [.github/pull_request_template.md](.github/pull_request_template.md)

## Development workflow

GitHub Flow: `main` is always buildable; work happens on short-lived `type/scope-description`
branches merged through pull requests with a merge commit. Commits follow Conventional Commits
with scopes `ios | backend | crypto | protocol | ci | docs | infra`. `main` requires pull
requests and passing CI.

## License

[MIT](LICENSE)
