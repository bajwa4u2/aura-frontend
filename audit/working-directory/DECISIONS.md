# Decisions — aura_final

Last updated: 2026-08-14 UTC (Realtime Architecture Correction — Phase 0 approved and completed; Thread Call Lifecycle Convergence code fixes from earlier this session remain approved/landed)

Founder-approved decisions governing this repository (recorded retroactively at continuity establishment, 2026-07-21).

## 2026-08-14: Realtime Architecture Correction — architecture APPROVED (all six §18 decisions resolved); Phase 0 (canonical contracts + executable test harness) authorized and COMPLETE.

Founder reviewed `../aura-backend/capability/REALTIME_ARCHITECTURE_CORRECTION_LONG_TERM_ARCHITECTURE_AND_MIGRATION_PLAN.md` (previously recorded here as "NOT YET A DECISION") and resolved all six §18 decisions, superseding that earlier entry:

1. Two-axis session+participant lifecycle model — **APPROVED**, over a single flattened enum.
2. Meetings separate-orchestrator recommendation — **APPROVED** over continued full sharing or full separation, but scoped: the orchestrator itself is NOT implemented in Phase 0, only its boundary over shared lower-level contracts.
3. Phase 7 (Meetings orchestrator) sequencing — **stays LAST**. Meeting Attendee Context Restoration was separately approved to pull forward independently, but was not implemented beyond proving the boundary via Meetings contract fixtures.
4. iOS CallKit/PushKit scope — **NOT core architecture**; own future roadmap chapter.
5. `PresenceService` in-memory cache — **derived/acceleration-only**, not re-litigated by Phase 0, pending production observability.
6. Event-contract renaming — **APPROVED**, via dual-emit, not flag-day.

Founder then authorized Phase 0 itself. **Standing fact, unchanged, regardless of which target was chosen**: Meetings currently has no dedicated backend service or frontend controller — it is entirely `isMeetingSession`/`surfaceType === MEETING` branches inside Thread/DM-owned code (`RealtimeController`, `RealtimeSessionService`, `RealtimeContinuityAuthorityService`, etc.). Phase 0's new `lib/core/realtime_canonical/` (mirroring the backend's `src/realtime/canonical/` 1:1) implements the target session/participant lifecycle, device/socket-binding, precedence/reconciliation, and event contracts as pure, isolated Dart, proven by the same 29-scenario + 4-Meetings-fixture deterministic harness as the backend (33/33 passing, `flutter analyze` clean). Explicit instruction, honored: nothing wired into production; Phase 1 does not begin automatically. Full technical detail: `CURRENT_STATE.md`'s matching entry.

## 2026-08-14: Phase 0 CLOSEOUT — JOIN_FAILED/SESSION_FAILED doctrine FROZEN; canonical architecture documents moved into governed version control (backend-owned, this repo references).

Founder resolved the single remaining open item from Phase 0. **Frozen: JOIN_FAILED is participant-scoped, SESSION_FAILED is session-scoped and never automatically derived from participant state** — see the full doctrine text in the paired backend `DECISIONS.md` entry (identical wording governs both repos). Implemented in this repo's mirror: doc comments on `CanonicalParticipantStatus.failed`/`CanonicalSessionStatus.failed` in `lib/core/realtime_canonical/participant_lifecycle.dart`/`session_lifecycle.dart`; new `sessionFailed` canonical event added to `event_contract.dart`; 4 new regression tests in `test/realtime_canonical/join_failed_session_failed_doctrine_test.dart`. Practical suite and `flutter analyze` re-verified clean.

**Canonical documents moved.** The architecture document and Phase 0 compatibility contract now live at `aura-backend/capability/REALTIME_ARCHITECTURE_CORRECTION_LONG_TERM_ARCHITECTURE_AND_MIGRATION_PLAN.md` and `aura-backend/capability/REALTIME_ARCHITECTURE_CORRECTION_PHASE_0_COMPATIBILITY_MIGRATION_CONTRACT.md` — `aura-backend` owns them (canonical session/participant lifecycle truth is backend-owned); this repo's continuity docs reference that path rather than holding a duplicate copy, per explicit instruction not to maintain independent full copies in both repos.

**Zero founder lifecycle-model decisions remain open from Phase 0.** Phase 1 (Backend Canonical Lifecycle / Participant Truth) is named next and has explicitly NOT started.

## 2026-08-14: Thread Call Lifecycle Convergence — founder certification of the transport repair failed 3 of 4 scenarios; root-caused and fixed the two provable defects. FROZEN DOCTRINE established.

Founder tested `cd256d3` (the transport ownership repair) directly and found: explicit caller cancel PASS; natural invite expiry asymmetric FAIL (receiver clears, caller never does); successful accept could still show "Call ended"/Retry-Dismiss alongside a working connection; accept could still return to an unresolved spinner. Explicit instruction: continue end to end, no more isolated patches, prove root causes with evidence.

**Natural expiry, PROVEN precisely**: `correspondence-orchestrator.service.ts`'s `maybeEndIdleSession()` already had the correct aggregate check and already called `endLive()` — but `endLive` → `broadcastCallTerminal()` deliberately excludes `params.actorUserId` from the broadcast (correct for a genuine user-initiated end). `maybeEndIdleSession` passes the caller/host as that actor to represent an auto-end that wasn't actually their action — so the caller, the one person who needed reconciling, was the one excluded by the existing design. Fixed with a dedicated `RealtimePolicyService.broadcastNoAnswerTruth()` → `RealtimeGateway.broadcastNoAnswer()` call, broadcasting directly to the caller via `/realtime` before `endLive` runs, independent of `broadcastCallTerminal`'s exclusion — which is left unchanged, since it's correct for its other callers.

