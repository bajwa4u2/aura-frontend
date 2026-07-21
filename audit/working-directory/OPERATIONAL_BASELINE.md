# Operational Baseline — aura_final

Last updated: 2026-07-21 UTC

## Production resources

- Web: `auraplatform.org`, deployed via Railway from this repo (push-to-deploy was confirmed live 2026-07-13; re-verify before relying on it).
- Mobile: iOS via the founder's manual Codemagic/App Store flow; Android per release process. Last recorded release: `1.2.2+22`.

## Commands

- `flutter analyze` (must be clean)
- `flutter build web --release` (must compile)
- `flutter test`

## Release order

Implement -> Founder Approval -> Commit -> analyze + build -> Push (web auto-deploy) -> Live cache-busted verification on auraplatform.org -> Continuity synchronization

Note from the ROS Phase II deploys: production sits behind an edge cache — always verify with a cache-busted request/screenshot, and expect a founder-side cache purge to be needed occasionally.

No secrets are stored in this working directory.
