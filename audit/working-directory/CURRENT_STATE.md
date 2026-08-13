# Current State — aura_final

Last updated: 2026-08-16 UTC (**Item 15 (Rich-Text Composition + Structured-Content Boundary) DELIVERED same day** — new `lib/core/rich_content/` (inline markdown tokenizer + span builder) wired into the single shared `ResolvedTagText` widget, automatically covering Posts/Institution Posts/Thread-Space messages/DMs; DM composer gained `GovernedTagAutocomplete` (previously none) and the DM bubble now renders via `ResolvedTagText` (previously bare `Text`) for structured `@mention` support end to end. 26 new tests, full 361-test suite + `flutter analyze` clean. Full detail canonical in aura-backend's roadmap doc, Item 15 subsection. **Item 14 (Internal Link Hydration) DELIVERED** — new `lib/core/link_preview/internal_reference_card.dart` and `display_link_preview.dart` wired into all 5 composer surfaces + all 4 display surfaces that carry `linkUrl`; internal Aura links now resolve a live, per-viewer, canonical-authority-sourced preview instead of rendering as a bare "open externally" chip. 13 new tests, full 335-test suite + `flutter analyze` clean. Full detail canonical in aura-backend's roadmap doc, Item 14 subsection — this repo does not duplicate it. Realtime Architecture Correction — Phase 4 (Notification/Ringing Projection Migration) CLOSED, founder-approved, committed `e344dbc` (paired backend `b359a66`), pushed — see below. `SESSION_CANCELLED`'s canonical wire name corrected to `session.cancelled` (was `participant.cancelled`, a pre-existing backend inconsistency) — `realtime_socket_service.dart` and `incoming_call_projection.dart` updated to match. Consolidated Release-Client Roadmap canonical in aura-backend's `capability/AURA_RELEASE_CLIENT_CONSOLIDATED_ROADMAP.md` (this repo references, does not duplicate) — every founder-confirmed item RELEASE REQUIREMENT: MANDATORY, release doctrine FROZEN. Next Realtime phase: Phase 5 (Institution Space adapter), not started. Phase 3 CLOSED, founder-approved, committed `2bf0367`/backend `bb53e1e`, pushed. Phase 2 CLOSED in aura-backend. Phase 1 remains CLOSED (committed `214e48e`, pushed). Thread Call Lifecycle Convergence code fixes remain landed/pushed below; founder combined certification still PENDING)

## Realtime Architecture Correction — Phase 4 (Notification/Ringing Projection Migration) CLOSED, 2026-08-16 — founder-approved, committed `e344dbc`, pushed

Full record (canonical, aura-backend-owned): `../aura-backend/docs/2026-08-16-realtime-architecture-correction-phase4-implementation.md`. This repo's changes: new `lib/features/realtime/application/incoming_call_projection.dart` — the ONE shared projection authority consolidating two previously-independent, already-drifted duplicate classifier implementations (`incoming_live_overlay.dart` and `notification_bridge.dart` each carried their own copy of call-kind/session/terminal-state resolution) into one shared, tested module, plus a new session-scoped `IncomingCallPrecedenceGuard` (bounded tombstone set) closing a genuine gap: nothing previously prevented a late/reordered incoming-call delivery from resurrecting a ringing card after that session's terminal truth (accepted/declined/expired/cancelled/ended) had already arrived. `IncomingCallBridgeNotifier` (`incoming_call_bridge.dart`) now wires the guard into `addIncoming`/`removeBySession`/`remove`/`evictExpired`/`clear`, and both its socket listeners now route through `projectCallPresentationEvent` instead of hardcoded per-event-name branches. `RealtimeSocketService`'s event whitelist gained the canonical dot-case wire names (`invite.issued`, `participant.accepted/declined/expired/cancelled`, `session.ended`) — previously silently dropped by the explicit `socket.on(name, ...)` per-name registration even though the backend already dual-emitted them since Phase 2/3.

`_joinError`/`_joinErrorSessionId` (`joinErrorIsStale`) and `_joinFutures` (`ThreadCallLifecycleController`) both reviewed and **not removed** — confirmed still correctly scoped to their own distinct concerns (join-failure presentation precedence; single-flight join dedup), not superseded by this phase's ringing-presentation precedence work. Android native `aura_calls` channel / `MainActivity` tag matching / the single-choke-point `cancelNativeCallNotifications()` call confirmed already correct, zero native/Kotlin code touched. iOS documented honestly (FCM-only registration, no CallKit/PushKit, blocked by the separately-tracked missing `GoogleService-Info.plist`) — no iOS work performed.

