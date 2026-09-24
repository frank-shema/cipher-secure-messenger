## Summary

<!-- One or two sentences. Which phase does this belong to? (Phase 0–6) -->

## Why

<!-- The problem or product goal this PR serves. Link the theme if it's a creativity feature:
     (A) Make encryption visible · (B) Protect the human · (C) Delight -->

## What changed

<!-- Bullet list, grouped by module (ios / backend / crypto / protocol / ci / docs / infra). -->

## How to test

<!-- Exact commands and manual steps a reviewer can follow. -->

```sh
make test
```

## Screenshots / GIFs

<!-- Required for UI changes. Delete this section for backend-only PRs. -->

## Security considerations

<!-- What does this touch in the threat model? Keys, plaintext, logging, auth, storage, replay?
     Say "none" explicitly if nothing changes. -->

## Checklist

- [ ] Builds locally (`xcodebuild` / `mvn verify`)
- [ ] Tests added or updated, and passing
- [ ] No secrets, keys, `.env` files, or build artifacts committed
- [ ] No plaintext or key material logged
- [ ] README / PROTOCOL.md updated if the contract or features changed
- [ ] CHANGELOG.md updated under **Unreleased**
- [ ] Conventional Commit title (`type(scope): summary`)
