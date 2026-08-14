# Next Work - aura_final

Last updated: 2026-08-16 UTC (**Item 15 (Rich-Text Composition) DELIVERED same day** — see `CURRENT_STATE.md` and aura-backend's roadmap doc Item 15 subsection. Composer toolbar UI for Institution Posts/Announcements explicitly deferred, named not hidden. Next: item 17. **Item 14 (Internal Link Hydration) DELIVERED** — see `CURRENT_STATE.md` and aura-backend's roadmap doc Item 14 subsection for full detail. Next: item 15/16. Realtime Architecture Correction — Phase 4 (Notification/Ringing Projection Migration) CLOSED in this repo, founder-approved, committed `e344dbc` (paired backend `b359a66`), pushed — see `CURRENT_STATE.md`. Next Realtime phase: Phase 5 (Institution Space adapter), not started, requires a new founder directive. **Canonical, governed, cross-repo Consolidated Release-Client Roadmap: `../aura-backend/capability/AURA_RELEASE_CLIENT_CONSOLIDATED_ROADMAP.md`** — read that document for the single authoritative view of everything remaining before an integrated release-client candidate. Founder release doctrine FROZEN: every founder-confirmed roadmap item (native-notification founder-device-certification gate, iOS Firebase/APNs, Runtime Lifecycle Phase 2, Selection/Clipboard/Paste, Legacy Overlay Cleanup, the Meeting attendee-context restoration item below, and items 8-17) is RELEASE REQUIREMENT: MANDATORY, not an engineering A/B/C recommendation. This file remains the tactical, this-repo-scoped work list; the roadmap doc is the strategic reconciliation.)

This document lists only remaining work. No item below is authorized as the next milestone until the founder prioritizes it.

## Institution Ownership Continuity, 2026-08-14 — COMPLETION PASS DELIVERED

All four founder decisions resolved; this repo built decision D (the governed recovery surface). **Carried forward, disclosed not deferred silently: the phantom `EDITOR` institution role.** `invite_create_screen.dart` offers `EDITOR` as a selectable invite role and several screens render labels/colors for it, but the backend `InstitutionMemberRole` enum has only OWNER/ADMIN/MEMBER — assigning it cannot succeed. The dead `Make Editor` control was removed from the platform-admin members screen; the wider phantom (especially the invite surface) needs its own founder decision: add the role, or purge it.

## Institution Ownership Continuity, 2026-08-14 — this repo's half implemented, commit held pending founder review (superseded above)

Canonical record (aura-backend-owned): `../aura-backend/capability/INSTITUTION_OWNERSHIP_CONTINUITY_DOCTRINE.md`. Not built this pass, recommended follow-up if needed: a platform-admin dashboard/picker UI for emergency ownership recovery — the repository method and backend endpoint already exist and are callable.

## Account Lifecycle / Public Identity, 2026-08-14 — this repo's half implemented, commit held pending founder review

Canonical record (aura-backend-owned): `../aura-backend/capability/ACCOUNT_LIFECYCLE_DOCTRINE.md`. Two mandatory obligations recorded OPEN there (Institution Ownership Continuity, Account Retention & Final Deletion) — neither has any frontend scope defined yet.

## Domain 9 — CLOSED, committed and pushed, 2026-08-14 (`88efffb`)

## Domain 9 — Frontend Contextual Mention Eligibility corrected, 2026-08-14 — commit held pending report review

Canonical record (aura-backend-owned): `../aura-backend/capability/FOUNDER_ACCEPTANCE_REGISTER.md` Domain 9. `mention_scope.dart`/`mention_scope_providers.dart` added; Thread/Space/DM composers now pass a bounded, backend-eligible candidate set instead of the global `/search` pool. **Not started, deliberately not required for this checkpoint**: a scoped backend members-search endpoint — local substring filtering over the (small) bounded candidate set was judged sufficient for v1; revisit only if a Space's membership grows large enough for that to become a real UX problem.

Immediately after Domain 9 closes: **Part B — `GET /search` unauthenticated-access security investigation** is explicitly authorized as the next domain, before Item 17. Not started. Backend-owned (`aura-backend/src/search/search.controller.ts` imports `JwtAuthGuard` but never applies it — no global auth guard exists in the app either).