New tests: `test/realtime/incoming_call_projection_test.dart` (17 pure-function tests, including the amended Gate 2's wire-name correction test) + `test/realtime/incoming_call_bridge_precedence_test.dart` (6 integration tests against the real `IncomingCallBridgeNotifier`) — 23 total, covering the founder's 20-scenario test matrix.

Certification: `flutter analyze` clean (full project). Practical suite **279/279 (1 pre-existing golden skip, unrelated)**, up from prior baseline with 22 new Phase 4 tests included. Backend: 125 suites/1642 tests, AppModule smoke-boot passing, tsc/build/prisma-validate/git-diff-check clean (see aura-backend's own continuity docs for full detail).

**LOCALLY CERTIFIED. GATE 2 — awaiting founder review. NOT committed, NOT pushed.** No Meetings orchestrator work begun, no CallKit/PushKit work begun.

## Realtime Architecture Correction — Phase 3 CLOSED, 2026-08-16 — one Dart file + one new test file, mirrored from aura-backend's reconciliation, committed `2bf0367`, pushed

`lib/core/realtime_canonical/session_lifecycle.dart`'s `sessionTransitions` map gained the identical `active -> cancelled` edge as the backend's `session-lifecycle.ts` (see `../aura-backend/docs/2026-08-16-realtime-architecture-correction-phase3-implementation.md`'s amended Gate 2 section for the full mechanical proof) — both languages' Phase 0 contracts remain in lockstep, per that file's own "do not let the two drift" doctrine. New `test/realtime_canonical/session_cancelled_reachability_doctrine_test.dart` (6 tests) mirrors the backend's equivalent spec exactly. Full `test/realtime_canonical/` suite re-verified: 43/43 passing (37 pre-existing + 6 new). No other Dart file touched — `RealtimeController`/`ThreadCallLifecycleController`/`AuraIncomingLiveLayer` remain untouched, per the original Phase 3 submission's frontend audit (not rewritten). **Not committed/pushed — mirrors the backend's own not-yet-committed state.**

## Realtime Architecture Correction — Phase 3, 2026-08-16 — backend-only, no aura_final code change (frontend AUDITED, not rewritten)

Caller-cancellation doctrine implemented entirely in `aura-backend`. Full record: `../aura-backend/docs/2026-08-16-realtime-architecture-correction-phase3-implementation.md`. **Zero Dart file touched** — the existing single `endCall()` action in `realtime_controller.dart` needs no change: the backend now transparently classifies CANCELLED vs ENDED and deliberately preserves the same legacy `session:ended` socket event either way, so the existing `case 'session:ended': case 'call:terminal':` handler already tears down the UI correctly for both outcomes. Frontend state ownership was audited this phase (see the backend record's Part G) — `RealtimeState`/`ThreadCallLifecyclePhase` confirmed AUTHORITATIVE/DERIVED as designed; `AuraIncomingLiveLayer._joining`/`_joinError`/`_joinErrorSessionId` and `ThreadCallLifecycleController._joinFutures` remain disclosed, not-yet-verified `REMOVE` candidates — NOT removed this phase (full removal needs a typed FAILED-reason projection from `RealtimeState`, a real future refactor, not speculative removal). **Stopped at local certification in aura-backend, NOT committed/pushed (feature work), Phase 4 not started.**

## Realtime Architecture Correction — Phase 2, 2026-08-15 — CLOSED in aura-backend, backend-only, no aura_final change

**Final closeout**: founder approved the amended Gate 2 subject to one correction — `SESSION_CANCELLED` canonical production is Phase 3 (Thread/DM Orchestrator Migration) scope, not Phase 4. Phase 3/4 renumbered accordingly (Phase 3 = Thread/DM Orchestrator Migration, now also owns establishing authoritative caller-cancellation truth; Phase 4 = Notification/Ringing Projection Migration, consumes that truth). Full record: `../aura-backend/docs/2026-08-15-realtime-architecture-correction-phase2-implementation.md` §23. **When Phase 3 is authorized, it will be the first realtime chapter to touch this repo's `RealtimeController`/`AuraIncomingLiveLayer`/`ThreadCallLifecycleController`/`incomingCallBridgeProvider`** (per the architecture doc's §8/§13) — not started, not scheduled.

## Realtime Architecture Correction — Phase 2, 2026-08-15 (original amended Gate 2 entry, superseded by final closeout above) — backend-only, no aura_final change

Canonical event contract consolidation + compatibility migration, implemented entirely in `aura-backend` (new `CanonicalRealtimeEventService`, dual-emit at 9 call sites, additive schema). Full record: `../aura-backend/docs/2026-08-15-realtime-architecture-correction-phase2-implementation.md`. Zero Dart file touched — no frontend consumer of any canonical wire event was wired this phase by explicit scope (`RealtimeController` untouched); every new canonical event is additive and currently unconsumed. Deliberately no change to `lib/core/realtime_canonical/` (the Dart mirror of the Phase 0 pure contracts) — Phase 2 did not touch Phase 0's contracts, only produced them in the backend for the first time. Frontend canonical-event consumption remains Phase 3/4 scope. **Stopped at local certification, NOT committed/pushed in aura-backend, Phase 3 not authorized.**

## Realtime Architecture Correction — Phase 1, 2026-08-14 — backend-only, no aura_final change (incl. amended Gate 2)

Phase 1 (Backend Canonical Lifecycle / Participant Truth) is implemented and locally certified entirely within `aura-backend` — production wiring of the already-frozen Phase 0 canonical contracts into real backend services (session/participant transition owners, the now-producible `RealtimeJoinState.FAILED`, `maybeEndIdleSession`/`leaveSurfaceSession` routed through the extracted aggregate evaluator). An amended Gate 2 the same day resolved two conditions entirely within `aura-backend`: a guest-disconnect lifecycle question (investigated, proven not a doctrine contradiction) and a full 107-migration disposable-Postgres replay (clean). **Zero file in this repo changed at any point**, including the amendment — the Dart canonical mirror (`lib/core/realtime_canonical/`) is untouched because the contracts themselves did not change, only the backend's own production wiring to them. Full record: `../aura-backend/docs/2026-08-14-realtime-architecture-correction-phase1-implementation.md`. Backend Phase 1 is CLOSED — committed `214e48e`, pushed to `origin/main`.

## Realtime Architecture Correction — Phase 0 (canonical contracts + executable test harness), 2026-08-14 — CLOSED

Founder reviewed `AURA_REALTIME_LONG_TERM_ARCHITECTURE_AND_MIGRATION_PLAN.md` (previously produced as a documentation-only proposal) and approved the architecture direction plus all six §18 decisions: two-axis lifecycle APPROVED; Meetings separate-orchestrator recommendation APPROVED but its implementation stays deferred/last, Phase 0 only names the boundary; Phase 7 (Meetings orchestrator) sequencing stays last; iOS CallKit/PushKit is its own future roadmap chapter, not core architecture; `PresenceService` treated as derived/acceleration-only pending production observability, not re-litigated; event-contract renaming APPROVED via dual-emit (not flag-day). The architecture document itself is now updated in place to **ARCHITECTURE APPROVED — FROZEN**, each decision's resolution recorded in §18.

Founder then authorized Phase 0: turn the target contracts named throughout that document into pure, executable, isolated code, proven by a deterministic test harness — explicitly so "the founder must no longer be the primary integration debugger."

**New, isolated directory `lib/core/realtime_canonical/`** (deliberately placed OUTSIDE `lib/features/realtime/` so an accidental production import is visually obvious in review; confirmed not imported by any production file) — a behaviorally-identical Dart mirror of `aura-backend/src/realtime/canonical/`'s TypeScript contracts:

- `session_lifecycle.dart` / `participant_lifecycle.dart` — the same two-axis `CanonicalSessionStatus`/`CanonicalParticipantStatus` enums, legal-transition tables, and `evaluateSessionActivity`/`resolveFirstActionWins` pure functions as the backend.
- `device_socket_binding.dart` — `resolveMediaOwnershipClaim`/`hasAnyLiveOrRecoverableSocket`, mirroring the backend's device/socket/media-ownership layering contract.
- `precedence.dart` — `reconcileParticipantEvent`/`reconcileSessionEvent`, the same stale-event/duplicate-delivery/terminal-absorbing reconciliation rules that generalize this session's two proven bugs (natural-expiry caller-exclusion, sticky `_joinError`).
- `event_contract.dart` — `CanonicalRealtimeEvent` enum + `legacyEventMap`, mirroring the backend's `LEGACY_EVENT_MAP` classification of all 8 current ad-hoc event names.
- `lifecycle_test_harness.dart` — a deterministic, in-memory, Riverpod/Socket.IO-free `LifecycleTestHarness`, structurally identical to the backend's.
- `test/realtime_canonical/lifecycle_scenarios_test.dart` (the same 29 required scenarios as the backend suite) + `test/realtime_canonical/meetings_contract_fixtures_test.dart` (the same 4 Meetings boundary fixtures) — **33/33 passing**. `flutter analyze lib/core/realtime_canonical test/realtime_canonical` clean.

**Companion document**: `../aura-backend/capability/REALTIME_ARCHITECTURE_CORRECTION_PHASE_0_COMPATIBILITY_MIGRATION_CONTRACT.md` — see the paired backend `CURRENT_STATE.md` entry for the full contract-file inventory and the migration mechanics it specifies.

**Explicitly NOT done**: nothing in Phase 0 is wired into any production controller/provider/widget on either side — verified by `git diff` showing only new files under `lib/core/realtime_canonical/`, `test/realtime_canonical/`, and documentation. Phase 1 (backend canonical lifecycle production wiring) is named next but explicitly NOT started, NOT authorized to begin automatically — this chapter stops for founder Gate 1/Phase 0 closeout review per the directive's explicit instruction.

## Realtime Architecture Correction — Phase 0 CLOSEOUT, 2026-08-14 — JOIN_FAILED/SESSION_FAILED doctrine frozen + canonical docs governed

Founder resolved the one remaining open item: **JOIN_FAILED is strictly participant-scoped and must never automatically fail the whole session**; a new `sessionFailed` canonical event was added for genuine session-level failure, applied only as an explicit, non-derived transition. Recorded as doc comments on `CanonicalParticipantStatus.failed`/`CanonicalSessionStatus.failed` in `lib/core/realtime_canonical/participant_lifecycle.dart`/`session_lifecycle.dart`, proven by 4 new tests in `test/realtime_canonical/join_failed_session_failed_doctrine_test.dart` (mirroring the backend's identical suite): one participant JOIN_FAILED doesn't fail a session with another actionable invite; doesn't fail a session with another CONNECTED participant; `evaluateSessionActivity` has no FAILED-deriving path at all; a genuine session-level FAILED remains representable as an explicit `transitionSession` call. Practical suite and `flutter analyze` re-verified clean (33/33 canonical tests including the 4 new ones).

**Canonical documents moved into governed version control** — now live at `aura-backend/capability/REALTIME_ARCHITECTURE_CORRECTION_LONG_TERM_ARCHITECTURE_AND_MIGRATION_PLAN.md` and `aura-backend/capability/REALTIME_ARCHITECTURE_CORRECTION_PHASE_0_COMPATIBILITY_MIGRATION_CONTRACT.md`, replacing the previously unversioned parent-level `docs/architecture/` copies. `aura-backend` owns the canonical source; this repo's continuity docs reference that path, per explicit instruction not to duplicate the full plan into both repos. See the paired backend `CURRENT_STATE.md`/`DECISIONS.md` entries for the full reasoning.

**With this closeout, Phase 0 is fully CLOSED and zero founder decisions remain open from it.** Phase 1 is named next and has explicitly NOT started.

**Unchanged, standing finding from the earlier audit**: Meetings currently has no dedicated backend service or frontend controller — it is entirely `isMeetingSession`/`surfaceType === MEETING` branches inside Thread/DM-owned code. Phase 0's Meetings contract fixtures prove the future orchestrator boundary (admission-vs-transport independence, socket-loss-vs-departure, orchestrator-owned reconnect grace) is representable in the canonical contracts without building the orchestrator itself.

## Thread Call Lifecycle Convergence, 2026-08-14 (code fixes — landed, committed, pushed; supersedes/extends the Transport Ownership repair below after founder certification found it insufficient)

Founder tested the pushed single-flight transport repair (`cd256d3`) directly. Explicit cannot-close instruction: "FOUNDER CERTIFICATION FAILED — CONTINUE END TO END." Results: (1) explicit caller cancel — **PASS**, preserved unchanged; (2) natural invite expiry — **asymmetric FAIL**, receiver's ring cleared correctly at ~95s but the caller remained ringing/connecting indefinitely with no terminal reconciliation; (3) successful accept could still show "Call ended" + Retry/Dismiss simultaneously with a working connection; (4) accept could still return to an unresolved spinner on a separate call. Founder explicitly forbade another isolated UI/timeout/spinner/ringtone patch and required root-cause proof plus a genuine lifecycle-precedence architecture.

**Root cause #1, PROVEN precisely (natural expiry caller propagation) — `correspondence-orchestrator.service.ts`.** `sweepExpiredInvites()` already called `maybeEndIdleSession()`, which already had the correct aggregate check (no remaining PENDING invites, no other ACTIVE/JOINING participant) and already called `endLive({actorUserId: hostUserId, sessionId})` — the caller-reconciliation logic existed and ran. But `endLive` → `broadcastCallTerminal()` **deliberately excludes `params.actorUserId` from the broadcast** (correct behavior for a genuine user-initiated end — the actor already knows they ended it). `maybeEndIdleSession` passes the caller/host as that `actorUserId` to represent "this idle session auto-ended" — not a real action *by* the host — so the one person who actually needed reconciling (the caller, who had been waiting) was the one deliberately excluded by design. This is a different, more precise finding than the initial hypothesis (a `MessagesGateway` namespace mismatch) — that namespace issue is real elsewhere in this file but was not the actual blocker here, since the dead call was never reached in the first place given the exclusion.

**Fix #1**: `maybeEndIdleSession` now calls a new, dedicated `RealtimePolicyService.broadcastNoAnswerTruth(sessionId, hostUserId)` → `RealtimeGateway.broadcastNoAnswer()`, emitting `call:terminal` (`reason: NO_ANSWER`) directly to the caller via `/realtime` (the namespace they're actually connected to — mirrors the already-proven-working `broadcastAcceptedTruth`/`broadcastDeclined` pattern), called *before* `endLive`, independent of `broadcastCallTerminal`'s actor-exclusion. `broadcastCallTerminal`'s own behavior is untouched — still correct for its other (genuine user-action) callers. Zero client-side changes needed: `case 'call:terminal':` in `RealtimeController._handleSocketEvent` already exists, already handles this event unconditionally (regardless of `isJoined`), already session-scopes correctly, and already resets to `joinState: idle` with `'The call has ended.'`.

**Multi-party correctness preserved**: `maybeEndIdleSession`'s pre-existing aggregate check (which this fix sits behind, unchanged) already ensures a caller is never reconciled while another invite remains PENDING or another participant is ACTIVE/JOINING — ONE recipient expiring in a multi-party call does not end the call for the others.

**Root cause #2, best-evidence fix (successful accept coexisting with "Call ended"/Retry-Dismiss) — `incoming_live_overlay.dart`.** `AuraIncomingLiveLayer._joinError` was sticky, uncoordinated local widget state: set on a transient join failure, cleared only by explicit user action (Retry/Dismiss) or the 90s ring-timeout — nothing external (a later successful join for the SAME logical call, e.g. via an automatic reconnect) ever invalidated it. Code-level tracing of the render path (`_isInterruptCandidate`'s "already in `/realtime`" and "already joined this session" guards) shows the *card itself* cannot render once genuinely on the room screen for a joined session — meaning the visually-reported contradiction is consistent with this stale-state class of bug rather than a guard-matching failure, though a fresh live reproduction to pin the exact trigger moment was not obtained (see Not Done below).

**Fix #2**: `_joinError` is now paired with `_joinErrorSessionId`, tracking which session the failure belongs to. New pure, top-level, independently-tested function `joinErrorIsStale({joinErrorSessionId, isJoined, liveSessionId})` implements the founder-mandated invariant precisely: authoritative JOINED truth for a session invalidates stale failure presentation for *that exact session*, without ever suppressing a genuinely different failure (different session, or none). Wired into `build()` as `effectiveJoinError`, computed fresh every render — no risk of stale suppression outliving its relevance.

**Certification**: Backend `tsc --noEmit` clean (2 pre-existing unrelated errors persist, out of scope, unchanged). Backend full suite **115 suites / 1488 tests** (up from 1485, +3 new: last-actionable-invite reconciles caller; pending sibling invite does not terminate caller; already-joined participant does not terminate caller). Frontend `flutter analyze` clean, practical suite **214/214** (up from 209, +5 new: `joinErrorIsStale` precedence tests). Debug APK build succeeded.

**Explicitly NOT touched, per founder instruction**: `session:participant.left` semantics for Thread/DM (no grace period added — evidence still doesn't prove a stale-registration cause, and the founder explicitly forbade reflexive Meetings-style grace); `broadcastCallTerminal`'s actor-exclusion behavior (correct for its other callers — endSession, leaveSession-with-ENDED-result, explicit host end); the transport ownership repair itself (`cd256d3`) — kept as-is, still correct, this work builds on top of it.

**Not done, honestly disclosed**: no fresh live device reproduction of "successful accept + Call ended + Retry-Dismiss" was captured post-fix (the founder's own certification already served as the reproduction evidence for the *symptom*; a live trace pinpointing the exact real-time trigger moment was not additionally obtained, given the explicit instruction not to cycle the founder through more broad testing). No widget-level test exists for `AuraIncomingLiveLayer` itself (same pre-existing gap as the Transport Ownership repair — the precedence *logic* is tested via the extracted pure function, not the full widget). The natural-expiry fix was not live-verified end-to-end this session (requires a ~95s wait per cycle); it is proven by precise code tracing (found the exact exclusion line) and backend test coverage, not an additional live reproduction.

## Thread Call Transport Ownership — permanent root repair, 2026-08-14 (superseded in part by Lifecycle Convergence above — kept, still correct)

Founder-mandated forensic-first repair after the join-retry epoch fix (below) proved insufficient — the founder reproduced the stuck-spinner symptom again after that fix shipped, and demanded root-cause closure before any further symptom-level patching.

**Root cause, proven via live device logs cross-referenced with backend logs.** `RealtimeController.connect()` had its own state-based "already connecting" guard (`state.connectionStatus`), a signal completely separate from `RealtimeSocketService`'s own connect-guard. The two could desync. Combined with the already-known fact that `Future.timeout()` does not cancel an abandoned `_performJoin()` attempt, multiple logical join attempts could each independently reach `RealtimeSocketService.connect()` — which always disconnected and recreated the shared socket — each one destroying a sibling attempt's in-progress connection before it could stabilize. Captured directly: three real join attempts, ~2s apart, each producing an empty socket id, none ever reaching a server-acknowledged `session:join`; cross-referenced against Railway backend logs for the same session confirming zero `session:join` records ever landed for the affected user.

**Permanent architecture.** `RealtimeSocketService.connect()` renamed to `ensureConnected()` and rebuilt as the sole, genuinely single-flight owner of transport establishment, using a new standalone, independently-tested primitive: `lib/core/concurrency/single_flight.dart` (`SingleFlight<T>`) — a Completer-based "first caller owns it, every other concurrent caller awaits the same in-flight operation" utility, generic and reusable beyond realtime. `RealtimeSocketService.isConnected` requires both `.connected` AND a non-empty server-assigned `.id` (an invariant already established in an earlier fix this session, now formally enforced as the transport-readiness gate before any emit). `emitAck()` now throws immediately if called before the transport is ready — a hard invariant, not a silent best-effort wait. Every other independent reconnect-decision point was removed: `_performJoinWithRetry`'s pre-retry "if not connected, reconnect" step, `join()`'s own pre-check before calling `_performJoinWithRetry`, and `_rejoinAfterReconnect`'s own pre-check — `_performJoin`'s own `connect()` call (routing through the single-flight `ensureConnected()`) is now the only path transport establishment can happen through, for every entry point. `_performJoin` also gained additional epoch checkpoints (before transport connect, before `session:join` emit) so a superseded attempt bails out before doing real work, not just before mutating state.

**Live-verified, not just unit-tested.** Placed a real call from the founder's own signed-in browser session (caller) to a locally-built, adb-installed debug APK on the founder's Pixel (callee), with continuous logcat + Railway log capture. Result: `ensureConnected called` → `_establish starting` → `new socket object created` → `connect event received, id=<real-id>` (non-empty, immediate) → `session:join ack received` → `state.isJoined=true` → RTC `Connected` — the entire signaling sequence completed in ~1.3 seconds, single attempt, zero churn, zero empty socket ids, zero retries. Call remained stable 3+ minutes on both sides before being cleanly ended. An earlier "Call ended" toast observed mid-test was traced to a *different*, never-explicitly-ended prior test call left running in the background — not a recurrence of the bug.

**Deterministic regression tests added**: `test/single_flight_test.dart` (5 tests — the exact concurrency property proven: two/three concurrent callers share one in-flight operation, not N; a caller after completion starts a genuinely new one; failures propagate to all waiters then free the slot; `abort()` releases waiters without waiting for settlement) and `test/realtime_socket_service_test.dart` (3 tests — a fresh service reports not-connected, `emitAck` refuses to fire before readiness, `disconnect()` on a never-connected service is a safe no-op).

**Certification**: `flutter analyze` clean (full project), practical suite **209/209** (up from 201, +8 new). `flutter build apk --debug` and `flutter build web --release` both succeeded. Backend: untouched (zero diff), full suite re-run to confirm — 115 suites/1485 tests still passing; two pre-existing, unrelated `tsc` errors noted (not caused by this repair, out of scope).

**Meetings and Institution Space preservation**: not independently live-retested (no dedicated automated coverage exists for either surface in this repo — a pre-existing gap), but preserved by construction — both share the identical non-meeting-branch transport path through `_performJoin`/`ensureConnected()`; the only surface-specific branching (`isMeetingSession`) was not touched.

**Call Ended / Retry-Dismiss while joining**: per the founder's explicit instruction, `session:participant.left` semantics were NOT touched in this repair — the founder's own evidence review concluded the captured instance belonged to the caller's real, single, healthy socket via an explicit `session:leave`, not a stale registration. Whether this symptom still reproduces after the transport repair remains to be confirmed by further use; not re-observed during this session's live verification (calls stayed stable, no false termination observed), but not exhaustively retested either.

**Diagnostic instrumentation kept** (matches this repo's existing `[join-seq]` precedent): `[transport-diag]` logging throughout `RealtimeSocketService` and `[join-diag]` logging in `_joinCurrent`/`_startJoin`/`join()` — cheap, permanently useful for this exact class of defect, consistent with how `[join-seq]` was kept from an earlier fix.

## URGENT — Meetings attendee-join router regression, restored 2026-08-14

Founder production evidence: a legitimate Aura user who booked a Meeting was redirected to **Institution Sign In** when attempting to join, instead of entering through the certified Meeting attendee/join path. Meetings is a frozen/protected surface — founder ordered a read-only forensic trace first, then authorized full end-to-end restoration once the cause was proven deterministic.

**Root cause, proven at the code level.** `router.dart`'s `requiresInstitutionAccess(path)` treats every `/institution/:id/...` sub-path as requiring `institutionAccess.hasAccess` via a blanket regex (`^/institution/[^/]+/.+`, present since 2026-05-01). Meetings' institution-namespaced route family (`/institution/:institutionId/meetings/:meetingId(...)`, added 2026-07-11 so a meeting's URL can carry institution context) was never carved out of that blanket rule. Three call sites unconditionally build that institution-namespaced URL whenever a meeting has an owning institution, regardless of whether the viewer is an institution actor: `booking_confirm_screen.dart`'s post-booking "View meeting" button, `keep_meeting_screen.dart`'s post-signin "keep this booking" flow, and — the one that actually blocks joining — `meeting_detail_screen.dart`'s `_liveBasePath`/`_enterRoom()` "Enter room" button. Any of the three sends a legitimate booked/invited attendee (who has no reason to have institution access) straight into the router's institution gate.

**Not a recent regression** — proven via `git blame`: the institution-namespaced link generation (`13bf4c6`, 2026-07-11) postdates the blanket router gate (2026-05-01) by two months, so this bug has been live and reproducible since 2026-07-11. It predates Identity Foundation Phase 1 (2026-08-11) and every shared-runtime/router change made this session by a wide margin — none of that work introduced or touched this. It is a month-old latent bug, first observed and reported now, not a new regression from recent shared work.

**Confirmed safe, backend independently authoritative.** `GET /meetings/:id` → `MeetingService.getMeetingForMember(id, userId)`, documented in the controller as "Visibility follows Participation Policy: host, participants, invitees, and (for institution meetings) active institution members" — zero dependency on institution-actor role anywhere in that authorization path (`grep` for `institutionAccess`/`hasAccess` in the meetings controller/service returns nothing). The frontend router's institution gate was strictly broader than the resource it protects; removing it for meeting-attendee sub-paths does not weaken any real authorization boundary.

**Fix — shared boundary only, zero Meetings-file changes.** `requiresInstitutionAccess`'s body was extracted from a router-closure-local method to a new top-level, dependency-free pure function `requiresInstitutionAccessForPath(String path)` (the local method now just delegates) — this was necessary to make it independently unit-testable at all, since it was previously buried inside the `routerProvider` closure with no test coverage. The function gained one carve-out: `/institution/:id/meetings/:meetingId(...)` (record, prep, room, waiting, live, summary, post-meeting) no longer requires institution access — governed by Meeting Attendance Authority (the backend check above) instead of Institution Authority. `/institution/:id/meetings` (the bare list) and `/institution/:id/meetings/new` (creation) remain gated — those genuinely are institution-staff-only management surfaces, explicitly excluded via a negative lookahead so "new" can never be mistaken for a meetingId.

**New regression test**: `test/router_institution_access_test.dart` (4 groups) — locks in that meeting-attendee sub-paths are never gated, that institution-staff meeting management stays gated, that other institution-scoped resources (profile, announcements, correspondence, dashboard, verification) are unaffected (no blanket weakening), and that non-institution paths are unaffected.

**Blast radius checked, not expanded beyond evidence.** `meetings_home_screen.dart`'s `_meetingPathFor` has the identical unconditional-institution-path pattern, but that screen is only reachable via `/institution/:id/meetings` (itself gated) — a user already had institution access to get there, so this occurrence causes no user-facing symptom and was left untouched (not a Meetings-file change, no reported defect). Checked Institution Spaces for an equivalent public-entry regression: none exists — Spaces have no public booking-style flow generating an institution-namespaced link for a non-institution-actor; membership there is entirely post-creation self-join/roster management. Confirmed confined to Meetings.

**Certification**: `flutter analyze` clean (targeted `router.dart` pass, then full-project pass, both clean). Full practical suite **201/201** (197 + 4 new). Backend: untouched, no changes needed — its authorization was correct from the start.

**Not yet done**: commit/push pending this same turn; founder device/browser certification for the actual booked-attendee join flow still owed (recorded in `NEXT_WORK.md`).

## Permanent Call Lifecycle Reconciliation, 2026-08-14

Founder directive, mid-Phase-D device testing: two symptoms survived every prior local fix (Android ring sound continuing ~24s past accept; a Retry/Dismiss error banner appearing on calls that connected and ended cleanly) and were explicitly identified as evidence of multiple competing state holders, not independent cosmetic bugs. Founder ordered a stop to incremental patching and a full forensic trace before any further code changes.

**Root cause 1 — Retry/Dismiss banner (PROVEN, code-level, not inferred).** `RealtimeController._performJoinWithRetry()` wraps each join attempt in `Future.timeout(15s)`. Dart's `Future.timeout()` does not cancel the underlying computation — it only stops awaiting it. `_performJoin()` sets the authoritative `joinState: joined` transition BEFORE its slow tail (ICE/media negotiation, wrapped non-fatally since an earlier fix), so a real-network attempt that runs past 15s due to that slow tail was still succeeding in the background when the retry loop, having caught the `TimeoutException`, started a second, fully concurrent `_performJoin()` for the same session. Both could mutate shared `state` independently; live device logs from this same session (`live_capture.txt`, 2026-08-11 23:07) captured three `session:join` emissions for one session within 6 seconds — the smoking gun, previously captured but unexplained. If the superseded attempt's late success or the retry's own spurious failure (e.g. a business-rule rejection because the session was already joined) landed last, it could overwrite a genuinely successful join with an error state.

**Root cause 2 — Android ring surviving accept (documented via existing, previously-uncommitted native code comments, not re-derived from scratch this session).** The `aura_calls` notification channel (`AuraApplication.kt`) uses `USAGE_NOTIFICATION_RINGTONE`, which Android plays to completion independent of app/notification state until the notification is explicitly cancelled — this app had no `flutter_local_notifications` and no custom `FirebaseMessagingService`, so nothing was cancelling it. **Explicitly ruled out** as a contributing cause: the dual push-delivery pipeline (direct + canonical) recalled from an earlier chapter's memory — re-verified against current backend code and found consolidated to a single production call site (`NotificationDeliveryAuthorityService.sendToUser`, guarded by its own `DELIVERY_DEDUP_TTL_MS` dedup map); that architecture no longer exists at current code state.

**Fix — `lib/features/realtime/application/realtime_controller.dart`.** Added `_joinEpoch` (int), incremented once per attempt inside `_performJoinWithRetry`. `_performJoin(sessionId, epoch)` now takes the attempt's epoch and no-ops before either state-mutating transition (the meeting-only interim state and the authoritative `joined` transition) if a newer attempt has since started — a superseded attempt can never again clobber a newer attempt's outcome. `_performJoinWithRetry` also short-circuits to success (no retry) if `state.isJoined` for the exact session is already true by the time a retry would start — the realistic case proven by the log evidence, where the authoritative transition already landed before the timeout-driven retry decision was made. This uniformly protects Thread/DM, Meeting, and Institution Space join paths since all share this one method — a strict improvement, not a behavior change, for the happy path of all three surfaces.

**Fix — `lib/features/realtime/presentation/incoming_live_overlay.dart`.** Native ring-notification cancellation was previously called from two explicit action sites (`_joinCurrent`, `_declineCurrent`), missing every remote-driven termination (caller cancels before answer, invite expiry, another device answering first) — the direct evidence for this gap was 7 stale, uncancelled call notifications observed stacked in the device shade earlier in this same session. Consolidated to a single authoritative choke point: the existing `ref.listen(incomingCallBridgeProvider, ...)` diff callback (already firing on every bridge removal, from whatever cause) now also calls `cancelNativeCallNotifications()` once per removed session. Notification presentation now follows lifecycle truth (bridge removal) rather than best-effort calls scattered per action.

**Also present in this diff, built but not yet installed/tested on-device before the founder's directive arrived, now included in this fix (pre-existing from the tag-cancellation investigation, unchanged by this session's root-cause work):** `MainActivity.kt`'s `cancelCallNotifications()` matches `manager.cancel(entry.tag, entry.id)` (was the single-arg `cancel(id)`, which silently no-ops on tagged notifications) and only cancels notifications on the `aura_calls` channel.

**Certification.** `flutter analyze` clean across the realtime module, `app`, and `core/notifications`. Full practical suite: **197/197** (1 pre-existing golden skip, unrelated — `realtime_room_golden_test.dart`, documented rot predating this session). `flutter build apk --debug` succeeded, confirming the native Kotlin change compiles. Backend: full suite **1485/1485**, including two new regression tests added this session (`correspondence-orchestrator.service.spec.ts` — `sweepExpiredInvites` invariant: queries only `PENDING` invites, never touches `ACCEPTED`).

**Not done this session, honestly disclosed:** no live on-device retest — the founder's Pixel was not connected via adb when this work completed (previous connection from earlier in this session had ended). The founder's directive explicitly authorized implementing end-to-end without incremental device-test round-trips; a narrow founder-device certification checklist is owed in the handoff for this reason. No widget/controller-level automated regression test was added for the epoch-guard race itself or for the `_isInterruptCandidate` "already joined" guard — both are exercised only by code-level proof and the full analyzer/test/build certification above, not a dedicated new unit test, because `RealtimeController` has no existing test harness (its dependencies — `RealtimeRepository`/`RealtimeSocketService`/`RealtimeMediaService` — require `Dio`/Socket.IO/`flutter_webrtc` and no fakes exist yet in this repo) and building one from scratch was judged disproportionate to add blind, mid-fix, without risking an unreliable test. Flagged as a good candidate for a dedicated future testing chapter, same disclosure pattern as the Compose Link Intelligence chapter's composer-coverage note above.

## Native Background/Terminated Notification Certification — Phase A/B/C/D, 2026-08-14

Backend record: `../aura-backend/docs/2026-08-14-native-background-terminated-notification-certification.md`. Status: audit + test matrix + evidence reconciliation + founder-approved repair, all complete. **Implemented, locally certified, committed `74d7875` ("fix: repair thread call lifecycle and native presentation"), pushed to `origin/main`.** This was a controlled commit/push to establish a safe deployment point for founder device certification, not chapter closeout — founder post-deployment device certification is PENDING, chapter NOT CLOSED.

**Phase D — repair implemented in this repo, 2026-08-14.** `RealtimeState.acceptedByPeer`/`isPeerAcceptedNotYetPresent` (new) + `case 'call:accepted':` in `RealtimeController`'s WS switch (added to `RealtimeSocketService`'s event allowlist — was not forwarded before) + new "Accepted — joining…" `_CallTopBar` state — closes the caller-stuck-Connecting single point of failure identified in Phase C, deliberately never collapsing ACCEPTED with CONNECTED (`session:participant.joined` remains the sole connection proof). `AuraIncomingLiveLayer` now triggers `SystemSound.play`+`HapticFeedback.heavyImpact()` once per newly-added `incomingCallBridgeProvider` session id (reuses existing dedup, zero new dependency) — iOS foreground calls now have sound+haptic. New `RealtimeMediaService.setSpeakerphoneEnabled()` (wraps `Helper.setSpeakerphoneOn`, mobile-native only via `kIsWeb` guard, resolved fresh per call, reset in `resetSessionMedia()`) + `RealtimeController.toggleSpeakerphone()` + a speaker/earpiece button in `_CallControlDock` shown only where `Platform.isIOS || Platform.isAndroid` — Thread/DM calls now have real output-routing control. `Meetings`' `MeetingDevicePicker`/`_showDeviceSettings()`/`setAudioOutput()` usage is unchanged — confirmed untouched. New test `test/realtime_state_accepted_by_peer_test.dart` (5 tests). Certification: full-project `flutter analyze` clean; practical non-golden suite **190/190** (up from 178); `flutter build web --release` succeeded.

**Phase A/B client-side findings (unchanged)**: `ios/Runner/GoogleService-Info.plist` is confirmed missing — no iOS device can register for push at all today. `DeviceService._fcmPayload()` hardcodes `provider: 'FCM'` for both Android and iOS. No CallKit/PushKit anywhere. `NotificationBridge`'s `_onFcmTap` correctly handles both warm background-tap and cold/terminated start via the identical function. `_firebaseMessagingBackgroundHandler` is a no-op stub. Windows: foreground-socket-only by design. Web `sw.js` remains the one platform with the full ring→cancel→tap chain proven complete.

**Phase C findings, new 2026-08-14 (founder-device evidence reconciled)**: confirmed by full-repo trace that **zero sound/haptic implementation exists anywhere** in this repo (no audio-player package, no `HapticFeedback` call) — Android's parity comes entirely from a native, Android-only `NotificationChannel` config with zero shared-code involvement, so this is a genuinely missing iOS feature, not a bug in shared code. Confirmed **zero speaker-route control exists for Thread/DM calls** — the only such control (`RealtimeMediaService.setAudioOutput()`) is wired exclusively into Meetings; `_CallControlDock` (Thread/DM's control set: Mic/Camera/Participants/More/Leave) has no speaker button; no custom `AVAudioSession` config anywhere on iOS; audio and video calls share identical audio-session code. Traced the caller-stuck-Connecting defect as far as this repo's own code allows: `RealtimeController`'s `session:participant.joined`/`call:declined` WS handling is correctly wired — **no client-side bug was found here**; the defect is a backend-side single point of failure (no redundant signal exists server-side, not that this client mishandles a signal it receives). Traced the Android "keeps ringing after notification tap" report: `_onFcmTap` bypasses `ThreadCallLifecycleController.acceptIncomingCall()`'s explicit bridge management, navigating directly via GoRouter — but `_startJoin()`'s `.then()` clears the incoming-call bridge entry on any successful join regardless of source, so this alone doesn't fully explain the symptom; most consistent explanation ties it to the same backend single-point-of-failure gap (linked hypothesis, not independently proven).

Founder-reported during Phase A, now root-caused in Phase C (see above): two-party iOS audio/video calls have low volume at 100% device volume, no speaker toggle — confirmed zero speaker-route implementation, not a false report.

## Communication Timeline Authority — Phase 1, implemented 2026-08-13

Backend implementation record: `../aura-backend/docs/2026-08-13-communication-timeline-authority-phase1-implementation.md`.

Status: implemented, locally certified, **founder Gate 2 approved, committed `38765bc` ("feat: establish communication timeline authority phase 1"), pushed to `origin/main`** (`6e1f7aa..38765bc`). Chapter closed. Paired backend commit `47a4fae` (`6b8d97e..47a4fae`).

Activated the previously-dead `type == 'LIVE'` branch in `activity_screen.dart`'s `_buildTitle()` — extended to handle the four new founder-approved outcomes (`CALL_COMPLETED`/`CALL_DECLINED`/`CALL_CANCELLED`, plus the pre-existing `CALL_MISSED` case), using a new `direction` field (INCOMING/OUTGOING) to phrase outgoing vs. incoming correctly. `_iconForType()` gained a `LIVE` case (`Icons.call_outlined`) — it previously had none at all, falling through to a generic bell. `_buildSubtitle()`/`_ctaLabel()` needed no changes, both already handled LIVE generically.

**Real, general (not Timeline-scoped) client bug found and fixed while activating this dead code**: `NotificationsRepository._normalizeNotificationItem()` has always read `item['data']` first, but the backend's `ActorNotificationsService.list()` has always returned the row's custom fields under the JSON key `payload`, never `data`. Every pre-existing notification type survived this silently via top-level column fallbacks (`threadId`, `postId`, etc.) — a call-outcome row's only distinguishing field (`notificationKind`) has no such fallback and would have been silently lost even with correct backend data. Fixed with a one-line, general fallback (`item['data'] ?? item['payload']`), not scoped narrowly to this chapter.

Certification: `flutter analyze` clean, practical suite **178/178** (up from 172), web build succeeded. New `test/activity_screen_communication_timeline_test.dart` (6 tests) mounts the real, previously-zero-coverage production `ActivityScreen` end to end for every outcome (missed, completed-outgoing, completed-incoming, declined, cancelled, mixed-feed-no-duplication).

## Compose Link Intelligence / OG Preview — Phase 1 — CLOSED, 2026-08-12 (final scope: Member Posts + Institution Posts + Institution Announcements)

Backend implementation record: `../aura-backend/docs/2026-08-12-compose-link-intelligence-og-preview-phase1-implementation.md`.

Status: implemented, locally certified, **founder Gate 2 approved, committed `6303882` ("feat: establish link intelligence phase 1"), pushed to `origin/main`** (`9d0d558..6303882`). Chapter closed. Paired backend commit `ec09202` (`80d9145..ec09202`).

**Announcement extension, founder-approved same day after the first Gate 2 review.** `institution_announcement_composer.dart` now wires the identical `ComposeLinkDetector`/`LinkPreviewService`/`LinkPreviewCard` trio already proven on the other two composers — same debounce, same always-resend/null-clears payload convention, same edit-mode hydration-without-refetch. `Announcement` domain model gained the same six flat link fields; `announcement_detail_screen.dart` renders the preview as a top-level block mutually exclusive with attached media, matching that screen's own pre-existing media-above-card layout (the one named layout-constraint adaptation, not a divergent rendering system). The compact `_AnnouncementCard` list-view summary row was deliberately left unwired (thumbnail-only layout, no room for a rich card). `institutions_repository.dart`'s `createInstitutionAnnouncement`/`updateInstitutionAnnouncement` gained `linkPreviewId`/`linkSourceUrl` params, always included in the request body (the one deliberate divergence from that file's own `if (x != null)` convention for every other field, required for the null-clears contract). New widget test (`test/institution_announcement_composer_link_preview_test.dart`, 3 tests) mounts the real production `InstitutionAnnouncementComposer` end to end; `Announcement.fromJson` parsing coverage added to the existing `link_preview_model_parsing_test.dart`. Practical suite grew to 172/172 (up from 166), analyzer clean, web build succeeded. Zero files under Member Posts or Institution Posts touched.

**Real, load-bearing discovery from the pre-implementation audit**: `lib/features/posts/presentation/widgets/post_card.dart` already had a fully-built link-preview rendering block (`_finalAttachmentBlock` — thumbnail, title, description, host, "Tap to open · Hold to copy") reading `post.linkUrl`/`.linkTitle`/`.linkDescription`/`.linkImageUrl` via dynamic dispatch — but `Post.linkUrl` did not exist on the client model, so every read silently threw, was caught, and the card was permanently dead code. Confirmed by reading the code, not assumed; the founder's explicit instruction to audit-first before assuming nothing exists is what surfaced this.

**New shared module `lib/core/link_preview/`**: `LinkPreview` (parsed model), `link_url_detection.dart` (`firstUrlIn()`), `LinkPreviewService` (`POST /link-previews/resolve`), `ComposeLinkDetector` (plain-Dart controller-listener, 500ms debounce, stale-in-flight-resolve guard — mirrors the existing `GovernedTagAutocomplete` pattern), `LinkPreviewCard` (rendering widget). One of each — no duplicate detection, resolution, or rendering logic for either compose surface.

**Both composer screens wired identically**: `compose_screen.dart` (member) and `institution_post_composer_screen.dart` (institution) each instantiate the same `ComposeLinkDetector` wrapping their text controller, render the same `LinkPreviewCard`, and always resend `linkPreviewId`/`linkSourceUrl` in their save/publish payload (null clears — same convention as `primaryTopic`). Draft/edit hydration reads the post's own already-resolved flat fields, no redundant refetch on open.

**Two separate card-rendering systems both now render link previews via the one shared widget**: `Post` (`lib/features/feed/domain/post.dart`) gained `linkUrl`/`linkSiteName` (the missing fields that activate `post_card.dart`'s pre-existing dead code — zero changes needed to that file itself); `FeedItem` (`lib/features/feed/domain/feed_item.dart`) gained all 5 link fields, wired into a new rendering branch in `unified_feed_card.dart` (institution posts had no link rendering at all before this chapter). `InstitutionPost` (`lib/features/institutions/domain/institution_post.dart`) also gained the 5 fields for the composer's own hydration.

**Certification**: full-project `flutter analyze` clean; practical non-golden suite **166/166** (up from 147); `flutter build web --release` succeeded. **Real, full production composer screens under widget test for the first time in this repo** (both had zero pre-existing coverage): `test/compose_screen_link_preview_test.dart` (3 tests) and `test/institution_post_composer_link_preview_test.dart` (3 tests) mount the actual `ComposeScreen`/`InstitutionPostComposerScreen` and drive paste→debounce→resolve→render→save/publish, remove-clears, and resolve-failure-still-saves scenarios end to end. Plus `test/compose_link_detector_test.dart` (7 tests, the shared detector mechanism) and `test/link_preview_model_parsing_test.dart` (6 tests, model `fromJson`).

**Explicit scope disclosure**, addressing repeated founder questions about composer test coverage during this chapter: this coverage is scoped to the Link Intelligence feature, driven through the real screens — it is not comprehensive coverage of every other composer capability (topic picker, media upload, cross-post, draft autosave timing, discard, reply threading), none of which had test coverage before this chapter. Recommended as its own dedicated future testing chapter.

Meetings, Reachability Authority, Session Continuity Authority, Communication Runtime Lifecycle Authority, Device Communication Presence Authority, Notification Delivery Authority, Canonical Call Notification Stage A, Institution Authority, and Identity Foundation were not touched.

## Identity Foundation Phase 1, 2026-08-11

Backend implementation record: `../aura-backend/docs/2026-08-11-identity-foundation-phase-1-implementation.md`.

Status: implemented, locally certified, founder Gate 2 approved, committed, and pushed. Commit `56a0bb7` ("feat: establish identity foundation phase 1"), on `origin/main` (`46eda5d..56a0bb7`). Paired backend commit `18b2cfb`.

**A. Required identity baseline (Date of Birth).** New `identityBaselineCompleteProvider` (`lib/core/auth/session_providers.dart`), a structural mirror of the existing `emailVerifiedProvider` (same null-means-wait discipline, same institution-account bypass), fed by a new `identityBaselineComplete` field on `/auth/me`. `router.dart` gained `kCompleteIdentityRoute = '/complete-identity'`, `requiresIdentityBaseline(path)`, a `ref.listen` wired into the existing `refresh` notifier, and boot-path plus main-flow redirect blocks placed **before** the email-verification check (DOB is checked first, as "the first identity field"). New `IdentityBaselineScreen` (`lib/features/auth/presentation/identity_baseline_screen.dart`), structurally identical to `VerifyPendingScreen` — full-screen interstitial, carries `redirectTo`, submits via `PATCH /users/me/identity-baseline`, then only invalidates `authMeDataProvider` (the router's own listener handles navigation, no manual `context.go`). This reuses the same proven redirect mechanism email verification and institution access already use, so cross-platform consistency (web refresh, desktop start, Android/iOS resume/launch, deep-link interception before completion) comes for free — no platform-specific code was needed. No age-eligibility threshold implemented — none exists anywhere in this codebase; flag to founder if required.

**B. Shared identity resolution repair.** Root cause, confirmed by reading code: `new_conversation_screen.dart`'s `_DirectoryEntry.id` and `.userId` were resolved via independently-ordered fallback chains that could diverge for a payload where a wrapper/relationship-row id differs from the actual user id — the same real person could surface as two different selectable/selected entries depending on which listing produced them. Fixed by resolving `userId` once, then deriving `id` from it, so selection key and submission key are always the same value. `_SelectedChip` gained an `AuraAvatar` (previously text-only) for pre/post-selection identity consistency. Institution-space creation has no member-picker UI on this client today (confirmed by full-file audit of `institution_spaces_screen.dart`) — nothing to patch there; membership is entirely post-creation self-join/roster management.

Regression proof: new test in `test/new_conversation_screen_test.dart` reproduces the divergent-wrapper-id scenario and was verified to **fail against the pre-fix code** (via a temporary `git stash` of the fix) before being verified green against the fix — a proven regression guard.

Certification (first pass): full-project `flutter analyze` clean; practical non-golden suite 137/137 (including a real app-boot smoke test whose router-trace log confirms `identityBaselineComplete` evaluates correctly during boot); `flutter build web --release` succeeded. Meetings, Reachability, Session Continuity, Communication Runtime Lifecycle, Device Communication Presence, Notification Delivery, and Canonical Call Notification Stage A were not touched.

**Second pass, 2026-08-11 — institution-space member selection, chapter now COMPLETE.** Founder required institution-space member selection end to end before closing this chapter. Extracted the identity model out of `new_conversation_screen.dart`'s private scope into a public, canonical module: `lib/core/directory/directory_entry.dart` (`DirectoryEntry`, `memberEntryFromMap`, `dedupeDirectoryEntries`) — one identity resolver now, not a second one duplicated for institution use. `new_conversation_screen.dart` was refactored to consume it (mechanical extraction, zero behavior change, verified by re-running its full pre-existing test suite unchanged before adding anything new). New reusable `lib/core/directory/member_picker_field.dart` (`MemberPickerField`) — a self-contained selection widget for bounded candidate lists (search/select/dedupe/chips, client-side filtered) — wired into `institution_spaces_screen.dart`'s create form, sourcing candidates from the institution's own roster (`GET /institutions/:id/members`), excluding the current user, submitting `participantIds` built the same way `new_conversation_screen.dart` already does. Backend paired change: `../aura-backend` commit-pending `institutionSpaceSelectWithMembers`/`CreateInstitutionSpaceDto.participantIds`.

Certification (cumulative): full-project `flutter analyze` clean; practical non-golden suite **147/147** (up from 137, still including the app-boot `identityBaselineComplete` smoke-test confirmation); `flutter build web --release` succeeded; `new_conversation_screen_test.dart`'s full suite (2-party, multi-party, and the identity-resolution regression test) re-verified green after the shared-module extraction. Meetings, Reachability, Session Continuity, Communication Runtime Lifecycle, Device Communication Presence, Notification Delivery, Canonical Call Notification Stage A, and Institution authority were not touched.

## Takeover audit continuity reconciliation, 2026-08-11

A Claude takeover audit (read-only, no code edits) verified actual git history against this continuity set and found three entries below still described as "not committed, not pushed, awaiting founder Gate 2 authorization" when they were, in fact, already founder-approved, committed, and pushed to `origin/main`: Notification Delivery Authority Phase 1 (backend-only, `../aura-backend` commit `b23ff4419089483b8f5132f6ab4036d50ebb87ef`), Device Communication Presence Phase 1 (backend-only, `../aura-backend` commit `3bf8d67976c230767e0e108788d67f670dd883e3`), and the Correspondence entry flow repair (this repo, commit `7a47fefe5924ea19a1e483475182d72383b10687`; paired backend `9739ad5fb7551a0857ad22159add3e102eb7cc40`). Root cause: each entry was authored inside the same commit that performed the commit, so the "not committed" tense was already stale the moment it landed, and no follow-up entry ever corrected it. No code defect, no reopened architecture — documentation-tense correction only. Status lines below corrected in place; `DECISIONS.md` gained matching Gate 2 closure entries.

## Notification Delivery Authority Phase 1 backend contract, 2026-08-09

Backend implementation record: `../aura-backend/docs/2026-08-09-notification-delivery-authority-phase-1-implementation.md`.

No Flutter application/runtime/client code was edited.

Flutter contract impact:

- existing `call:incoming` socket payload and event name remain unchanged;
- existing direct Stage A call push payload remains unchanged;
- existing canonical Communication-linked push payload remains unchanged;
- existing notification tap/deeplink handling remains the client contract;
- `NotificationBridge`, `incomingCallBridgeProvider`, service-worker notification behavior, and root Thread lifecycle ownership remain unchanged;
- native background/terminated notification certification remains unresolved and mandatory before native production release.

Backend Phase 1 is Gate 2 approved, committed, and pushed as `b23ff4419089483b8f5132f6ab4036d50ebb87ef` in `../aura-backend`. It does not by itself create a new native client release artifact.

## Correspondence entry flow repair, 2026-08-08

Repair record: `docs/2026-08-08-correspondence-entry-flow-repair.md`.

Status: implemented, founder Gate 2 approved, committed, and pushed as `7a47fefe5924ea19a1e483475182d72383b10687`.

Founder production evidence: selecting a second member in Messages -> Create removed/replaced the first selected member, and create failed with backend validation. Root cause was a split selected-member state model: selected IDs persisted, but selected entries were derived from the current search cache, so changing search results could drop prior selections from the UI and submitted payload. A paired backend contract drift rejected Workroom/Salon mode values exposed by the Flutter UI.

Flutter fix:

- `NewConversationScreen` now stores selected entries by ID independently of current search results;
- search changes preserve prior selections;
- duplicate selection is ignored and deselection removes only the intended member;
- submitted participant IDs come from the same stable selection state shown in the UI;
- one-to-one private and shared-space mode transitions are deterministic;
- Circle, Workroom, and Salon remain distinct entry modes;
- submit errors use the safe app error mapper instead of surfacing raw Dio exceptions;
- `CompositionAssist` received a layout-only responsive fix for the embedded shared-space details surface.

Verification: focused entry-flow widget tests passed 5/5, `flutter analyze` passed, practical non-golden suite passed 130/130, and web release build passed. Meetings, Reachability, Session Continuity, Canonical Call Notification Stage A, Thread Call Lifecycle Stage 1, and Device Communication Presence Phase 1 were preserved.

## Device Communication Presence Phase 1 backend contract, 2026-08-08

Backend implementation record: `../aura-backend/docs/2026-08-08-device-communication-presence-phase-1-implementation.md`.

No Flutter application/runtime/client code was edited. Backend Phase 1 is Gate 2 approved, committed, and pushed as `3bf8d67976c230767e0e108788d67f670dd883e3` in `../aura-backend`.

Flutter contract impact:

- existing REST join/decline endpoints remain the client contract;
- existing socket events remain the client contract, including `session:join`, `session:replaced`, `call:declined`, and `call:terminal`;
- accepted/declined terminal synchronization is now backend-gated by first-action-wins authority, but released Flutter does not need new request/response fields;
- late losing Thread/DM media devices receive existing `session:replaced`, which current Flutter already handles by parking the replaced runtime;
- Activity doctrine, Notification Delivery Authority, native background notification handling, preferred-device policy, and manual transfer remain deferred.

Meetings remain protected. Backend Phase 1 does not track `MEETING` media ownership and did not edit Meeting source files.

## Communication Continuity & Presence Chapter 1 contracts, 2026-08-08

Backend platform contract record: `../aura-backend/docs/2026-08-08-communication-continuity-presence-chapter-1-contracts.md`.

No Flutter application/runtime/schema/client code was edited. This is contract/test-harness architecture only.

Frozen platform authorities:

1. Communication Runtime Lifecycle Authority.
2. Notification Delivery Authority.
3. Device Communication Presence Authority.
4. Communication Timeline Authority.

Flutter release implications:

- Desktop/Android/iOS production release is blocked until mandatory platform gates are resolved: Device Communication Presence Phase 1, Notification Delivery Authority Phase 1, native background/terminated notification certification, Communication Timeline Authority Phase 1, iOS Firebase/APNs confirmation, and Meetings preservation certification for shared authority implementation.
- Communication Runtime Lifecycle Phase 2 can remain later only if current native lifecycle health remains certified and no blocking lifecycle defect is found.
- Stage 1 Thread lifecycle remains the Thread foreground adapter and does not become a general platform lifecycle authority.
- `RealtimeController` remains the client media/session execution owner.
- Meetings remain protected and unchanged.

## Communication Continuity & Presence platform architecture, 2026-08-08

Backend platform record: `../aura-backend/docs/2026-08-08-communication-continuity-presence-platform-architecture.md`.

This is a new platform infrastructure discovery chapter, not Thread Calling or Meetings feature work. No Flutter application/runtime/schema/client code was edited.

Proposed long-term authorities:

1. Communication Runtime Lifecycle Authority.
2. Notification Delivery Authority.
3. Device Communication Presence Authority.
4. Communication Timeline Authority.

Flutter implications: Stage 1 remains the Thread foreground lifecycle seed, not the whole platform runtime authority. Future work should generalize lifecycle, notification delivery consumption, device ownership synchronization, and communication chronology through platform authorities while preserving `RealtimeController` as media/session execution owner and preserving Meetings unchanged.

## Pre-release connected-system health audit, 2026-08-08

Authoritative gate: `docs/2026-08-08-pre-release-connected-system-health-audit.md`.

Overall verdict: READY WITH NON-BLOCKING RISKS for native test builds.

Health summary:

- App root/provider lifecycle: HEALTHY.
- Authentication/session: HEALTHY.
- Notifications/attention: HEALTHY; active-call Activity doctrine remains deferred.
- Correspondence/Threads: HEALTHY.
- Realtime: HEALTHY; shared realtime files remain untouched.
- Meetings: HEALTHY; Meetings product files remain untouched and Meeting controls passed.
- Device registration: HEALTHY.
- Navigation/deep links: HEALTHY.
- Web: HEALTHY.
- Desktop: HEALTHY for source/compile readiness; runtime certification remains founder/device work.
- Android: HEALTHY for source/compile readiness; runtime certification remains founder/device work.
- iOS: AT RISK only because the secure CI `FIREBASE_IOS_CONFIG_BASE64` value cannot be verified from Windows and must be confirmed before/with the iOS build pipeline.
- Backend contract boundary: HEALTHY; no backend runtime/schema changes after certified backend chapters.
- Governance compliance: HEALTHY.

Verification completed with the certified `C:/flutter` safe-directory environment override: `flutter analyze` PASS, focused/recent shared-system set PASS 78/78, practical non-golden suite PASS 125/125, web release build PASS, Android debug build PASS, Windows desktop debug build PASS, Flutter doctor PASS, and `git diff --check` PASS for Flutter/backend.

No application/runtime/schema/client code was edited during this audit.

## Canonical Flutter Thread-Call Lifecycle Stage 1 implemented, 2026-08-08

Stage 1 implementation is committed and pushed as `86de6e165931e96185a2e78a349bb5502065940a` (`realtime: establish canonical thread call lifecycle`). It follows `docs/2026-08-08-canonical-flutter-thread-call-lifecycle-stage-1-blueprint.md`.

Implemented behavior:

- `threadCallLifecycleProvider` now owns Thread-call presentation/runtime intent at app level with client-only phases: `invited`, `joining`, `joined`, `mediaNegotiating`, `connected`, `transportDegraded`, `ended`.
- `ThreadCallLifecycleHost` is mounted from `AuraApp` under the existing `NotificationBridge`/app-root boundary and wraps routed content with the single incoming live layer for authenticated member sessions.
- `incomingCallBridgeProvider` remains the pending-call/dedup store and now exposes normalized `addIncoming()` ingestion for socket and foreground-push call payloads.
- `AuraIncomingLiveLayer` is presentation-only for incoming calls; accept delegates to the lifecycle owner, and route lookup no longer depends on shell-local `GoRouterState`.
- `MemberShell` and `InstitutionShell` no longer mount their own incoming overlay, preventing duplicate route/shell-owned consumers.
- Thread caller start, Thread call-card join, and incoming-overlay accept now route through the lifecycle owner, which delegates to the existing `RealtimeController`; `RealtimeController` remains the canonical socket/media/session executor.
- Foreground FCM call interrupts feed the same bridge path and dedup by `sessionId`.
- Meeting sessions are excluded from Thread lifecycle projection/overlay interference; no shared realtime files were edited.
- Existing external/background `/realtime/:sessionId?action=join` route behavior remains unchanged because generic realtime route edits were outside the approved shared-realtime gate.

Gate 2 toolchain health and verification:

- Root cause of the original test/build hangs: Flutter SDK git metadata at `C:/flutter` was not trusted for the current command user (`git -C C:\flutter status -sb` reported dubious ownership). Plain `flutter --version` timed out. Dart itself (`dart.exe --version`) was healthy.
- Recovery: `C:/flutter` was added to Git `safe.directory`; certification commands were run with the explicit session-local Git config override `GIT_CONFIG_COUNT=1`, `GIT_CONFIG_KEY_0=safe.directory`, `GIT_CONFIG_VALUE_0=C:/flutter`, which made Flutter tool startup healthy. Plain `flutter --version` still times out in this sandbox, so use the override for local Flutter certification until the sandbox/global Git config mismatch is fully corrected.
- Baseline control: `flutter test --no-pub test\governed_tagging_test.dart -r expanded` passed 11/11.
- Focused Stage 1 lifecycle tests: `flutter test --no-pub test\thread_call_lifecycle_controller_test.dart -r expanded` passed 6/6.
- Relevant correspondence/realtime/notification/Meeting set: `flutter test --no-pub test\thread_call_lifecycle_controller_test.dart test\notification_open_reconcile_test.dart test\module_attention_test.dart test\governed_tagging_test.dart test\meeting_entry_resolution_test.dart -r expanded` passed 31/31.
- Repository-standard practical suite: `flutter test --no-pub --exclude-tags golden -r expanded` passed 125/125.
- Meeting preservation control: `test\meeting_entry_resolution_test.dart` passed 6/6.
- `flutter analyze`: clean on 2026-08-08.
- Production web build: `flutter build web --release --no-wasm-dry-run` completed successfully and produced `build\web`.
- `git diff --check`: clean for Flutter and backend working trees.

Deferred items unchanged: Activity doctrine, multi-device arbitration, desktop native notification work, Android/iOS background/terminated notification handling, Stage B backend push consolidation, and any Meetings behavior changes.

## Platform-wide engineering governance, recorded 2026-08-08

These doctrines apply across every Aura repository, present and future:

- Certified product surfaces are protected by default.
- Solve problems within the owning feature/module before touching shared systems.
- Any work that directly, indirectly, intentionally, or unintentionally touches a shared system must identify the shared boundary, preserve existing behavior, execute targeted regression, certify shared-system health, and report shared-system certification separately.
- If preserving a certified shared system is impossible, stop and return for founder approval before implementation.
- Future implementation tasks inherit these rules automatically.
- Future audits must audit governance compliance in addition to feature correctness.
- Newly adopted engineering doctrines must be recorded in working continuity during the next implementation task rather than remaining only in conversation history.

## Canonical Flutter Thread-Call Lifecycle Stage 1 blueprint, 2026-08-08

Blueprint: `docs/2026-08-08-canonical-flutter-thread-call-lifecycle-stage-1-blueprint.md`. No Flutter application/runtime/schema/client code was edited.

Approved architecture decision: Stage 1 combines foreground incoming-call ownership and caller/callee realtime synchronization into one canonical Flutter Thread-call lifecycle chapter across web, desktop, Android, and iOS.

Frozen Stage 1 scope:

- Add one app-level Thread-call lifecycle owner, likely `threadCallLifecycleProvider`, mounted from `AuraApp`.
- Keep existing backend `call:incoming` event and payload; no backend change required.
- Keep `RealtimeController` as the single realtime socket/media/session controller; do not create competing realtime controllers.
- Make `AuraIncomingLiveLayer` root-mounted presentation rather than shell-local ownership.
- Route caller start, recipient accept, and `/realtime/:sessionId?action=join` through one lifecycle entry API.
- Add a client-only Thread call phase projection: invited, joining, joined, mediaNegotiating, connected, transportDegraded, ended. No backend states.
- Preserve Meetings exactly as-is. Shared realtime code changes are allowed only if minimal and backed by Meeting regressions.

Deferred by doctrine: Activity representation for active calls, multi-device accept/decline arbitration, desktop native notifications, and Android/iOS background/terminated push handling.

## Thread Calling Reliability - current Flutter risk model, 2026-08-08

Authoritative audit: `../aura-backend/docs/2026-08-08-thread-calling-reliability-collective-audit.md`. Documentation-only update; no Flutter application/runtime/schema/client code was edited.

Founder production evidence now supersedes older "likely foreground socket healthy" classifications:

- Chrome/browser background received the incoming Thread-call notification.
- Desktop app foreground showed no incoming-call interruption and no Activity entry.
- iOS app foreground showed no incoming-call interruption and no Activity entry.
- Android previously showed no interruption/notification, despite recovered backend evidence proving Android FCM `CALL_RINGING` attempts marked `SENT` for some recipients.
- Party B accepted/participated while Party A remained visually stuck on `Connecting...`.

Current Flutter-facing root-cause domains:

- Shared foreground incoming-call consumer ownership is likely too shell/provider-local. `AuraIncomingLiveLayer` consumes `incomingCallBridgeProvider` in `MemberShell` / `InstitutionShell`; `AuraApp` boots reconciliation but does not globally mount the incoming-call layer, and the global correspondence reconciliation path ignores `call:incoming`.
- Activity no-entry is proven as a backend/client ledger mismatch: Activity reads `/notifications` actor Notification rows while Stage A Thread calls create `Communication(type=LIVE, data.notificationKind=CALL_RINGING, ...)` rows and push attempts, not actor-aware call Notification rows.
- Party-A-stuck-on-`Connecting...` points before the visible `RealtimeController` reaches socket `session:join` ack and `joinState=joined`, or to stale/replaced provider state. Media negotiation alone should not keep pre-join `Connecting...` visible because media errors are non-fatal after join ack.
- Multi-device call notification fans out while media ownership defaults to one same-user runtime device per session (`REALTIME_ALLOW_MULTI_DEVICE=false` on backend), so future client work must account for deterministic replaced/terminal synchronization.

Recommended next work is not authorized yet: shared Flutter foreground call lifecycle ownership, then caller/callee realtime synchronization, then multi-device arbitration, then Activity doctrine, then platform-specific background/native notification handling. Meetings remain a hard preservation boundary.

Repository documentation is authoritative. Conversation history is temporary. This continuity set was established 2026-07-21 (workspace-wide continuity doctrine); prior history is reconstructed from git history and the ROS Phase II records.

## Known defect — logged, not repaired (2026-08-04)

`lib/features/institutions/posts/institution_post_composer_screen.dart` lines 1118, 1130, 1156: the "Title" hint (`Ã¢â‚¬â€`), "Headline for this statement…" hint, and "Write your post…" hint literal strings contain mis-encoded em-dash/ellipsis mojibake (`Ã¢â‚¬â€` / `Ã¢â‚¬Â¦`) baked directly into the Dart source — a UTF‑8-decoded-as-Latin‑1 (or similar) re-encoding at some earlier save, not a runtime rendering bug. Cosmetic only (placeholder/label text), found during live certification of institution post publication for the Publication Reliability and Multilingual Communication Completion mission. Confirmed scoped to this one file (`grep` across `lib/` for the same mojibake byte sequence found no other matches, including the visually similar `institution_announcement_composer.dart`, which is unaffected). Deliberately not repaired in that mission's commits — flagged here for a future, separately-scoped fix.

## Identity

Aura Meetings Flutter frontend (single codebase: iOS + Android + Web). Three application shells (Member / Institution / Admin) + Public shell; talks to `../aura-backend` under global `/v1`. Aura is verified-identity civic discourse infrastructure — see `AGENTS.md`. WebRTC engine: `lib/features/realtime/` (`realtime_controller.dart`, `realtime_media_service.dart`, `realtime_socket_service.dart`).

## New reusable platform capabilities (AXR-1, 2026-07-21)

- **Governed tagging** (`lib/core/tagging/`) — `@member`, `@institution`, `#topic` autocomplete as platform infrastructure, not a Post feature. `TagKind` is an open enum (new entity kinds are a case + a suggest source, no redesign). `tag_token.dart` is pure text/cursor math (no Flutter import) detecting the active token under the cursor, mirroring the backend's `extractHandles` email-boundary guard. `tag_suggest_service.dart` sources `@` suggestions from the existing server-ranked `/search` endpoint (no parallel ranking) and `#` suggestions from the closed `AuraTopic` taxonomy (instant, local). `GovernedTagAutocomplete` wraps any `(TextEditingController, FocusNode)` pair with a keyboard/mouse-navigable overlay. Wired live into post compose, thread messages, and institution announcements — three different composers, one widget.
- **Module attention projection** (`lib/features/updates/module_attention.dart`) — pure function from notification rows → per-module unread counts (Messages, Institutions, Meetings, Mentions), derived from the *same* polled rows the global Activity bell already reads. `moduleAttentionProvider` is the live Riverpod projection; wired into the member shell's side rail and bottom nav.
- **TagStyledText** (`lib/features/public/widgets/mention_text.dart`) — non-interactive tag highlighting for preview surfaces where the whole card is the tap target (e.g. the feed). Companion to the existing interactive `MentionText` used on detail surfaces.

## Production baseline

- Production web deployment at `auraplatform.org`, deployed via Railway. The 2026-07-13 record confirms pushing `main` auto-deployed the web build (verified by asset-hash change + live screenshot). Re-verify auto-deploy still holds before relying on it.
- Mobile: version `1.2.2+22` was the last recorded release commit (`4f6c2a5`). iOS distribution runs through the founder's manual Codemagic/App Store flow.

## Implementation status

- `main` HEAD `39e3964` — **committed locally, NOT pushed** (this milestone did not authorize deploy/push). `origin/main` remains at `b845820`.
- **AXR-1 (2026-07-21): Aura Experience Refinement — unified interaction & identity enhancement.** Consolidated, founder-directed initiative; four workstreams, one commit, no architecture change:
  - **W1 Universal Governed Tagging** — see "New reusable platform capabilities" above. Live in 3 composers today; any future composer (Studio-generated content, future institutional editors) adopts it by wrapping its own field.
  - **W2 Notification Synchronization** — module badges (Messages, Institutions today; Meetings/Mentions destinations don't have nav-rail entries yet, so their counts are computed but not currently displayed anywhere — see NEXT_WORK) now derive from the same notification rows as the global bell, eliminating the fragmented-attention defect the brief described.
  - **W3 Identity Rendering Consistency** — audited every surface the brief listed. The photo→initials fallback rule was never violated *by design*; it was unwired in two ways: (a) server payloads omitting `avatarUrl`/`logoUrl` (fixed in `../aura-backend`, commit `37cb22f`), and (b) five client call sites bypassing the canonical `AuraAvatar` with ad hoc `CircleAvatar`/icon fallbacks that never attempted the image (admin member rows, new-conversation directory, space-screen identity avatar, meeting-participant rows, search's institution tile). All five now delegate to the canonical widget/logo path.
  - **W4 Interaction Consistency** — added `TagStyledText` for the one text surface (feed card preview) rendering raw post text with no tag styling, closing that inconsistency with every other text surface. No duplicated CTAs or navigation actions found on audited surfaces (Single Intent Principle precedent from aura-studio applied as the standard).
  - Tests: 16 new (11 tag-token-engine + 5 module-attention-projection). Full suite: 69 files, all green (1 pre-existing skip, unrelated). `flutter analyze`: 0 issues.
- `b845820` = ROS Phase II fidelity restoration (2026-07-13, founder-authorized, on `origin/main`): stripped a Bajwa Writes trademark symbol from two screens and removed publishing/literary vocabulary from auth/register/search — deployed and live-verified with a cache-busted production screenshot.
- Earlier completed milestones (2026-07-10/11, verified in git history): resolver-driven pre-join (`meeting_entry_resolution.dart`, outcome state machine), invitation OTP flow, authenticated-booking read-only identity card, Profile → Participation continuity tab, managed Past-meetings archive, meeting-workspace surface migration onto AuraSurface tokens (live room internals frozen/untouched).
- ROS Phase II audit closed: **VERIFIED WITH RESIDUAL FOUNDER EDITORIAL ITEMS** (`representation/inventory/AURA_ROS_PHASE_II_CORRECTION_CLOSEOUT.md`). Full audit deliverable set lives in this repo under `representation/inventory/AURA_*.md`.

## AXR-1 — CERTIFIED, closed 2026-07-21

Founder rulings on the three items left open at first delivery, all resolved same-day:

1. **No Meetings/Mentions nav destinations.** Meeting notifications stay Activity-only until Profile → Participation → Meeting History exists (not yet built). Mention notifications don't need a dedicated tab — they must deep-link to their referenced content instead, which was **already true**: `MENTION` notifications carry `postId` (the reply/post containing the mention) and `_routeFor` in `notifications_screen.dart` already resolves `postId` → `/posts/:id`, a real route serving both top-level posts and replies. No code change needed; verified by re-reading the existing routing logic and the backend's `MENTION` notification payload (`postId: created.id`).
2. **Topic-seeded search accepted for AXR-1.** A dedicated topic-scoped view is deferred as a future enhancement (recorded in NEXT_WORK), not a defect.
3. **Institution post composer**: inspected and confirmed a real, routed, active production surface (`/institution/:id/posts/new` and its edit path, `institution_post_composer_screen.dart`). Wired with the same `GovernedTagAutocomplete` pattern as the other three composers — commit `a19547f`. Meeting notes wiring is **not required**: no meeting-notes composer widget exists yet; recorded as a future integration requirement in NEXT_WORK, to be picked up when that composer is built.

`flutter analyze`: 0 issues (file-scoped and full-repo). Full suite: 69 files, all green (1 pre-existing unrelated skip) — unchanged pass count, confirming no regression from the new wiring.

## Next implementation starting point

No founder-defined next milestone is recorded beyond AXR-1, which is now closed. `NEXT_WORK.md` lists the accepted future-enhancement items (topic-scoped search view, meeting-notes tagging once that composer exists) — none authorized to start without separate founder direction.

## Outstanding founder approvals

**None.** AXR-1 is fully implemented, verified, pushed (`a19547f` on `origin/main`, alongside `../aura-backend`'s `37cb22f` on its own `origin/main`), and certified closed. Per this repo's own release doctrine (`OPERATIONAL_BASELINE.md`), pushing `main` is push-to-deploy for the web target on Railway — unlike aura-studio's Cloudflare flow, deploy is not a separate authorized step here. Live cache-busted verification on `auraplatform.org` (the doctrine's own last release-order step) was not performed in this session and is worth a quick confirmation, but is operational follow-through, not a pending decision.
## 2026-07-21: Aura Post Integrity & Editing Remediation

Implemented in the working tree, pending commit/push/deploy verification:

- Member composer discard now calls `DELETE /posts/draft`, clears local composer state, and returns Home through the existing provider invalidation path. Backend stale-token filtering covers refresh/logout/login/restart cases.
- Public composer identity now passes authenticated profile `avatarUrl` into canonical `AuraAvatar`; institution composer actor banner also delegates to `AuraAvatar`.
- Member compose publish/save now requires a canonical selected `AuraTopic` for top-level posts. Raw `#` text does not satisfy this because `_primaryTopic` is only set by `AuraTopicSelector`.
- Member editing restored through `/posts/:postId/edit`, reusing `ComposeScreen` in deterministic edit mode and saving through `PUT /posts/:id`.
- Institution edit now hydrates the existing post through `GET /institutions/:institutionId/posts/:postId`, preserves title/body/topic/visibility/distribution/media state, and saves through `PATCH` instead of create.

Validation recorded this session:

- `flutter analyze` passed with no issues.
- `flutter test` could not be completed: the Flutter test runner hung before output even for pre-existing `test/governed_tagging_test.dart` and `--list-tests`; treat as environment/tooling blocker, not a test assertion failure.

Out-of-scope issues recorded:

- Existing `institutions_repository.dart` had multiple single-line `if` lint issues; fixed because this remediation touched the file.
- Production verification still required after push/deploy.

## 2026-07-21: Post Edit Save & Mention Attachment Follow-up

Implemented in the working tree, pending commit/push/deploy verification:

- `GovernedTagAutocomplete` now handles keyboard selection through the wrapped field focus node and pointer/touch selection on pointer-down, before overlay focus loss can discard the active token.
- Selected member/institution suggestions are recorded as canonical `TagReference` values and submitted in composer `mentions` payloads while the inserted token remains in the text.
- Member draft publish now sends the current compose payload to `/posts/draft/publish`, so selected mention metadata is not dropped at publish time.
- Institution edit mode now has deterministic `Cancel` / `Save changes` actions and no longer derives the save affordance from publish permission.

Validation recorded:

- `flutter analyze` passed with no issues.
- Added `test/governed_tag_autocomplete_selection_test.dart` covering tap and keyboard mention insertion.
- `flutter test -r expanded test\governed_tag_autocomplete_selection_test.dart` timed out after 240s before output.
- `flutter test -r expanded` timed out after 240s before output.

Post-push status:

- Pushed frontend `main` commit `759da23a152564c71614f56a604b475980ed7648`.
- `https://auraplatform.org` responded `200 OK` via Railway at 2026-07-21 05:56 UTC with `last-modified: Tue, 21 Jul 2026 05:20:56 GMT`.
- Authenticated production-flow verification of edit save and mention selection still requires a live authenticated session/account.
