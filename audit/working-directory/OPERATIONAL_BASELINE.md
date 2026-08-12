# Operational Baseline - aura_final

Last updated: 2026-08-14 UTC (Realtime Architecture Correction — Phase 1 CONDITIONALLY APPROVED/READY FOR COMMIT-PUSH in aura-backend only — see below)

## Realtime Architecture Correction baseline — Phase 1 conditionally approved in aura-backend, zero change in this repo

- Backend Phase 1 record: `../aura-backend/docs/2026-08-14-realtime-architecture-correction-phase1-implementation.md` — CONDITIONALLY APPROVED, amended Gate 2 items RESOLVED (guest disconnect investigated/not-a-contradiction; 107-migration disposable replay clean), READY FOR COMMIT/PUSH, NOT yet committed/pushed.
- **This repo's `lib/core/realtime_canonical/` is unchanged** — Phase 1 (including its amendment) wired only the backend's own production code to the already-frozen Phase 0 contracts; the contracts themselves (and therefore the Dart mirror) did not change.

## Realtime Architecture Correction baseline — architecture APPROVED/FROZEN, Phase 0 (canonical contracts + executable test harness) CLOSED

- Full plan: `../aura-backend/capability/REALTIME_ARCHITECTURE_CORRECTION_LONG_TERM_ARCHITECTURE_AND_MIGRATION_PLAN.md` (canonical, version-controlled in `aura-backend` — moved 2026-08-14 from an unversioned parent-level location) — status now **ARCHITECTURE APPROVED — FROZEN**, all six §18 decisions resolved, including the JOIN_FAILED/SESSION_FAILED sub-decision frozen 2026-08-14 (JOIN_FAILED participant-scoped, never auto-fails a session). See paired backend `OPERATIONAL_BASELINE.md` entry for the full decision list.
- Compatibility/migration contract: `../aura-backend/capability/REALTIME_ARCHITECTURE_CORRECTION_PHASE_0_COMPATIBILITY_MIGRATION_CONTRACT.md`.
- **Phase 0 delivered**: pure, isolated, executable Dart canonical contracts in `lib/core/realtime_canonical/` (`session_lifecycle.dart`, `participant_lifecycle.dart`, `device_socket_binding.dart`, `precedence.dart`, `event_contract.dart`, `lifecycle_test_harness.dart`), a behaviorally-identical mirror of `aura-backend`'s `src/realtime/canonical/`. Deterministic test suite: `test/realtime_canonical/lifecycle_scenarios_test.dart` (29 required scenarios) + `test/realtime_canonical/meetings_contract_fixtures_test.dart` (4 Meetings fixtures), **33/33 passing**. `flutter analyze lib/core/realtime_canonical test/realtime_canonical` clean.
- **Confirmed by `git diff`: zero production widget/provider/controller changes, nothing wired into any live code path.** `lib/core/realtime_canonical/` is deliberately placed outside `lib/features/realtime/` so an accidental production import would stand out in review.
- Phase 1 (backend canonical lifecycle production wiring) is named next but explicitly NOT started, NOT authorized to begin automatically — stops here for founder Gate 1/Phase 0 closeout review.

## Communication Timeline Authority baseline — CLOSED, committed `38765bc`, pushed

