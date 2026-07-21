# Operational Baseline - aura_final

Last updated: 2026-07-21 UTC (Post Integrity Remediation)

## Production resources

- Web: `auraplatform.org`, deployed via Railway from this repo. Push-to-deploy was confirmed live 2026-07-13; re-verify before relying on it.
- Mobile: iOS via the founder's manual Codemagic/App Store flow; Android per release process. Last recorded release: `1.2.2+22`.

## Commands

- `flutter analyze` (must be clean; clean in post-integrity remediation)
- `flutter build web --release` (must compile before release)
- `flutter test` (currently blocked in this Windows workspace: test runner hangs before test output even on pre-existing tests; rerun from a healthy Flutter environment before release certification)

## Current verification note

Post-integrity remediation validated with `flutter analyze`. Targeted Flutter tests were added for composer identity, but local `flutter test` and `--list-tests` invocations timed out before producing test output. Production-flow verification remains required after deployment.

## Release order

Implement -> Founder approval -> commit -> analyze + build -> push (web auto-deploy, if still configured) -> live cache-busted verification on `auraplatform.org` -> continuity synchronization.

Note from the ROS Phase II deploys: production sits behind an edge cache. Always verify with a cache-busted request/screenshot, and expect a founder-side cache purge to be needed occasionally.

No secrets are stored in this working directory.