## Founder Acceptance Register — remaining domains OPEN / NOT YET EVALUATED, 2026-08-16

Canonical register: `../aura-backend/capability/FOUNDER_ACCEPTANCE_REGISTER.md`. This repo's owed pieces:

- **Domain 1 — Rich Paste**: live-browser verification owed whenever the founder can perform it personally (`RichPasteField` wired into all 5 composers, ARCHITECTURE/IMPLEMENTATION PASS only). Do not manufacture further widget-harness proof — the existing harness hang was a disclosed, not-yet-diagnosed limitation, not a reason to keep retrying.
- **Domain 5 — Runtime Lifecycle**: `OrphanedSessionDismissalCache` delivered; PRODUCT-BEHAVIOR awaits founder live verification of the reload/restart/session-ends matrix.
- **Domains 9-12**: OPEN / NOT YET EVALUATED, no work started in this repo.
- Do NOT begin Item 17.

## Realtime Architecture Correction — Phase 1 CLOSED in aura-backend (backend-only, zero work in this repo); Phase 2 named next, NOT started, NOT authorized to begin automatically

Phase 1 (Backend Canonical Lifecycle / Participant Truth) is conditionally approved and locally certified in `aura-backend` only — see `../aura-backend/docs/2026-08-14-realtime-architecture-correction-phase1-implementation.md`. Amended Gate 2 (guest disconnect investigation + 107-migration disposable replay) resolved same day; Gate 2 was APPROVED there — committed `214e48e`, pushed to `origin/main`. No `aura_final` file changed at any point in this chapter, including the amendment; the canonical Dart contracts in `lib/core/realtime_canonical/` remain unchanged from Phase 0. Backend Phase 1 is committed and pushed. Phase 2 (event contract dual-emit, which WILL eventually touch this repo's event-consuming code) can be authorized.

## Realtime Architecture Correction — Phase 0 CLOSED (contracts + tests + JOIN_FAILED/SESSION_FAILED doctrine + governed docs)

Architecture document: `../aura-backend/capability/REALTIME_ARCHITECTURE_CORRECTION_LONG_TERM_ARCHITECTURE_AND_MIGRATION_PLAN.md`, now **ARCHITECTURE APPROVED — FROZEN**, all six §18 decisions resolved (two-axis lifecycle approved; Meetings separate-orchestrator recommendation approved but its implementation stays deferred/last; Phase 7 sequencing stays last; iOS CallKit/PushKit is its own future roadmap chapter, not core; `PresenceService` treated as derived/acceleration-only pending production observability; event-contract renaming approved via dual-emit). Phase 0 delivered pure, isolated, executable canonical contracts + a 33-scenario deterministic test harness in `lib/core/realtime_canonical/` + `test/realtime_canonical/` (mirroring `aura-backend/src/realtime/canonical/` 1:1), plus the compatibility/migration contract document `../aura-backend/capability/REALTIME_ARCHITECTURE_CORRECTION_PHASE_0_COMPATIBILITY_MIGRATION_CONTRACT.md`. Full detail: `HANDOFF.md`'s matching entry.

**Explicit stop point, per the founder's Phase 0 directive**: Phase 1 (backend canonical lifecycle production wiring) does NOT begin automatically — this chapter stops here for founder Gate 1/Phase 0 closeout review. Nothing in Phase 0 is wired into any production controller/provider/widget on either side.

**Closeout, 2026-08-14**: the JOIN_FAILED/SESSION_FAILED naming question is resolved (JOIN_FAILED participant-scoped; new `sessionFailed` event for genuine session-level failure), proven by 4 new regression tests. The canonical architecture documents moved into governed version control at `aura-backend/capability/REALTIME_ARCHITECTURE_CORRECTION_LONG_TERM_ARCHITECTURE_AND_MIGRATION_PLAN.md` + `aura-backend/capability/REALTIME_ARCHITECTURE_CORRECTION_PHASE_0_COMPATIBILITY_MIGRATION_CONTRACT.md` (backend-owned, this repo references). **Zero founder decisions remain open from Phase 0.**

**Explicitly flagged as safe to do independently, low-risk, low-cost, no dependency on the rest of the plan**: Phase 6 (Meeting attendee-context link-generation fix — 3 files: `booking_confirm_screen.dart`, `keep_meeting_screen.dart`, `meeting_detail_screen.dart`) — still not started, remains available to pull forward whenever prioritized.

## ONE combined founder certification checklist — second pass, 2026-08-14 (Lifecycle Convergence + everything from the first pass)

The founder's first certification pass on `cd256d3` found 3 of 4 scenarios still failing. Root causes for two of them are now proven and fixed (see `CURRENT_STATE.md`). This is the checklist for the second pass — do not test items separately:

1. **Thread call — successful accept**: repeat normal accept cycles — confirm the call connects cleanly with **no** "Call ended" / Retry-Dismiss appearing alongside a working connection. (Root cause was a sticky local error state with no live reproduction re-captured post-fix — this is the item most worth watching closely.)
2. **Thread call — natural expiry, BOTH sides**: let a call ring to natural expiry (~95s) without answering. Confirm the **receiver's** ring clears (already known-working) AND the **caller's** ringing/connecting screen also reconciles to a terminal state — this is the specific asymmetry that failed last time and is now fixed at the exact line that excluded the caller from the broadcast.
3. **Thread call — accept spinner**: repeat several accept cycles — confirm none return to an unresolved spinner. If this still happens, it needs its own fresh live trace (not another patch) — the transport ownership repair addressed one proven concurrency defect, but a second, separate spinner recurrence was also reported and not independently root-caused this round.
4. **Thread call — caller cancel**: still expected to PASS (unchanged, already confirmed healthy) — quick sanity check only.
5. **Meetings**: a booked or invited Aura member opens their meeting and joins — confirm no redirect to Institution Sign In.
6. **Android ring notification**: confirm it clears on caller-cancel and on natural expiry, not just in-app state.

**Corrected 2026-08-16, Realtime Architecture Correction Phase 4 Gate 2**: this line previously stated this checkpoint blocks iOS Firebase/APNs Confirmation, Runtime Lifecycle Phase 2, Selection/Clipboard/Rich Paste, and Legacy Global Runtime Overlay Cleanup outright — that framing is stale relative to the founder-confirmed release doctrine and roadmap sequencing (`aura-backend/capability/AURA_RELEASE_CLIENT_CONSOLIDATED_ROADMAP.md`). This device-certification pass remains mandatory before release and is the direct evidence dependency for Runtime Lifecycle Phase 2's scoping specifically (its scope was always deliberately left undefined pending this evidence). It is not a blanket gate preventing the Realtime Architecture Correction's remaining phases, or the other named post-Realtime roadmap items, from proceeding architecturally — all are independently MANDATORY per the consolidated roadmap, on their own dependency/execution-order terms, not chained behind this one checkpoint.

## Thread Call Lifecycle Convergence — implemented this session, founder retest owed (item 3, accept spinner recurrence, may still need its own trace)

Full detail in `CURRENT_STATE.md`/`DECISIONS.md`. Fixed: (1) natural-expiry caller propagation — `maybeEndIdleSession()` already had the correct logic but its caller-facing broadcast was silently excluded by `broadcastCallTerminal`'s actor-exclusion design; now broadcasts directly. (2) Stale join-error precedence — `_joinError` is no longer sticky; a new pure function `joinErrorIsStale()` invalidates it the moment authoritative JOINED truth exists for that exact session. New tests: 3 backend (caller reconciliation + multi-party non-termination), 5 frontend (`joinErrorIsStale` precedence). **Not independently re-confirmed via a fresh live device cycle this session** — proven by precise code tracing (the natural-expiry root cause is pinned to an exact line) and test coverage, per the founder's explicit instruction not to cycle through more broad live testing mid-repair.

## Thread Call Transport Ownership — permanent root repair, implemented + live-verified this session

Full detail in `CURRENT_STATE.md`/`DECISIONS.md`. Root cause: two independent, desyncable reconnect-decision guards let concurrent join attempts destroy each other's in-progress socket connections. Fixed with a genuine single-flight transport-establishment owner (`lib/core/concurrency/single_flight.dart`), removing every other independent reconnect path. Live-verified via a real call (founder's browser → adb-installed Pixel APK): single-attempt, ~1.3s signaling, zero churn. New tests: `test/single_flight_test.dart`, `test/realtime_socket_service_test.dart`. Superseded and replaced the earlier "Permanent Call Lifecycle Reconciliation" join-retry epoch fix below, which the founder found insufficient after a repeat reproduction.

