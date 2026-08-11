# Decisions — aura_final

Last updated: 2026-08-11 UTC (Takeover audit continuity reconciliation; Identity Foundation Phase 1)

Founder-approved decisions governing this repository (recorded retroactively at continuity establishment, 2026-07-21).

## 2026-08-11: Identity Foundation Phase 1 implemented locally

Backend record: `../aura-backend/docs/2026-08-11-identity-foundation-phase-1-implementation.md`.

Decision status: locally implemented and certified; awaiting founder Gate 2 review and commit authorization.

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

**Chapter status: Identity Foundation Phase 1 is now COMPLETE.** Remaining open item: minimum-age/eligibility policy, an explicit founder decision, not inferred or implemented.

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