- Backend record: `../aura-backend/docs/2026-08-13-communication-timeline-authority-phase1-implementation.md`.
- Scope: Thread/DM calls only. Meetings excluded.
- `activity_screen.dart`'s dead `type == 'LIVE'` branch activated: `_buildTitle()` extended for COMPLETED/DECLINED/CANCELLED (plus pre-existing MISSED), `_iconForType()` gained a `LIVE` case.
- `NotificationsRepository._normalizeNotificationItem()` general fix: falls back to `item['payload']` when `item['data']` is absent — closes a pre-existing contract mismatch for every notification type, not just calls.
- Certification: `flutter analyze` clean, practical suite 178/178 (up from 172), web build succeeded. New `test/activity_screen_communication_timeline_test.dart` (6 tests) against the real production `ActivityScreen`.
- **Founder Gate 2 approved. Committed `38765bc` ("feat: establish communication timeline authority phase 1"), pushed to `origin/main` (`6e1f7aa..38765bc`).** No production query, no deployment polling, no live production verification performed at any point in this chapter, per explicit instruction.
- Meetings, Reachability Authority, Session Continuity Authority, Communication Runtime Lifecycle Authority, Device Communication Presence Authority, Canonical Call Notification Stage A, Institution Authority, Identity Foundation, Link Intelligence / OG Preview all remain protected and untouched.
- **Institutional Attention Authority doctrine is FROZEN, founder-approved, zero unresolved decisions** (backend `docs/2026-08-13-institutional-attention-authority-proposal.md`) — no frontend implication yet, not implemented.

## Compose Link Intelligence / OG Preview baseline — CLOSED, committed `6303882`, pushed

- Backend record: `../aura-backend/docs/2026-08-12-compose-link-intelligence-og-preview-phase1-implementation.md`.
- **Final scope, founder-approved: Member Posts + Institution Posts + Institution Announcements** — one canonical capability across all three.
- New shared module `lib/core/link_preview/`: `LinkPreview`, `link_url_detection.dart`, `LinkPreviewService` (`POST /link-previews/resolve`), `ComposeLinkDetector` (500ms debounce), `LinkPreviewCard`.
- `Post`, `FeedItem`, `InstitutionPost`, `Announcement` domain models all gained link fields (`linkUrl`, `linkTitle`, `linkDescription`, `linkImageUrl`, `linkSiteName`, and `FeedItem`/`Announcement` also `linkFaviconUrl`).
- `compose_screen.dart`, `institution_post_composer_screen.dart`, and `institution_announcement_composer.dart` all wire the identical detector/card/service; `post_card.dart`, `unified_feed_card.dart`, and `announcement_detail_screen.dart` all render via the identical `LinkPreviewCard`.
- Certification: `flutter analyze` clean, practical suite 172/172 (up from 147), web build succeeded. Real widget tests against all three production composer screens for the first time in this repo (9 tests total), scoped to Link Intelligence only.
- **Founder Gate 2 approved. Committed `6303882` ("feat: establish link intelligence phase 1"), pushed to `origin/main` (`9d0d558..6303882`).** No production query, no deployment polling, no live production verification performed at any point in this chapter, per explicit instruction.
- Meetings, Reachability Authority, Session Continuity Authority, Communication Runtime Lifecycle Authority, Device Communication Presence Authority, Notification Delivery Authority, Canonical Call Notification Stage A, Institution Authority, Identity Foundation, Member Posts, Institution Posts all remain protected and untouched.

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

## Communication Continuity & Presence platform authorities

Backend discovery record: `../aura-backend/docs/2026-08-08-communication-continuity-presence-platform-architecture.md`.
Backend Chapter 1 contract record: `../aura-backend/docs/2026-08-08-communication-continuity-presence-chapter-1-contracts.md`.
Backend Device Presence Phase 1 record: `../aura-backend/docs/2026-08-08-device-communication-presence-phase-1-implementation.md`.
Backend Notification Delivery Phase 1 record: `../aura-backend/docs/2026-08-09-notification-delivery-authority-phase-1-implementation.md`.

Proposed platform authorities:

- Communication Runtime Lifecycle Authority.
- Notification Delivery Authority.
- Device Communication Presence Authority.
- Communication Timeline Authority.

Flutter Stage 1 is the Thread-call foreground lifecycle seed. It is not a replacement for a platform-wide lifecycle authority. Future work must preserve `RealtimeController` as socket/media/session execution authority and preserve Meetings exactly unless founder explicitly authorizes a shared-system change with Meeting regression certification.