## Meetings attendee-join router regression — restored this session, founder retest owed

Root cause (full detail in `CURRENT_STATE.md`/`DECISIONS.md`): `router.dart`'s institution-access gate applied a blanket rule to every `/institution/:id/...` path, never carving out Meetings' institution-namespaced attendee routes (added 2026-07-11, for URL context only). Proven not a recent regression — predates Identity Foundation Phase 1 and every shared-runtime change made this session. Fixed at the router-classification boundary only; zero Meetings-file changes; backend untouched (never institution-actor-gated). New test `test/router_institution_access_test.dart`.

## Permanent Call Lifecycle Reconciliation (2026-08-14, earlier this session) — superseded by Transport Ownership repair above

The join-retry epoch guard fixed a real, narrower race (a superseded attempt clobbering a newer one's *state*), but did not address the deeper transport-churn defect the founder later proved via reproduction. Kept as-is (still correct, still needed) — the Transport Ownership repair above builds on top of it, it does not replace it.

## Native Background/Terminated Notification Certification — Phase A/B/C/D COMPLETE, repair committed/pushed, founder device certification pending

Status: audit + test matrix + evidence reconciliation + founder-approved repair, all complete. Backend record: `../aura-backend/docs/2026-08-14-native-background-terminated-notification-certification.md`. **Committed `74d7875`, pushed to `origin/main`** — a controlled commit/push for founder device certification, not chapter closeout; founder post-deployment device certification remains PENDING. Implemented on this repo's side: `RealtimeState.acceptedByPeer`/`isPeerAcceptedNotYetPresent` + `call:accepted` WS handling (caller-stuck-Connecting fix — the backend-side single point of failure identified in Phase C is now closed by a real caller-facing signal); `AuraIncomingLiveLayer` foreground sound+haptic (`SystemSound`+`HapticFeedback`, reusing the bridge's existing dedup); `RealtimeMediaService.setSpeakerphoneEnabled()`/`RealtimeController.toggleSpeakerphone()`/`_CallControlDock` speaker button (mobile-native only, Meetings untouched). Certification: `flutter analyze` clean, practical suite 190/190 (up from 178), `flutter build web --release` succeeded.