**FROZEN DOCTRINE — applies to any future "auto-end" / "idle cleanup" logic that reuses a genuine user-action code path with a synthetic actor**: if a cleanup/sweep process calls a method designed for real user actions (like `endLive`) using a synthetic `actorUserId` to represent "the system did this on someone's behalf," any exclude-the-actor broadcast logic inside that method will silently exclude the person who most needs to know. Reconcile the affected party directly, outside the reused method, rather than trying to make the actor-exclusion conditional (which would risk regressing the method's other, correct callers).

**Successful-accept contradiction, best-evidence fix**: `AuraIncomingLiveLayer._joinError` was sticky, uncoordinated local state — nothing external (a later successful join for the same call) ever cleared it. New pure function `joinErrorIsStale()` (`lib/features/realtime/presentation/incoming_live_overlay.dart`) implements the founder-mandated precedence invariant: authoritative JOINED truth for a session invalidates stale failure presentation for that exact session, never a different one. A fresh live reproduction pinpointing the exact real-time trigger was not additionally obtained (the founder's own certification served as reproduction evidence for the symptom); this is the best-evidence architectural fix for the class of bug the code supports, disclosed as such.

Certification: backend 1488/1488 (+3), frontend analyzer clean, practical suite 214/214 (+5), debug APK build succeeded.

**Explicitly not touched**: `session:participant.left` Thread/DM semantics (no grace period — still unproven as the cause, founder explicitly forbade reflexive Meetings-style grace); `broadcastCallTerminal`'s actor-exclusion (correct for its other callers); the transport ownership repair itself (kept, unchanged, this builds on top of it).

## 2026-08-14: Thread Call Transport Ownership — permanent root repair. FROZEN DOCTRINE established.

Founder rejected the earlier join-retry epoch fix as insufficient after reproducing the stuck spinner again, and mandated a full forensic closure before any further symptom-level patching: prove the exact concurrency defect, implement single-flight transport ownership, add regression tests, certify, and return once — not another micro-patch.

**Root cause, proven via live device + backend log correlation**: two independent, desyncable "is something already connecting?" guards (`RealtimeController`'s own `state.connectionStatus` check, separate from `RealtimeSocketService`'s own guard) let multiple concurrent join attempts each independently call socket `connect()` — which always disconnected and recreated the shared socket — each destroying a sibling attempt's in-progress connection. Captured directly: three real attempts producing an empty socket id each time, zero successful server acks, confirmed via Railway logs showing zero `session:join` records for the affected user in that session.

**FROZEN DOCTRINE — applies to any future shared-resource establishment/reconnection logic in this repo, not just realtime sockets:** a resource that must be established exactly once per logical need (a socket connection, a device handle, any stateful external resource) must have exactly ONE code path that decides to (re)establish it, gated by a genuine single-flight primitive (a `Completer`/generic `SingleFlight<T>` that a second caller can *await*), never a boolean or enum-state check that a concurrent caller can race past. See `lib/core/concurrency/single_flight.dart` — the extracted, independently-tested primitive this repair introduced; reuse it rather than hand-rolling another guard.

**Fix**: `RealtimeSocketService.connect()` → `ensureConnected()`, rebuilt on `SingleFlight<void>`. Transport readiness formally requires `.connected` AND non-empty server-assigned `.id` (an invariant from an earlier fix this session, now the hard gate `emitAck()` enforces by throwing rather than silently waiting). Every competing reconnect-decision point removed: `_performJoinWithRetry`'s pre-retry reconnect, `join()`'s pre-check, `_rejoinAfterReconnect`'s pre-check — `_performJoin`'s own `connect()` call is the sole path now, for every entry point (fresh join, resume, reconnect-after-drop).

**Live-verified**: a real call placed from the founder's signed-in browser to a locally-built, adb-installed debug APK on the founder's Pixel, with continuous device + backend log capture. Result: single-attempt join, non-empty socket id immediately, full signaling round trip in ~1.3s, stable 3+ minutes, clean end. See `CURRENT_STATE.md` for the full captured sequence.

**Tests**: `test/single_flight_test.dart` (5), `test/realtime_socket_service_test.dart` (3) — new deterministic coverage for the exact concurrency property, since none existed before and this defect must not go untested again.

Certification: analyzer clean, practical suite 209/209 (up from 201), debug APK + web release builds both succeeded. Backend untouched, re-verified clean (1485/1485, two pre-existing unrelated tsc errors noted out of scope).

**Explicitly deferred, per founder instruction**: `session:participant.left` / Thread-DM reconnect-grace semantics were NOT touched — founder's own evidence review found the captured "Call ended" instance was the caller's own explicit `session:leave` on a healthy, single socket, not a stale-registration artifact. Whether it still reproduces after this transport fix is unconfirmed (not re-observed during verification, but not exhaustively retested either) — do not add Thread/DM reconnect grace preemptively; only if post-repair evidence proves it's still needed.

## 2026-08-14: Meetings attendee-join router regression — restored at the shared router boundary. FROZEN DOCTRINE established.

Founder production evidence: a booked/invited Meeting attendee was redirected to Institution Sign In on join, instead of entering through the certified attendee path. Meetings is frozen/protected; founder required a proven, deterministic root cause before any restoration, then authorized the fix once it was code-proven (not a workaround).

**FROZEN DOCTRINE — the layered-authority principle, applies to any future shared-boundary work touching institution-owned resources, not just Meetings:** AUTHENTICATION determines who the person is. INSTITUTION AUTHORITY (`institutionAccess.hasAccess`) determines whether that person may act *as* the institution. A separate, resource-specific ATTENDANCE/PARTICIPATION AUTHORITY (backend-enforced, e.g. `MeetingService.getMeetingForMember`'s host/participant/invitee check) determines whether they may use a specific institution-owned resource. **An institutionId present in a URL path segment is never sufficient grounds to require Institution Authority — it may exist purely for URL/context purposes.** Do not write or approve a router gate that infers institution-actor identity from institutionId path presence alone; check what authority the underlying resource/backend endpoint actually requires.

**Root cause**: `requiresInstitutionAccess` (now `requiresInstitutionAccessForPath`, extracted to top-level for testability) gated the entire `/institution/:id/...` path space with one blanket regex since 2026-05-01. Meetings' institution-namespaced route family (added 2026-07-11, for URL context only) was never carved out. Proven NOT a recent regression — the two-months gap between the gate and the link generation, both predating Identity Foundation Phase 1 and this session's shared-runtime work, rules out any change made in the current work stream. Proven safe to fix: the actual backend endpoint (`GET /meetings/:id`) has zero dependency on institution-actor role.

**Fix, zero Meetings-file changes**: `router.dart` gained one carve-out — `/institution/:id/meetings/:meetingId(...)` (record/prep/room/waiting/live/summary/post-meeting) no longer requires institution access; `/institution/:id/meetings` (list) and `/meetings/new` (creation) remain gated as genuinely institution-staff-only. New regression test `test/router_institution_access_test.dart`. Certification: `flutter analyze` clean, practical suite 201/201 (up from 197). Backend untouched — its authorization was correct from the start; this was purely a frontend routing-classification bug.

Checked and ruled out, not fixed (no reported defect, no user-facing symptom): `meetings_home_screen.dart`'s identical unconditional-institution-path pattern in `_meetingPathFor` — unreachable except by users who already have institution access (that screen only mounts under the already-gated `/institution/:id/meetings` list route). Checked Institution Spaces for the same pattern — no equivalent public-entry point exists there.

## 2026-08-14: Permanent Call Lifecycle Reconciliation — founder ordered a stop to incremental patching, mandated a full forensic trace, root cause found and fixed. FROZEN PATTERN established.

Founder context: after several rounds of evidence-based device fixes this session (GoRouter crash, notification-tap routing, socket staleness, speaker routing, dock overflow — all confirmed working on the founder's own device), two symptoms kept recurring across fixes: the Android ring notification outlasting accept by ~24s, and a Retry/Dismiss error banner appearing on calls that had already connected and ended cleanly. The founder explicitly named these as evidence of **multiple competing state holders that never converge to one truth**, not independent cosmetic bugs, and ordered a full file/method-level forensic trace before any further local workaround.

**Root cause, proven at the code level (not inferred from symptoms):** `RealtimeController._performJoinWithRetry()` wraps each join attempt in `Future.timeout(15s)`. **`Future.timeout()` does not cancel the underlying computation — it only stops awaiting it.** A `_performJoin()` attempt that ran past 15s due to slow-but-legitimate network conditions (ICE/media negotiation, which happens after the authoritative `joinState: joined` transition and is non-fatal by an earlier fix) kept running in the background while the retry loop started a second, fully concurrent `_performJoin()` for the same session. Live device logs from earlier in this same session had already captured the symptom (three `session:join` emissions for one session within 6 seconds) without an explanation at the time.

**FROZEN PATTERN — applies to any future retry-around-a-timeout logic in this repo, not just this call path:** wrapping an async operation in `.timeout()` and retrying on `TimeoutException` is only safe if either (a) the operation is provably idempotent end-to-end, or (b) each attempt is epoch/generation-tagged so a superseded attempt's late completion — success or failure — can never mutate state a newer attempt now owns. `_performJoin` now takes an `epoch` int, checked before every state-mutating transition; `_performJoinWithRetry` also short-circuits to success if the session is already `isJoined` by the time a retry would start. Do not reintroduce a bare `.timeout()`-retry loop against shared mutable state anywhere in this codebase without this guard.

Second, independent finding: the dual push-delivery pipeline (direct + canonical) recalled from an earlier chapter's memory as a possible contributor to the ring-duration symptom was **explicitly re-verified against current backend code and found not to exist anymore** — `PushNotificationService.sendToUser()` has a single production call site today (`NotificationDeliveryAuthorityService`, with its own dedup guard). The ring symptom is fully explained by Android's `USAGE_NOTIFICATION_RINGTONE` channel semantics (not cancelled until explicit `NotificationManager.cancel()`), now consolidated to one authoritative choke point (the incoming-call bridge's removal listener) instead of two scattered action-site calls that missed remote-driven terminations.

Certification: `flutter analyze` clean, full practical suite 197/197 (1 pre-existing unrelated golden skip), `flutter build apk --debug` succeeded. Backend: 1485/1485 including two new regression tests. Not yet founder-device-retested (device not connected at completion) — narrow checklist recorded in `NEXT_WORK.md`.

## 2026-08-14: Native Background/Terminated Notification Certification — Phase D repair approved and implemented. FROZEN DOCTRINE established (backend-owned, applies here too).

Backend record: `../aura-backend/docs/2026-08-14-native-background-terminated-notification-certification.md`. The frozen doctrine — **ACCEPT/DECLINE TRUTH MUST PROPAGATE FROM THE AUTHORITATIVE ACTION ITSELF; socket/media join is evidence of realtime entry, not the sole acceptance signal; RINGING/CONNECTING → ACCEPTED/JOINING → CONNECTED are never collapsed** — is recorded in full in the backend `DECISIONS.md` and working memory `arch_accept_decline_truth_propagation.md`. This repo's implementation of it: `RealtimeState.acceptedByPeer`/`isPeerAcceptedNotYetPresent`, the `call:accepted` WS case, and the new "Accepted — joining…" UI state — any future call-state work in this repo must preserve this distinction, not reintroduce a collapse of ACCEPTED into CONNECTED. Also decided/implemented this chapter: foreground incoming-call sound+haptic via `SystemSound`/`HapticFeedback` (not a new audio-plugin dependency); Thread/DM speaker-route control via `flutter_webrtc`'s `Helper.setSpeakerphoneOn` (mobile-native only, resolved fresh per call, never persisted). Committed `74d7875`, pushed to `origin/main` — a controlled commit/push for founder device certification, not chapter closeout; founder post-deployment device certification remains PENDING.

## 2026-08-13: Communication Timeline Authority — Phase 1 — Gate 2 approved, committed, pushed. CHAPTER CLOSED.

Backend record: `../aura-backend/docs/2026-08-13-communication-timeline-authority-phase1-implementation.md`. Founder froze the outcome vocabulary and attention rules backend-side (see backend `DECISIONS.md`), then approved Gate 2. **Committed `38765bc` ("feat: establish communication timeline authority phase 1"), pushed to `origin/main` (`6e1f7aa..38765bc`).** Paired backend commit `47a4fae`. This repo's decisions:

1. `activity_screen.dart`'s dead `type == 'LIVE'` branch is activated with real data, not rebuilt — `_buildTitle()` extended for the four outcomes, `direction` disambiguates outgoing vs. incoming phrasing. `_buildSubtitle()`/`_ctaLabel()` required no changes.
2. `_iconForType()` gained a `LIVE` case. Outcome-specific icon coloring (missed=red, etc.) was deliberately not attempted — the leading-icon widget only receives `type`, not the full item; threading that through is a larger, separate change.
3. `NotificationsRepository._normalizeNotificationItem()`'s `item['data']` → `item['payload']` fallback is a general fix, not scoped to Timeline items only — the mismatch was silently present for every notification type relying on nested fields with no top-level column equivalent.
4. Widget tests mount the real, full production `ActivityScreen` (previously zero coverage) rather than a minimal harness, consistent with this repo's established testing discipline from the prior chapter.

Protected: Meetings, Reachability Authority, Session Continuity Authority, Communication Runtime Lifecycle Authority, Device Communication Presence Authority, Canonical Call Notification Stage A, Institution Authority, Identity Foundation, Link Intelligence / OG Preview — none touched; full practical suite (178/178, up from 172) + web build re-verified.

## 2026-08-12: Compose Link Intelligence / OG Preview — Phase 1 — Gate 2 approved, committed, pushed. CHAPTER CLOSED.

Final certified scope: Member Posts + Institution Posts + Institution Announcements share one canonical shared frontend module (`lib/core/link_preview/`), wired identically into all three composer screens and rendered identically across `post_card.dart`, `unified_feed_card.dart`, and `announcement_detail_screen.dart`. Founder Gate 2 approved both the original Member/Institution-Posts report and, same day, the Announcement extension. **Committed `6303882` ("feat: establish link intelligence phase 1"), pushed to `origin/main` (`9d0d558..6303882`).** Paired backend commit `ec09202` in `../aura-backend` (`80d9145..ec09202`). No production query, deployment polling, or live production verification performed at any point in this chapter, per explicit instruction. Recorded here so a future takeover audit does not have to reconstruct authorization from git history alone — the two chapter entries below (Announcement extension, then the original Member/Institution-Posts implementation) are the full decision record; this entry is the closure marker.

## 2026-08-12: Compose Link Intelligence / OG Preview — Announcement extension approved and implemented, committed as part of the closing feature commit

Founder reviewed the Member/Institution-Posts-only Gate 2 report, approved it, and required one further scope item before advancing to Communication Timeline Authority: extend the identical capability to Institution Announcements. Decisions:

1. `institution_announcement_composer.dart` wires the exact same `ComposeLinkDetector`/`LinkPreviewCard` pair as the other two composers, no third variant.
2. `announcement_detail_screen.dart`'s rendering is a top-level block above the `AuraCard`, mutually exclusive with media — matching this screen's own pre-existing media-above-card layout (a genuine, named-acceptable layout adaptation), not a divergent OG-preview system.
3. The compact list-view `_AnnouncementCard` (`announcements_screen.dart`) was deliberately left unwired — thumbnail-only summary layout, no room for a rich card without a separate redesign.
4. `institutions_repository.dart`'s `createInstitutionAnnouncement`/`updateInstitutionAnnouncement` send `linkPreviewId`/`linkSourceUrl` unconditionally (unlike every other field in those two methods) — the one deliberate divergence from that file's own convention, required so an explicit `null` reaches the backend and can actually clear an attached link.
5. Member Posts and Institution Posts are now also explicitly named protected systems for this chapter — zero files under either surface were touched, confirmed via `git status`.

Protected: all previously-named systems plus Member Posts and Institution Posts — none touched; full practical suite (172/172, up from 166) + web build re-verified.

## 2026-08-12: Compose Link Intelligence / OG Preview — Phase 1 (Member Posts + Institution Posts) implemented, committed as part of the closing feature commit

Backend record: `../aura-backend/docs/2026-08-12-compose-link-intelligence-og-preview-phase1-implementation.md`.

Decision status: implemented, locally certified, founder Gate 2 approved. Committed `6303882` ("feat: establish link intelligence phase 1"), pushed to `origin/main`.

Decisions:

1. One shared module, `lib/core/link_preview/`, owns detection (`firstUrlIn`), resolution (`LinkPreviewService`), debounced controller-wiring (`ComposeLinkDetector`), and rendering (`LinkPreviewCard`) — neither `compose_screen.dart` nor `institution_post_composer_screen.dart` implements its own version of any of these.
2. `ComposeLinkDetector` follows the existing `GovernedTagAutocomplete` pattern (wraps `TextEditingController`, plain Dart class not a widget) rather than inventing a new composer-extension shape.
3. `LinkPreviewCard` is consumed by both `post_card.dart` (member feed) and `unified_feed_card.dart` (institution/broader feed) — no second rendering widget was created for institution posts.
4. `Post.linkUrl`/`.linkSiteName` were added because `post_card.dart` already expected them (a real, pre-existing dead-code path found by audit, not assumed) — adding the missing model fields activates that existing rendering with zero changes to the widget file itself.
5. `FeedItem` gained all 5 link fields; `FeedReply` deliberately did not — link previews are scoped to top-level content, not reply text, consistent with how institution replies/reshares are treated elsewhere in this codebase.
6. Compose payload convention: `linkPreviewId`/`linkSourceUrl` are always resent on every save/publish (undefined leaves unset, explicit `null` clears) — matching the existing `primaryTopic`/`tagReferences` convention rather than inventing a new patch-semantics.
7. Draft/edit hydration reads the post's own already-resolved flat link fields directly — no redundant `resolve()` network call fires on opening an existing draft/post.
8. Widget tests for this chapter mount the real, full production composer screens (`ComposeScreen`, `InstitutionPostComposerScreen`) rather than a minimal harness only, after direct founder pushback on test-coverage framing during this chapter (five separate messages pressing on composer test coverage, culminating in "i do not want it under perform"). This is explicitly scoped to the Link Intelligence feature — comprehensive coverage of every other composer capability remains a separate, undone, future chapter, stated plainly rather than implied as complete.
9. Announcements were deliberately not wired on this client — the founder named member and institution compose specifically; Announcements is a third, distinct composer surface out of this chapter's bounded scope.

Protected: Meetings, Reachability Authority, Session Continuity Authority, Communication Runtime Lifecycle Authority, Device Communication Presence Authority, Notification Delivery Authority, Canonical Call Notification Stage A, Institution Authority, Identity Foundation — none touched; full practical suite (166/166, up from 147) + web build re-verified.

## 2026-08-11: Identity Foundation Phase 1 implemented locally

Backend record: `../aura-backend/docs/2026-08-11-identity-foundation-phase-1-implementation.md`.

Decision status: Gate 2 approved, committed `56a0bb7` ("feat: establish identity foundation phase 1"), pushed to `origin/main`. Paired backend commit `18b2cfb`.

Decisions:

1. `identityBaselineCompleteProvider` mirrors `emailVerifiedProvider`'s exact contract (true/false/null=wait) rather than inventing a new async-state shape.
2. Blocking is done entirely in `router.dart`'s `redirect` callback, reusing the proven pattern from email verification and institution access — not a new root-level widget host. `ThreadCallLifecycleHost` was read as a reference precedent but is a wrapping/overlay pattern, not a blocking one, and was correctly not reused for this.
3. The identity-baseline gate is checked before the email-verification gate in the redirect chain (DOB is "the first identity field"), and the two gates explicitly cannot deadlock each other (`requiresVerifiedEmail` excludes `kCompleteIdentityRoute`; the identity-baseline check does not depend on email-verification state).
4. No age-eligibility threshold is enforced. None exists anywhere in this codebase today. Explicit, open founder decision, not inferred or implemented.
5. `_DirectoryEntry.id` is now derived from a single canonically-resolved `userId` rather than two independently-ordered fallback chains, fixing the founder-reported "member identities don't resolve" defect for Thread/Space creation.
6. Institution-space creation has no member-picker UI on this client today (confirmed by full-file audit) — nothing to patch there.
7. The regression test added for the identity-resolution fix was verified to fail against the pre-fix code (temporary `git stash`) before being verified to pass against the fix — a proven, not assumed, regression guard.

Protected: Meetings, Reachability Authority, Session Continuity Authority, Communication Runtime Lifecycle Authority, Device Communication Presence Authority, Notification Delivery Authority, Canonical Call Notification Stage A, and the already-certified Correspondence entry flow behavior — none touched; full practical suite + web build re-verified.

## 2026-08-11: Identity Foundation Phase 1 — institution-space member selection (second pass), chapter COMPLETE

Founder required institution-space member selection completed end to end, with explicit reuse of the canonical identity path rather than a second identity model.

Decisions:

1. The client-side identity model (`_DirectoryEntry`/`_memberEntryFromMap`/`_dedupeEntries`) was extracted from `new_conversation_screen.dart`'s private scope into a public module, `lib/core/directory/directory_entry.dart` — this repo now has exactly one canonical member-identity resolver, not a duplicate one for institution use.
2. Institution-space creation gets its own picker widget (`MemberPickerField`, `lib/core/directory/member_picker_field.dart`) rather than being forced through `NewConversationScreen`'s live-platform-search UI — the two surfaces have genuinely different contracts (a bounded institution roster vs. live platform-wide search with no server-side search endpoint), so the shared thing is the identity *model*, not one UI forced onto both products.
3. Candidates are sourced from `GET /institutions/:id/members` (the institution's own roster), not a general user search — consistent with the backend's own `INVITE_ONLY` join-time restriction.
4. `MemberPickerField` force-remounts (bumped key token) after a successful create or when the form closes/reopens, so its internal selection state can never drift from the parent's `_selectedMembers` mirror — caught and fixed during this pass before certification, not shipped as a latent bug.

Protected: Meetings, Reachability Authority, Session Continuity Authority, Communication Runtime Lifecycle Authority, Device Communication Presence Authority, Notification Delivery Authority, Canonical Call Notification Stage A, Institution authority, and the already-certified Correspondence entry flow + Identity Foundation DOB baseline behavior — none touched; full practical suite (147/147) + web build re-verified, and `new_conversation_screen_test.dart`'s existing suite re-verified green after the shared-module extraction.

**Chapter status: Identity Foundation Phase 1 is now COMPLETE.** Founder authorized commit and push, 2026-08-11: committed `56a0bb7`, pushed to `origin/main` (`46eda5d..56a0bb7`), establishing the clean rest point alongside paired backend commit `18b2cfb`. Remaining open item: minimum-age/eligibility policy, an explicit founder decision, not inferred or implemented.

## 2026-08-11: Continuity reconciliation — Gate 2 closure recorded for three chapters

A Claude takeover audit (read-only) found that Notification Delivery Authority Phase 1, Device Communication Presence Phase 1 (both backend-owned), and the Correspondence entry flow repair were each committed and pushed days before this entry, but this file's entries never recorded the actual Gate 2 approval/commit event. Documentation-process gap only — underlying authorization and push are real and independently verified via `git log`/`git show` in both repos.

1. **Notification Delivery Authority Phase 1 — Gate 2 approved. Backend committed `b23ff4419089483b8f5132f6ab4036d50ebb87ef`, pushed to `origin/main`.** No Flutter change in this chapter.
2. **Device Communication Presence Phase 1 — Gate 2 approved. Backend committed `3bf8d67976c230767e0e108788d67f670dd883e3`, pushed to `origin/main`.** No Flutter change in this chapter.
3. **Correspondence entry flow repair — Gate 2 approved. Flutter committed `7a47fefe5924ea19a1e483475182d72383b10687`, pushed to `origin/main`; paired backend commit `9739ad5fb7551a0857ad22159add3e102eb7cc40`.**

## 2026-08-09: Notification Delivery Authority Phase 1 is backend-owned

Backend record: `../aura-backend/docs/2026-08-09-notification-delivery-authority-phase-1-implementation.md`.

Decision status: Gate 2 approved, backend committed `b23ff4419089483b8f5132f6ab4036d50ebb87ef`, pushed to `origin/main` (see the 2026-08-11 continuity reconciliation entry above). No Flutter implementation was authorized or performed in this chapter.

Flutter contract decisions:

1. Existing `call:incoming` socket event name and payload remain the client contract.
2. Existing direct Stage A push payload remains the client contract.
3. Existing canonical Communication-linked push payload remains the client contract.
4. Existing notification tap/deeplink behavior remains the client contract.
5. `NotificationBridge`, `incomingCallBridgeProvider`, service-worker behavior, and root Thread lifecycle ownership were not changed.
6. Native background/terminated notification certification remains mandatory and unresolved before native production release.

## 2026-08-08: Correspondence entry flow contract repaired locally

Repair record: `docs/2026-08-08-correspondence-entry-flow-repair.md`.

Decision status: Gate 2 approved, committed `7a47fefe5924ea19a1e483475182d72383b10687`, pushed to `origin/main` (see the 2026-08-11 continuity reconciliation entry above).

Decisions:

1. Public Messages -> Create remains the canonical communication entry surface for direct private conversations and shared spaces.
2. Selection state is owned by stable selected-entry identity, not by transient search result membership.
3. One selected other person with no shared-space title creates a `PRIVATE` one-to-one conversation.
4. Multiple selected people, or an explicit shared-space title, creates a shared space.
5. Circle, Workroom, and Salon remain distinct UI modes; backend now accepts `WORKROOM` and `SALON`, while `STUDIO` remains backend-compatible for existing callers.
6. User-facing create failures should use safe application error mapping rather than raw transport exception text.
7. Meetings and certified communication authorities remain protected and unchanged.

## 2026-08-08: Device Communication Presence Phase 1 is backend-owned

Backend record: `../aura-backend/docs/2026-08-08-device-communication-presence-phase-1-implementation.md`.

Decision status: Gate 2 approved, backend committed `3bf8d67976c230767e0e108788d67f670dd883e3`, pushed to `origin/main` (see the 2026-08-11 continuity reconciliation entry above). No Flutter implementation was authorized or performed in this chapter.

Flutter contract decisions:

1. Existing REST join/decline endpoints and socket event names remain the client contract.
2. Flutter does not require a new DTO or endpoint to consume backend first-action-wins arbitration.
3. Existing `session:replaced` remains the released-client-compatible signal for a losing Thread/DM media runtime.
4. Activity, Notification Delivery, native background notification work, preferred-device policy, and manual transfer remain deferred.
5. Meetings remain protected and unchanged.

## 2026-08-08: Platform-wide engineering governance adopted

These are platform governance rules, not Flutter-only or backend-only implementation notes.

1. Certified product surfaces are protected by default.
2. Problems must be solved inside the owning feature/module before touching shared systems.
3. Any work touching shared systems, directly or indirectly, must identify the shared boundary, preserve existing behavior, execute targeted regression, certify shared-system health, and report that certification separately.
4. If preserving a certified shared system is impossible, implementation stops and founder approval is required before proceeding.
5. Future implementation tasks inherit these rules automatically.
6. Future audits must include governance-compliance review as well as feature correctness.
7. Newly adopted engineering doctrines must be recorded in working continuity during the next implementation task.

## 2026-08-08: Communication Continuity & Presence platform architecture discovered

Backend platform record: `../aura-backend/docs/2026-08-08-communication-continuity-presence-platform-architecture.md`.

Decision status: superseded by the frozen Chapter 1 contracts below. No Flutter implementation is authorized by the discovery record.

Platform authorities later approved in Chapter 1:

1. Communication Runtime Lifecycle Authority.
2. Notification Delivery Authority.
3. Device Communication Presence Authority.
4. Communication Timeline Authority.

Flutter boundaries:

1. `RealtimeController` remains the client media/session execution owner.
2. Stage 1 Thread lifecycle remains the Thread foreground adapter.
3. Meetings remain a protected certified system; Meeting live-room, waiting-room, admission, guest, host-control, reconnect, UX, and notification semantics must remain unchanged.
4. Future lifecycle/notification/device/timeline work must be authorized as platform infrastructure, not patched into one feature locally.

## 2026-08-08: Communication Continuity & Presence Chapter 1 contracts frozen

Backend contract record: `../aura-backend/docs/2026-08-08-communication-continuity-presence-chapter-1-contracts.md`.

Founder decisions resolved:

1. Approved authorities: Communication Runtime Lifecycle, Notification Delivery, Device Communication Presence, Communication Timeline.
2. Mandatory before Desktop/Android/iOS production release: Device Presence Phase 1, Notification Delivery Phase 1, native background/terminated notification certification, Communication Timeline Phase 1, iOS Firebase/APNs configuration confirmation, and Meetings preservation certification for shared authority implementation.
3. Multi-device Phase 1: ring all eligible devices, no preferred device, first ACCEPT/DECLINE wins globally, terminal sync to all other devices, one active media-owning device per user/session, deterministic stale-state cleanup.
4. Desktop: foreground app-level realtime interruption is required; background/minimized reliable system notification path is required before production release if supported by the desktop distribution/runtime model.
5. Calls must participate in canonical communication chronology before native production release.

No Flutter implementation is authorized by this contract decision.

## 2026-08-08: Pre-release connected-system health gate

Decision record: `docs/2026-08-08-pre-release-connected-system-health-audit.md`.

Current source is READY WITH NON-BLOCKING RISKS for founder-directed native test builds. This is a health gate only, not authorization to publish store builds.

Boundaries:

1. Meetings remain a protected certified surface and were certified healthy without product/runtime edits.
2. Backend Reachability Authority, Session Continuity Authority Phase 1, and Canonical Call Notification Stage A remain closed and reused as certified foundations.
3. Activity doctrine, multi-device arbitration, desktop native push, and Android/iOS background/terminated notification work remain deferred.
4. iOS build readiness depends on confirming the CI-provided `FIREBASE_IOS_CONFIG_BASE64` secure variable; its local absence is expected and is a release risk, not a source blocker.

## 2026-08-08: Canonical Flutter Thread-Call Lifecycle Stage 1 implemented

Stage 1 implementation is authorized, locally certified, committed, and pushed as `86de6e165931e96185a2e78a349bb5502065940a`.

Frozen decisions now implemented:

1. Thread-call lifecycle ownership is app-root owned from `AuraApp`, under the existing notification/app boundary.
2. `RealtimeController` remains the canonical client owner for realtime socket entry, signaling, ICE/media, and session execution.
3. The new Thread lifecycle owner coordinates intent and presentation only; it does not add backend states and does not replace shared realtime authority.
4. Root incoming-call presentation must not depend on `MemberShell`, Thread route lifetime, realtime-room route lifetime, or navigation position.
5. Activity doctrine, multi-device arbitration, and platform-specific background/native notification work remain deferred.
6. Meetings are a hard preservation boundary. Stage 1 did not edit shared realtime controller/state/socket/media files or Meetings-specific product code.

## 2026-08-08: Canonical Flutter Thread-Call Lifecycle Stage 1 blueprint approved, implementation not authorized

Blueprint: `docs/2026-08-08-canonical-flutter-thread-call-lifecycle-stage-1-blueprint.md`.

Founder architecture decision: Stage 1 combines foreground incoming-call ownership and caller/callee realtime synchronization into one canonical Flutter Thread-call lifecycle chapter. It is a Flutter chapter across web, desktop, Android, and iOS.

Frozen constraints:

1. Do not implement until founder authorizes coding.
2. Do not reopen backend Reachability Authority, Session Continuity Authority Phase 1, or Canonical Call Notification Stage A.
3. Do not change backend event names, payloads, schema, or Stage A push ownership.
4. Activity doctrine, multi-device arbitration, and platform background/native notification work are deferred.
5. Meetings must be preserved exactly as-is.

Approved design direction:

1. Use one app-level Thread-call lifecycle owner mounted from `AuraApp`.
2. Keep `RealtimeController` as the single active realtime socket/media/session owner.
3. Make caller start, recipient accept, and route join share one lifecycle entry API.
4. Move incoming-call foreground ownership out of shell-local overlay lifetime.
5. Add client-only Thread call presentation phases without adding backend states.

## 2026-08-08: Thread Calling Reliability collective audit - no Flutter implementation authorized

Authoritative audit: `../aura-backend/docs/2026-08-08-thread-calling-reliability-collective-audit.md`.

Accepted founder evidence: Chrome background receives Thread-call notification; Desktop foreground and iOS foreground do not show incoming interruption or Activity entry; Android previously showed no interruption/notification despite recovered backend FCM `SENT`; Party B accepted/participated while Party A remained visually stuck on `Connecting...`.

Current decisions/constraints:

1. No Flutter application/runtime/schema/client code change is authorized by this audit.
2. Do not reopen backend Reachability Authority, Session Continuity Authority Phase 1, or Canonical Call Notification Stage A.
3. Meetings remain a hard preservation boundary. Any shared realtime client change must prove Meeting behavior unchanged.
4. Treat the symptoms as one repair program until implementation evidence proves independence.

Recommendation only: next Flutter work should start by stabilizing foreground Thread `call:incoming` consumption at an authenticated app-root or equivalent always-mounted boundary, then address caller/callee realtime join-state synchronization, then multi-device terminal/replaced convergence, then platform-specific background/native notification handling.

## 2026-07-31: Orphaned Aura Editor sheet — retired (superseded, not abandoned)

`compose_screen.dart`'s `_openAuraEditorSheet`/`_runAuraEditor` (plus the sheet-only helpers `_spellingItems`, `_grammarItems`, `_legacySignals`, `_legacyRefinement`, `_listOfString`, and the `_auditBusy`/`_lastAuditAt`/`_auditResult`/`_auditError` state) have been deleted, along with the now-unused `ai/providers.dart` import. This was the March 2026 integrity-gate regression's dead remnant on the personal-post composer — discovered during the Communication Integrity System's editor-reconnection discovery to be completely unreachable (two references in the whole codebase: its own definition and its own recursive "run again" self-call; nothing external ever opened it).

**Sequenced correctly, not removed first:** per founder-approved retirement order, this was deleted only after the real replacement — Communication Integrity Review on institution announcements (`institution_announcement_composer.dart`, backed by `aura-backend`'s runtime-certified CIS pipeline) — was built and verified end to end (backend: 67 suites/799 unit tests + 21 real HTTP scenarios against a disposable database; client: full `flutter analyze` and `flutter test` clean). Confirmed zero routes or tests depended on the removed code before deleting it.

**This is a real capability moving to its correct, doctrine-governed home — not a feature abandoned.** The old sheet gated the wrong surface (personal posts, never institutional) against the wrong contract (legacy `/ai/editor-review` + `/ai/claim-audit`, not the certified Provider→Assessment→Policy→Publication pipeline) and conflated Writing Assistance with integrity review in one panel — exactly the confusion the new design (`lib/features/institutions/announcements/integrity/`) is built to keep separate. `claim_audit_screen.dart` (the standalone admin paste-box tool) is untouched — it's a separate, still-live tool, not part of this retirement.

Full record: `aura-backend/capability/COMMUNICATION_INTEGRITY_SYSTEM_ANNOUNCEMENT_INTEGRATION_PLAN.md`.

## 2026-07-21: AXR-1 closeout rulings

Decision, founder-issued to resolve the three items AXR-1's first delivery left open:

1. **No Meetings or Mentions nav destinations solely for badges.** Meeting notifications remain Activity-only until Profile → Participation → Meeting History exists. Mention notifications must deep-link to their referenced content instead of getting a dedicated tab — confirmed already true (see below), not a new build.
2. **Topic-seeded search is accepted as AXR-1's final behavior.** A dedicated topic-scoped view is future enhancement only, not required for this milestone.
3. **The institution post composer is in scope.** It is a real, routed, active production surface — inspected and confirmed, not assumed. It gets governed tagging like the other three composers. Meeting notes do not, because no meeting-notes composer exists yet; that's a future integration requirement, not a deferred build.

Verification for (1): `MENTION` notifications already carry `postId` (the reply/post containing the mention — backend `posts.service.ts`'s mention fanout: `postId: created.id`), and `notifications_screen.dart::_routeFor` already resolves `postId` → `/posts/:id`, a route that serves both posts and replies. No code change was needed — the deep-link requirement was already satisfied by existing infrastructure; verifying that first is what avoided building a redundant Mentions tab.

Reason: keeps the badge/nav surface exactly as large as real destinations justify (Single Intent Principle spirit — don't add a nav item whose only job is carrying a number), while confirming attention still reaches the user through Activity + the correct deep link.

Repository impact: `institution_post_composer_screen.dart` wired with `GovernedTagAutocomplete` (commit `a19547f`). No routing changes — the mention deep-link was verified, not built.

## 2026-07-21: Governed tagging is platform infrastructure, not a Post feature

Decision: `@member` / `@institution` / `#topic` tagging lives in `lib/core/tagging/` and is entity-agnostic (`TagKind` is an open enum). Any text-composing surface adopts it by wrapping its existing `TextEditingController`/`FocusNode` in `GovernedTagAutocomplete` — not by reimplementing autocomplete per surface.

Reason: the brief was explicit that tagging must generalize across posts, comments, replies, messages, announcements, meeting notes, Studio-generated content, and future editors without redesign per surface.

Alternatives considered: a Post-scoped mention widget extended ad hoc per surface — rejected; would recreate the exact per-surface drift the brief was trying to eliminate.

Repository impact: `lib/core/tagging/`; wired into post compose, thread messages, institution announcements (commit `39e3964`).

## 2026-07-21: Module attention derives from one source, never a parallel count

Decision: per-module unread badges (`module_attention.dart`) are a pure projection over the same notification rows the global Activity bell already polls. No module maintains its own unread count.

Reason: a second unread source is a second thing that can drift from the first — the exact "fragmented attention" defect the brief named as the problem to fix.

Repository impact: `moduleAttentionProvider`; wired into member shell side rail + bottom nav.

## 2026-07-21: Identity rendering precedence — canonical widget, not per-surface fallback logic

Decision: photo → institution logo → approved avatar → initials → placeholder, implemented once in `AuraAvatar` (`lib/core/ui/aura_platform_components.dart`). Surfaces rendering identity must delegate to it, not reimplement a `CircleAvatar`/initials fallback.

Reason: five surfaces had silently drifted from the canonical widget over time, each with its own incomplete fallback that skipped the image even when one existed. See `../aura-backend/audit/working-directory/DECISIONS.md` for the paired server-side decision (payloads must include the image field).

Repository impact: `admin_institution_members_screen.dart`, `new_conversation_screen.dart`, `space_screen.dart::_IdentityAvatar`, `meeting_detail_screen.dart`, `search_screen.dart::_InstitutionTile` — all five now delegate to `AuraAvatar` or an equivalent logo-with-fallback path (commit `39e3964`).

## 2026-07-11: No identity forms at meeting doors

The pre-join guest name/email form is deleted; identity renders from resolver outcomes only ("Invited as <name>", OTP verification, or login). Do not reintroduce.

## 2026-07-11: Member booking identity is read-only

Authenticated members see a read-only "Booking as" card; name/email fields render only for anonymous visitors.

## 2026-07-10/11: Live room internals are frozen

Meeting workspace surfaces migrated to AuraSurface tokens, but the live room's internals were explicitly left untouched and stay frozen.

## 2026-07-13: ROS Phase II verdict

VERIFIED WITH RESIDUAL FOUNDER EDITORIAL ITEMS. Audit and deployment were two separately authorized founder missions; follow the two-stage pattern.

## Frozen classification

Aura's product architecture was frozen 2026-07-12 (`AURA_REPRESENTATION_MODULE_INVENTORY.md`, `AURA_PLATFORM_ARCHITECTURE.md` — in `representation/inventory/`). When a later audit runs, Phase 1 is "confirm and cite," never "re-derive and re-freeze."
## 2026-07-21: Post editing reuses canonical composers

Decision: member and institution post editing must use deterministic edit modes in the canonical composer surfaces, not separate edit architectures or create-mode redirects.

Reason: public/member edit capability disappeared because the affordance was hidden and backend update rejected published posts. Institution edit routed into an unhydrated create-mode composer, risking duplicate/blank mutations. Edit mode must hydrate the existing row, preserve metadata, and save through update endpoints.

Repository impact: `ComposeScreen` accepts `editPostId` and saves through `PUT /posts/:id`; `InstitutionPostComposerScreen` loads `postId` through the single-post endpoint and saves through `PATCH /institutions/:institutionId/posts/:postId`.

## 2026-07-21: Topic selection is canonical state, not raw text

Decision: publishing/editing top-level posts requires selected `AuraTopic` state. Raw text that starts with `#` is tagging/autocomplete text only and does not satisfy topic selection.

Reason: backend routing and doctrine depend on canonical topic enum values. Text tokens can be incomplete, decorative, or stale.

## 2026-07-21: Mention selection is text plus canonical reference

Decision: governed mention autocomplete replaces the active text token and reports the selected canonical entity reference to the composer. The text remains the renderable source; the `mentions` payload carries selected member/institution ids for backend fanout.

Reason: plain `@handle` text is necessary for readable posts and normal editing, but selected autocomplete results must not lose their canonical identity before publish/update.
