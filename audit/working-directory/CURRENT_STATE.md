# Current State — aura_final

Last updated: 2026-08-08 UTC (Canonical Flutter Thread-Call Lifecycle Stage 1 locally certified; pending founder review/commit)

## Canonical Flutter Thread-Call Lifecycle Stage 1 implemented locally, 2026-08-08

Stage 1 implementation is present in the working tree, locally certified, and not committed. It follows `docs/2026-08-08-canonical-flutter-thread-call-lifecycle-stage-1-blueprint.md`.

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