**Remaining after this chapter:**

1. iOS Firebase/APNs confirmation (next named chapter, not started) — add missing `ios/Runner/GoogleService-Info.plist`; decide FCM-registration vs. reviving the raw APNs path.
2. Android `CALL_CANCELLED` stale-notification gap — remains OPEN, not resolved by this repair (no founder observation exists for that exact scenario).
3. Chrome double-notification — remains OPEN/NOT ADJUDICATED (two unadjudicated candidates).
4. Runtime Lifecycle Phase 2 — not started, scope pending evidence.
5. **Platform-Wide Selection, Clipboard & Rich Paste** — NEW, recorded 2026-08-14, doctrine/scope only, zero implementation. Native text-selection/copy/cut/paste across DMs/Thread/Institution Space messages/Member+Institution Posts/Announcements; rich clipboard paste (image/video/audio/document) in messages/composers must route through the existing governed media/attachment pipeline, never a parallel upload path.
6. **Legacy Global Runtime Overlay Cleanup** — NEW, recorded 2026-08-14, doctrine/scope only, zero implementation. Trace/retire the vague global bottom overlay; route legitimate feedback to its correct targeted owner (call lifecycle, personal notification, targeted post notification, future Institutional Attention, or local snackbar) — do not build a second global overlay.

Neither #5 nor #6 reorders this list — recorded so they are not lost, not scheduled as next.

## Communication Timeline Authority — Phase 1 — COMPLETE, committed, pushed

Status: implemented, certified (analyzer clean, practical suite 178/178, web build, real widget tests against the previously-zero-coverage production `ActivityScreen`), founder Gate 2 approved, committed `38765bc` ("feat: establish communication timeline authority phase 1"), pushed to `origin/main` (`6e1f7aa..38765bc`). Chapter closed. Backend record: `../aura-backend/docs/2026-08-13-communication-timeline-authority-phase1-implementation.md`.

