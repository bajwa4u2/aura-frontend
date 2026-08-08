# Operational Baseline - aura_final

Last updated: 2026-08-08 UTC (Canonical Flutter Thread-Call Lifecycle Stage 1 locally certified)

## Production resources

- Web: `auraplatform.org`, deployed via Railway from this repo. Push-to-deploy was confirmed live 2026-07-13; re-verify before relying on it.
- Mobile: iOS via the founder's manual Codemagic/App Store flow; Android per release process. Last recorded release: `1.2.2+22`.

## Commands

- `flutter analyze` (must be clean; clean in post-integrity remediation)
- `flutter build web --release` (must compile before release)
- `flutter test --exclude-tags golden` (repository-standard practical suite)

Local toolchain note: in this sandbox, plain `flutter` startup can hang because the Flutter SDK checkout at `C:/flutter` is owned by a different Windows user. Run Flutter certification commands with the explicit Git safe-directory environment override for `C:/flutter` unless/until the host-level Git config is corrected:

`GIT_CONFIG_COUNT=1`, `GIT_CONFIG_KEY_0=safe.directory`, `GIT_CONFIG_VALUE_0=C:/flutter`

## Platform-wide engineering governance

These rules apply across every Aura repository, present and future:

- Certified product surfaces are protected by default.
- Solve problems within the owning feature/module before touching shared systems.
- Any work touching a shared system must identify the boundary, preserve existing behavior, execute targeted regression, certify shared-system health, and report that certification separately.
- If certified shared-system preservation is impossible, stop and return for founder approval before implementation.
- Future implementation tasks inherit these rules automatically.
- Future audits must audit governance compliance as well as feature correctness.
- Newly adopted engineering doctrines must be recorded in working continuity during the next implementation task.

## Current verification note

Stage 1 Gate 2 toolchain health was restored using the `C:/flutter` safe-directory override. Current local verification: focused Stage 1 tests passed 6/6, relevant correspondence/realtime/notification/Meeting set passed 31/31, repository-standard non-golden suite passed 125/125, `flutter analyze` clean, and `flutter build web --release --no-wasm-dry-run` completed successfully.

## Thread calling reliability baseline

- Current authoritative audit: `../aura-backend/docs/2026-08-08-thread-calling-reliability-collective-audit.md`.
- Stage 1 blueprint/design record: `docs/2026-08-08-canonical-flutter-thread-call-lifecycle-stage-1-blueprint.md`. Stage 1 is implemented locally and pending founder review/commit.
- Foreground Thread call interruption is now app-root owned locally through `ThreadCallLifecycleHost`, `threadCallLifecycleProvider`, `incomingCallBridgeProvider`, and root-mounted `AuraIncomingLiveLayer`.
- Activity reads `/notifications`; active Thread calls currently create backend Communication rows and push attempts, not actor-aware call Notification rows.
- Party-A-stuck-on-`Connecting...` is addressed locally by routing caller start and callee accept through one Thread lifecycle owner that delegates to the existing `RealtimeController` and projects joined/media/connected presentation phases from existing controller state.
- Meetings are a hard preservation boundary for any shared realtime client work.
- Stage 1 release impact: web deploy, desktop build/deploy, Android release, and iOS release. Existing installed native clients cannot receive this fix without new binaries.

Stage 1 local verification note:

- `flutter analyze` clean on 2026-08-08.
- `git diff --check` clean.
- Focused lifecycle test passed 6/6.
- Relevant correspondence/realtime/notification/Meeting set passed 31/31.
- Repository-standard non-golden suite passed 125/125.
- Web release build completed successfully.

## Release order

Implement -> Founder approval -> commit -> analyze + build -> push (web auto-deploy, if still configured) -> live cache-busted verification on `auraplatform.org` -> continuity synchronization.

Note from the ROS Phase II deploys: production sits behind an edge cache. Always verify with a cache-busted request/screenshot, and expect a founder-side cache purge to be needed occasionally.

No secrets are stored in this working directory.