Pre-native-production mandatory gates: Device Communication Presence Phase 1 (`3bf8d67`) and Notification Delivery Authority Phase 1 (`b23ff44`) are backend-local, Gate 2 approved, committed, and pushed. Native background/terminated notification certification, Communication Timeline Authority Phase 1, iOS Firebase/APNs configuration confirmation, and Meetings preservation certification for later shared authority implementation remain mandatory.

## Identity Foundation Phase 1 baseline — chapter COMPLETE, committed `56a0bb7`, pushed

- Record: `../aura-backend/docs/2026-08-11-identity-foundation-phase-1-implementation.md`.
- `identityBaselineCompleteProvider` (mirrors `emailVerifiedProvider`) + `router.dart`'s `kCompleteIdentityRoute` (`/complete-identity`) redirect, checked before email verification.
- New `IdentityBaselineScreen`, structurally identical to `VerifyPendingScreen`.
- No age-eligibility policy is implemented — the one remaining open founder decision for this chapter.
- Canonical member-identity model at `lib/core/directory/directory_entry.dart` (`DirectoryEntry`/`memberEntryFromMap`/`dedupeDirectoryEntries`), consumed by both `new_conversation_screen.dart` (personal Thread/Space creation) and `institution_spaces_screen.dart` (institution-space creation, via the new `MemberPickerField` widget). One resolver, not two.
- Verification: `flutter analyze` clean, practical suite **147/147**, `flutter build web --release` succeeded. Meetings, Reachability Authority, Session Continuity Authority, Communication Runtime Lifecycle Authority, Device Communication Presence Phase 1, Notification Delivery Authority Phase 1, Canonical Call Notification Stage A, and Institution authority remain protected.

## Current verification note

Correspondence entry flow repair, 2026-08-08:

- Record: `docs/2026-08-08-correspondence-entry-flow-repair.md`.
- Focused `test/new_conversation_screen_test.dart` passed 5/5.
- Practical non-golden Flutter suite passed 130/130.
- `flutter analyze` passed.
- Web release build passed.
- Backend paired contract repair is recorded in `../aura-backend/docs/2026-08-08-correspondence-entry-flow-contract-repair.md`.
- Meetings, Reachability Authority, Session Continuity Authority, Canonical Call Notification Stage A, Thread Call Lifecycle Stage 1, and Device Communication Presence Phase 1 remain protected.

Stage 1 Gate 2 toolchain health was restored using the `C:/flutter` safe-directory override. Current local verification: focused Stage 1 tests passed 6/6, relevant correspondence/realtime/notification/Meeting set passed 31/31, repository-standard non-golden suite passed 125/125, `flutter analyze` clean, and `flutter build web --release --no-wasm-dry-run` completed successfully.

Pre-release connected-system health gate, 2026-08-08:

- Record: `docs/2026-08-08-pre-release-connected-system-health-audit.md`.
- Verdict: READY WITH NON-BLOCKING RISKS for native test builds.
- Additional verification: focused/recent shared-system set passed 78/78, practical non-golden suite passed 125/125, `flutter analyze` passed, web release build passed, Android debug build passed, Windows desktop debug build passed, Flutter doctor passed, and `git diff --check` passed for Flutter/backend.
- Meetings: HEALTHY; no Meetings product files or shared realtime controller/state/socket/media files were edited.
- iOS: AT RISK only because the CI-provided `FIREBASE_IOS_CONFIG_BASE64` secure variable cannot be verified from Windows and must be confirmed before/with the iOS build pipeline.

## Thread calling reliability baseline

- Current authoritative audit: `../aura-backend/docs/2026-08-08-thread-calling-reliability-collective-audit.md`.
- Stage 1 blueprint/design record: `docs/2026-08-08-canonical-flutter-thread-call-lifecycle-stage-1-blueprint.md`. Stage 1 is committed and pushed as `86de6e165931e96185a2e78a349bb5502065940a`.
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