All six founder decisions from the 2026-08-12 investigation resolved and frozen backend-side (see `../aura-backend/DECISIONS.md`).

Carried forward, not part of this chapter, unscoped/unprioritized:

1. Outcome-specific icon coloring in Activity — the leading-icon widget doesn't receive enough data today (only `type`, not the full item); a separate, larger change, not currently scoped or requested.
2. Deep-pagination Timeline merge (page 2+ of Activity) — backend-side scope limit, disclosed not fixed.

**Institutional Attention Authority — doctrine FROZEN, founder-approved, zero unresolved decisions** (`../aura-backend/docs/2026-08-13-institutional-attention-authority-proposal.md`), backend doctrine, no frontend implication yet. When authorized: a dedicated Institution Attention / Inbox surface inside Institution Workspace, distinct from the personal global bell (frontend implication for a future chapter, not this one). Not started, not scheduled.

Per founder instruction: **Stop at Gate 2.**

## Compose Link Intelligence / OG Preview — Phase 1 — COMPLETE, committed, pushed

Status: implemented, certified (analyzer clean, practical suite 172/172, web build, real widget tests against all three production composer screens), founder Gate 2 approved, committed `6303882` ("feat: establish link intelligence phase 1"), pushed to `origin/main` (`9d0d558..6303882`). Chapter closed. **Final scope: Member Posts + Institution Posts + Institution Announcements.** Backend record: `../aura-backend/docs/2026-08-12-compose-link-intelligence-og-preview-phase1-implementation.md`.

Resolved during this chapter: the founder reviewed the original Member/Institution-Posts-only report and explicitly approved extending the identical capability to Institution Announcements before closing.

Carried forward, not part of this chapter, unscoped/unprioritized:

1. Comprehensive composer test coverage beyond Link Intelligence (topic picker, media upload, cross-post, draft autosave timing, discard, reply threading — across all three composers now) — explicitly out of this chapter's scope, recommended as its own future chapter, not started.
2. The compact `_AnnouncementCard` list-view summary row (`announcements_screen.dart`) has no link-preview rendering (thumbnail-only layout, deliberately left unwired) — a candidate for a future presentation-layer pass, not currently scoped or requested.

Next authorized chapter, named, NOT started: Communication Timeline Authority — Phase 1.

## Identity Foundation Phase 1 — COMPLETE, committed, pushed

Status: implemented, certified end to end (including institution-space member selection, the founder's required second-pass scope), founder Gate 2 approved, committed `56a0bb7`, pushed to `origin/main`. Record: `../aura-backend/docs/2026-08-11-identity-foundation-phase-1-implementation.md`.

Both founder decisions from the 2026-08-11 continuation resolved: (1) DOB stays capture-only, no age policy; (2) institution-space member selection implemented end to end via `MemberPickerField` + the extracted canonical `directory_entry.dart` model, proven by `test/institution_spaces_screen_test.dart`.

Remaining:

1. Founder decision on whether a minimum-age/eligibility policy is required — not implemented, not inferred, genuinely open (the only founder decision still outstanding for this chapter).
2. Founder production observation after deployment/release.

Deferred, not part of this chapter: consolidation of the several duplicate identity-extraction helpers (`CorrespondenceIdentity` and per-screen `_extractMembers`/`_IdentityAvatar` implementations in `space_screen.dart`/`conversations_screen.dart`/`correspondence_hub_screen.dart`/`messages_hub_screen.dart` — real duplication, out of this chapter's narrow scope; `directory_entry.dart` is the natural future consolidation target).

## Correspondence entry flow

Status: implemented, founder Gate 2 approved, committed, and pushed as `7a47fefe5924ea19a1e483475182d72383b10687`. Record: `docs/2026-08-08-correspondence-entry-flow-repair.md`. (Continuity correction 2026-08-11: previously read "commit/push requires founder authorization" — stale, already happened.)

Remaining gate:

1. Founder production observation after deployment/release.

Selection-stability defect this repair actually fixed is distinct from the identity-resolution defect tracked under Identity Foundation Phase 1 below — do not conflate the two.

Deferred enhancements outside this repair: richer shared-space mode education, Activity/timeline work, and any broader public-space taxonomy changes.

## Communication Continuity & Presence platform architecture

Status: Device Communication Presence Phase 1 and Notification Delivery Authority Phase 1 are backend-implemented, founder Gate 2 approved, committed, and pushed. Records:

- Discovery: `../aura-backend/docs/2026-08-08-communication-continuity-presence-platform-architecture.md`.
- Chapter 1 contracts: `../aura-backend/docs/2026-08-08-communication-continuity-presence-chapter-1-contracts.md`.
- Device Presence Phase 1: `../aura-backend/docs/2026-08-08-device-communication-presence-phase-1-implementation.md` (commit `3bf8d67`).
- Notification Delivery Phase 1: `../aura-backend/docs/2026-08-09-notification-delivery-authority-phase-1-implementation.md` (commit `b23ff44`).

(Continuity correction 2026-08-11: this section previously said "pending founder Gate 2/commit authorization" — both chapters were already committed and pushed before this correction.)

No Flutter implementation was required for Device Presence Phase 1 or Notification Delivery Authority Phase 1. Current Flutter contract remains existing join/decline endpoints, existing socket events, existing push payloads, and existing notification tap/deeplink behavior.

Founder doctrine decisions are resolved. Identity Foundation Phase 1 is the founder-prioritized next chapter (in progress as of 2026-08-11 — see the Identity Foundation section below).

Mandatory before Desktop/Android/iOS production release:

1. ~~Device Communication Presence Phase 1.~~ Committed and pushed (`3bf8d67`).
2. ~~Notification Delivery Authority Phase 1.~~ Committed and pushed (`b23ff44`).
3. ~~Identity Foundation Phase 1.~~ Complete, committed and pushed (`56a0bb7`), 2026-08-11.
4. Compose Link Intelligence / OG Preview Phase 1.
5. Native background/terminated notification certification.
6. Communication Timeline Authority Phase 1.
7. iOS Firebase/APNs configuration confirmation.
8. Meetings preservation certification for any shared authority implementation.

Communication Runtime Lifecycle Phase 2 can remain later only if current native lifecycle health remains certified and no blocking runtime defect is found.

## Pre-release connected-system health gate

Status: complete. Record: `docs/2026-08-08-pre-release-connected-system-health-audit.md`.

Current verdict: READY WITH NON-BLOCKING RISKS for founder-directed native test builds. Do not start build/release pipelines without founder direction.

Non-blocking risks to carry into build planning:

1. Confirm `FIREBASE_IOS_CONFIG_BASE64` is current in the iOS CI/build environment; local Windows source intentionally does not include `ios/Runner/GoogleService-Info.plist`.
2. Use the certified `C:/flutter` safe-directory environment override for local Flutter verification in this sandbox until host-level Git config is normalized.
3. Native runtime certification remains founder/device work after test builds.

## Canonical Flutter Thread-Call Lifecycle - Stage 1

Status: implemented, locally certified, committed, and pushed as `86de6e165931e96185a2e78a349bb5502065940a`. Blueprint/design record: `docs/2026-08-08-canonical-flutter-thread-call-lifecycle-stage-1-blueprint.md`.

Frozen scope:

- foreground incoming-call ownership;
- caller/callee realtime synchronization;
- app-root Thread-call lifecycle owner;
- one active call intent keyed by `sessionId + current user`;
- existing `RealtimeController` remains the realtime socket/media/session owner;
- root-mounted incoming-call presentation;
- client-only Thread call phases for presentation/runtime.

Deferred: Activity doctrine, multi-device accept/decline arbitration, desktop native notifications, Android/iOS background and terminated push handling.

Meetings hard gate: no Meeting behavior change. If shared `RealtimeController`, `RealtimeState`, `RealtimeSocketService`, `RealtimeMediaService`, or route behavior must change, add Meeting regressions and preserve waiting room, admission, guest handling, host controls, Meeting reconnect, leave/end, Meeting UX, and Meeting notification semantics.

Remaining Stage 1 gates:

1. Founder-directed platform test builds and live runtime certification.
2. No further local source verification gate is known. The prior Flutter test/build hang was traced to Flutter SDK Git safe-directory/tool startup and certification now passes when commands are run with the explicit `C:/flutter` safe-directory environment override.

Closed Stage 1 decisions:

1. Root owner placement is `AuraApp` through `ThreadCallLifecycleHost` under the existing notification/app boundary.
2. Shared realtime touch boundary was preserved. `RealtimeController`, `RealtimeState`, `RealtimeSocketService`, `RealtimeMediaService`, and generic realtime route behavior were not edited.

## Thread Calling Reliability - Flutter repair program

Status: read-only collective audit recorded in `../aura-backend/docs/2026-08-08-thread-calling-reliability-collective-audit.md`. No Flutter application/runtime/schema/client code was edited.

Do not reopen backend Reachability Authority, Session Continuity Authority Phase 1, or Canonical Call Notification Stage A from this item. Do not modify Meetings without explicit proof and regression coverage that current Meeting behavior is unchanged.

1. ~~Founder decision required - shared foreground call consumer ownership.~~ **Implemented, certified, committed, and pushed in Stage 1.**
2. ~~Founder decision required - caller/callee synchronization pass.~~ **Implemented, certified, committed, and pushed in Stage 1 as Thread-specific lifecycle coordination over existing `RealtimeController` outputs.**
3. **Founder decision required - Activity doctrine for active calls.** Activity currently reads `/notifications`; Stage A calls create Communication rows. Coordinate with backend before changing Flutter Activity behavior.
4. **Founder decision required - multi-device doctrine.** Current backend rings all eligible devices but allows one same-user media owner by default. Client work must honor the final accepted/replaced/terminal synchronization doctrine.
5. **Platform-specific notification work remains later.** Desktop native push is absent; Android/iOS background and terminated notification display require separate native release work after foreground lifecycle is resolved or explicitly deprioritized.

## Current remediation follow-up

1. ~~Complete Flutter test-suite verification from a healthy runner.~~ **RESOLVED, 2026-08-02**: `flutter test` (full suite, 76 tests) and `flutter analyze` both ran cleanly to completion in this same Windows workspace during the cold-deep-link investigation below — the earlier "hangs before test output" symptom did not reproduce. 1 pre-existing, unrelated failure (`governed_tag_persistence_test.dart` — a stale username fixture, confirmed present on a clean `git stash` of unrelated changes) and 1 pre-existing, documented golden-test skip (`realtime_room_golden_test.dart`) remain; neither is new.
2. After deployment, production-verify post draft discard, token-only draft suppression, topic enforcement, member edit, and institution edit with seeded production-like accounts.
3. Re-verify the Railway push-to-deploy behavior before relying on it for a release.
4. After the edit-save/mention fix deploys, production-verify member edit save, institution edit save, keyboard mention selection, and mouse/touch mention selection.

## Accepted future enhancements (unprioritized, explicitly not part of AXR-1)

1. Topic-scoped search results view. `#Topic` tap-through seeding general search (`/search?q=%23Topic`) is accepted as AXR-1's final behavior. A dedicated view that filters specifically by topic tag remains a future UX improvement.
2. Governed tagging in meeting notes, once a meeting-notes composer widget exists. When that composer is built, wrap its field in `GovernedTagAutocomplete` per the established pattern.
3. Meetings/Mentions local badge destinations, if Profile -> Participation -> Meeting History or an equivalent is ever built. `module_attention.dart` already computes both counts; only the nav destination to attach them to is missing by founder ruling.

## Residual founder editorial items (from ROS Phase II closeout, 2026-07-13)

1. Two live announcements on Aura Platform's own institution feed show raw `[OFFICIAL:ANNOUNCEMENT]` tag syntax in their titles.
2. Aura Platform's own institution profile banner is stock-photo buzzword imagery ("2050 AND BEYOND"), plus a comic-meme official post.
3. "Founder & Steward" booking-page title is backend/profile data, not frontend source.

## Recorded technical items (unprioritized)

- 3 pre-existing lints in `create_meeting_screen.dart` (recorded 2026-07-11).
- **RESOLVED (does not reproduce), 2026-08-02 — Cold deep-link reload redirects an authenticated session to `/login`.** Originally recorded 2026-08-02 as an incidental, unconfirmed finding (see prior text below). Direct investigation traced the full chain — `router.dart`'s `redirect` callback, `authStatusProvider`/`sessionBootstrapProvider` (`session_providers.dart`/`session_bootstrap.dart`), and `TokenStore` (`auth_providers.dart`) — and then reproduced the exact described scenario live: a `flutter build web` release build served with an SPA-fallback static server, driven by real browser navigation (confirmed via `performance.getEntriesByType('navigation')` to be a genuine top-level document load, not an SPA-internal route change) against a local mock backend whose `/auth/refresh` carried an artificial 3-5s network delay to widen the race window.
  - **Root cause finding: the suspected race does not currently exist.** `authStatusProvider` (`session_providers.dart:59`) already gates on `sessionBootstrapProvider`'s own loading state (`if (boot.isLoading) return AuthStatus.loading`), and `router.dart`'s `redirect` treats that as `isBootstrapping` and parks the app on `/_boot` (a spinner) until bootstrap resolves — never touching `/login` while a restore is in flight. `git log` confirms this exact mechanism was added by commit `d9c7cef` ("fix(auth): implement auth bootstrap gating + 3-state emailVerified + **prevent 401 bootstrap race**"), dated 2026-05-03 — about three months **before** this defect was observed on 2026-08-02. The fix already existed when the bug was seen.
  - **Empirical verification (real browser, real cold reload, artificial network delay)**: (1) valid session, cold reload on `/home` — correctly held on `/_boot` for the full delay window, then rendered the authenticated home page, confirmed via `RuntimeTrace` console output showing `authStatus` staying at its pre-existing state through the delay and only transitioning once `sessionBootstrapProvider` actually resolved; (2) valid session, cold reload on an institution-gated route (`/institution/:id/dashboard`, which additionally awaits `institutionAccessProvider`) — correctly waited, then correctly routed to `/enter-institution` (accurate "no access" outcome, not a bogus `/login` bounce); (3) a genuinely invalid/expired session (mock `/auth/refresh` returns 401) — correctly, and only after actually attempting the refresh, redirected to `/login?redirect=<original>`. All three match required behavior exactly; none reproduce the reported defect.
  - **One genuine false-positive during this investigation, recorded for anyone repeating it**: restarting the local mock backend process mid-test (to change its artificial delay) reset the mock's own in-memory "logged in" flag, causing a legitimate 401 on the next `/auth/refresh` call — which correctly cleared the client's session hint and correctly redirected to `/login`. This looked identical to the reported bug at first glance but was a test-harness artifact, not an app defect; it is called out here because it is exactly the kind of false signal that could produce a plausible-looking "confirmed reproduction" without being real.
  - **No code fix applied** — per "repair only the actual defect," inventing a change for a non-reproducing race would itself be a defect. Added `test/session_bootstrap_race_test.dart` (3 tests, `ProviderContainer`-based, no widget/network dependency) that locks in the exact invariant the router's redirect logic depends on: `authStatusProvider` reports `loading` (never `unauthed`) while `sessionBootstrapProvider` is in flight, and correctly resolves to `authed`/`unauthed` once it settles, including for an expired persisted token. This gives the mechanism a fast, deterministic regression guard so a future real regression here is caught at the provider level rather than only by a live reload.
  - Original recorded text (2026-08-02, prior to investigation): "Found incidentally while verifying messaging calls through the real web UI (see `../../aura-backend/audit/working-directory/NEXT_WORK.md`'s 'Realtime Reproduction and Capacity Enforcement' closure) — not investigated or repaired as part of that task. Observable behavior: a logged-in session that reaches a deep route via normal in-app navigation (e.g. clicking into a thread) works correctly; the same route loaded via a hard page reload or a fresh navigation directly to that URL (bookmarked link, browser refresh, a pasted deep link) redirects to `/login?redirect=<original path>` even though the session is still valid — confirmed by immediately re-navigating in-app afterward with no re-login required. Likely surface ownership: client-side, almost certainly the router's auth-redirect guard (`router.dart`) running its authenticated/not-authenticated check before the session-hydration path (`session_bootstrap.dart`, `SharedPreferences`-backed) has resolved on a cold load — a hydration-race pattern, not a real logout or token-invalidity issue. Unconfirmed without direct investigation; not investigated further per task scope." If this resurfaces, it is most likely either a genuinely expired/invalid session (item behaves correctly per case 3 above) or a backend-side session/cookie issue, not this client-side race.

## Explicit non-work

- Live room internals (`lib/features/live/` room UI) are frozen; do not restyle.
- Nothing under `../../orchestrate/`.
