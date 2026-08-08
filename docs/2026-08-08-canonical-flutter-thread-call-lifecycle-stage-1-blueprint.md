# Canonical Flutter Thread-Call Lifecycle - Stage 1 Blueprint

Date: 2026-08-08 UTC
Mode: implementation blueprint plus local Stage 1 implementation record. Application code was edited after founder authorization; no backend/schema code was edited.

Scope: Flutter Thread/Direct Message audio/video call lifecycle across Web, Desktop, Android, and iOS.

Approved Stage 1 objective: combine foreground incoming-call ownership and caller/callee realtime synchronization into one canonical Flutter Thread-call lifecycle chapter.

Closed foundations preserved:

- Backend Reachability Authority remains closed.
- Backend Session Continuity Authority Phase 1 remains closed.
- Backend Canonical Call Notification Normalization Stage A remains closed.
- Activity doctrine is deferred.
- Multi-device arbitration is deferred.
- Platform background/native notification work is deferred.
- Meetings must remain exactly as-is.

## 0. Stage 1 Local Implementation Outcome

Status: implemented and locally certified in the Flutter working tree, pending founder Gate 2 review and commit authorization.

Implemented files:

- `lib/features/realtime/application/thread_call_lifecycle_controller.dart`
- `lib/features/realtime/presentation/thread_call_lifecycle_host.dart`
- `lib/app/aura_app.dart`
- `lib/app/shell/member_shell.dart`
- `lib/core/notifications/notification_bridge.dart`
- `lib/features/updates/incoming_call_bridge.dart`
- `lib/features/realtime/presentation/incoming_live_overlay.dart`
- `lib/features/correspondence/presentation/thread_screen.dart`
- `test/thread_call_lifecycle_controller_test.dart`

Phase outcomes:

- Phase A: app-root incoming-call ownership is mounted from `AuraApp` via `ThreadCallLifecycleHost`. `incomingCallBridgeProvider` is kept alive after member auth, `CorrespondenceLiveService.ensureConnected()` is called by the lifecycle owner on boot/resume, and `AuraIncomingLiveLayer` is no longer owned by `MemberShell` or `InstitutionShell`.
- Phase B: Thread caller start, Thread call-card join, and recipient accept route through `threadCallLifecycleProvider`, which records a single current-session lifecycle intent for the current ProviderScope/member session and delegates execution to the existing `RealtimeController`. Join attempts are deduped by `sessionId`. Existing external/background `/realtime/:sessionId?action=join` route behavior remains unchanged because shared realtime route edits were outside the approved gate and were not required for foreground Stage 1.
- Phase C: Thread presentation phases are projected from existing `RealtimeController` state: pre-join `Connecting...` corresponds to `joining`; joined-but-alone is `joined`; joined with remote participants and busy media is `mediaNegotiating`; joined with remote renderer/media-ready evidence is `connected`; reconnect/disconnect/error maps to `transportDegraded`; terminal/replaced/removed/failed states map to `ended`.
- Phase D: local certification passed after resolving the Flutter SDK Git safe-directory startup issue with the explicit `C:/flutter` safe-directory environment override.

Meetings preservation:

- No Meetings product files were edited.
- No shared realtime controller/state/socket/media files were edited.
- `RealtimeController`, `RealtimeState`, `RealtimeSocketService`, `RealtimeMediaService`, and generic realtime route behavior remain untouched.
- Root Thread overlay suppresses itself when the active realtime session is a Meeting session.

Stage 1 remains a client release chapter: web deploy, desktop build/deploy, Android release, and iOS release are required for installed clients to receive this fix.

Toolchain health record:

- Original blocker: Flutter test/build commands hung because Flutter tool startup could not reliably read the SDK git checkout at `C:/flutter` under the sandbox user. `dart.exe --version` was healthy; `git -C C:\flutter status -sb` exposed the safe-directory ownership problem.
- Recovery: added `C:/flutter` to Git `safe.directory` and ran Flutter certification commands with `GIT_CONFIG_COUNT=1`, `GIT_CONFIG_KEY_0=safe.directory`, `GIT_CONFIG_VALUE_0=C:/flutter`.
- Baseline control: `test\governed_tagging_test.dart` passed 11/11.
- Focused Stage 1 lifecycle test: `test\thread_call_lifecycle_controller_test.dart` passed 6/6.
- Relevant Stage 1/correspondence/realtime/notification/Meeting set passed 31/31.
- Repository-standard non-golden suite passed 125/125.
- `flutter analyze` clean.
- `flutter build web --release --no-wasm-dry-run` completed successfully.

## 1. Canonical Client Owner

Stage 1 should introduce one app-level Flutter owner for Thread-call lifecycle. It should be a long-lived Riverpod controller/service mounted from `AuraApp`, not a per-route widget and not a second realtime controller.

Working name: `threadCallLifecycleProvider`.

Placement:

- Provider file: `lib/features/realtime/application/thread_call_lifecycle_controller.dart`.
- Boot/mount: `lib/app/aura_app.dart`, inside the existing root app tree and auth lifecycle, likely through a small widget wrapper under `NotificationBridge` and above `MaterialApp.router.builder`, or by an explicit root `ref.read(threadCallLifecycleProvider)` after auth bootstrap.
- Visual presentation: `AuraIncomingLiveLayer` remains the overlay widget, but it becomes app-root mounted rather than shell-local. The same widget can keep its visual implementation if its ownership moves.

Ownership boundaries:

- `CorrespondenceLiveService`: transport input for `call:incoming`, `call:terminal`, and correspondence socket reconnect.
- `RealtimeSocketService`: secondary transport input for realtime terminal/incoming events and active room signaling.
- `incomingCallBridgeProvider`: state store/deduper for pending incoming calls; may remain the call-inbox state, but its subscriptions must be booted by the app-level owner rather than by shell-local overlay lifetime alone.
- `AuraIncomingLiveLayer`: presentation consumer only. It should not be responsible for ensuring the app is subscribed to call events.
- `RealtimeController`: single active realtime session/media owner. Do not duplicate it.
- Router/navigation: consumer of lifecycle intent; should route to `/realtime/:sessionId?action=join` only through one canonical call-entry method.
- `NotificationBridge`: foreground push input, not the canonical owner. It may inject call payloads into the same app-level lifecycle only for foreground FCM/Web push fallback.

Survival requirements:

- Route changes: lifecycle provider stays alive across all routes.
- Thread navigation: lifecycle does not depend on `ThreadStateWrapper`.
- Background/foreground transitions: `AuraApp.didChangeAppLifecycleState` resumes correspondence socket and asks lifecycle to reconcile pending/active call state.
- Shell transitions: not mounted in `MemberShell`/`InstitutionShell` only.
- Desktop window state changes: foreground socket consumption remains owned by app root.
- Mobile resume: lifecycle resumes socket and reconciles pending calls; background notification display remains deferred.
- Accept/navigation into realtime room: the same `RealtimeController` instance owns join, media, signaling, and visible room state.

## 2. Incoming Call Ownership

Current path:

1. Backend emits existing `call:incoming`.
2. `CorrespondenceLiveService` listens if connected.
3. `incomingCallBridgeProvider` subscribes to `CorrespondenceLiveService.events` and `RealtimeSocketService.events`.
4. `AuraIncomingLiveLayer` watches `incomingCallBridgeProvider` and `notificationsControllerProvider`.
5. `AuraIncomingLiveLayer._joinCurrent()` calls `RealtimeController.join(sessionId)`, removes bridge state, marks read, and navigates.
6. Decline calls `RealtimeRepository.declineInvite(sessionId)` and removes local bridge state.

Problem:

- `AuraIncomingLiveLayer` is mounted in `MemberShell`/`InstitutionShell`; it is not mounted at `AuraApp` root.
- `incomingCallBridgeProvider` is a long-lived provider, but the practical subscription depends on something reading/watching it.
- The globally booted `RealtimeReconciliationController` ignores `call:incoming`.
- Chrome background notification can work through Web Push service worker while foreground native/desktop Flutter consumption remains unowned.

Stage 1 design:

- Root-call owner must eagerly keep `incomingCallBridgeProvider` alive after authentication.
- Root-call owner must call `CorrespondenceLiveService.ensureConnected()` after auth and on resume.
- Move `AuraIncomingLiveLayer` out of `MemberShell` and `InstitutionShell` into `AuraApp` root around routed content, with route gating preserved inside the layer.
- Remove shell-local duplicate `AuraIncomingLiveLayer` mounts after root mount exists to avoid double overlays.
- Keep backend event name and payload unchanged.
- Keep bridge dedup by notification id and `sessionId`.
- Add foreground FCM/Web push fallback only by injecting recognized call payloads into the same bridge/lifecycle state, not by showing a separate call UI path.

Dedup rules:

- One logical call key: `sessionId`, falling back to notification `id`.
- Socket `call:incoming`, realtime `call:incoming`, foreground FCM refresh, and poll item must converge into one bridge item.
- Duplicate direct/canonical push remains possible at transport level during backend Stage A; Flutter should dedup presentation by `sessionId`.
- Terminal events remove by `sessionId` idempotently.

Hard compatibility:

- No backend change.
- No payload shape change.
- Existing `call:incoming` remains the only socket invite event consumed.
- Overlay route suppression remains for `/realtime`, `/live/`, and `/activity` unless product changes later.

## 3. Active Call Controller Ownership

Current controller identity:

- `realtimeControllerProvider` is a non-autoDispose `StateNotifierProvider`.
- In normal `ProviderScope`, there is one `RealtimeController`, one `RealtimeSocketService`, and one `RealtimeMediaService`.
- `RealtimeRoomScreen`, `AuraIncomingLiveLayer`, Thread surfaces, PiP, and Meeting screens all read the same provider.

Risk:

- The controller is globally scoped, but call entry is not canonical. Caller start, recipient accept, Thread card join, notification tap, and route `action=join` can each decide when to call `join()`.
- `RealtimeRoomScreen.didChangeDependencies()` calls `join()` after route mount when `action=join`.
- `AuraIncomingLiveLayer._joinCurrent()` calls `join()` before navigation.
- Thread caller `_startLive()` creates the session with `joinAfterCreate=false` and relies on route action to perform join.
- A visible `Connecting...` state can persist if the visible room sees a controller state before `session:join` ack, while another path or stale runtime owns the actual session.

Stage 1 design:

- Add one canonical call-entry API on the app-level lifecycle owner, for example:
  - `startThreadCall(surfaceType, surfaceId, kind, metadata, returnTo)`
  - `acceptIncomingThreadCall(payload, returnTo)`
  - `joinThreadCallSession(sessionId, returnTo, source)`
- All Thread call entry points call this lifecycle API.
- The lifecycle API delegates to the existing `RealtimeController`; it does not replace it.
- The lifecycle owner records an active call intent keyed by `sessionId + currentUserId`, including source (`caller`, `recipient`, `route`, `notificationTap`), desired route, and phase.
- `RealtimeRoomScreen` becomes a visual consumer: if `action=join`, it asks the lifecycle owner to ensure the existing intent/session is joined rather than independently initiating a parallel join path.
- Only one join attempt per active `sessionId + currentUserId` may be in flight. Repeat route/accept/tap calls attach to the same Future/result.
- When `RealtimeController` reaches `joinState=joined` for that session, visible room and overlay state clear from the lifecycle owner.

Non-goals:

- Do not add per-session `RealtimeController` families in Stage 1.
- Do not change backend `RealtimeSessionParticipant` state.
- Do not change `REALTIME_ALLOW_MULTI_DEVICE`.
- Do not alter Meeting live room entry semantics.

## 4. Client Runtime State Model

Current relevant states:

- `RealtimeConnectionStatus`: `disconnected`, `connecting`, `connected`, `reconnecting`, `error`.
- `RealtimeJoinState`: `idle`, `joining`, `joined`, `requested`, `rejected`, `removed`, `banned`, `locked`, `failed`, `replaced`.
- `RealtimeState.isMediaReady`, `isMediaBusy`, `localRenderer`, `remoteRenderers`, `participants`, `lastSocketEvent`.

Current transition facts:

- `join()` sets `joinState=joining` and, if needed, calls `connect()`.
- `connect()` sets `connectionStatus=connecting`, then `connected` after socket connection.
- `_performJoin()` hydrates, runs REST join, connects socket, emits `session:join`, waits for ack.
- After `session:join` ack, `_performJoin()` sets `joinState=joined`, clears incoming call, starts heartbeat, then runs media readiness and RTC reconciliation.
- Media/negotiation errors are caught as non-fatal after join ack.

Stage 1 presentation/runtime phases:

- `invited`: call payload accepted into app-root lifecycle/bridge.
- `joining`: canonical lifecycle has one in-flight join for `sessionId + userId`.
- `joined`: `RealtimeController.state.sessionId == sessionId` and `joinState=joined`.
- `mediaNegotiating`: joined, local media attempt and/or offer/answer/ICE reconciliation is in progress.
- `connected`: joined plus at least one remote participant is present and either a remote renderer/track exists, or audio-only remote media evidence/peer connection health reports usable connection. For one-person waiting/ringing sessions, the correct label is waiting/ringing, not connected.
- `transportDegraded`: joined but socket is reconnecting/disconnected within grace, or peer health is reconnecting.
- `ended`: terminal event, explicit leave/end, replaced, removed, failed terminal, expired, or backend says resolved.

Advancement observations:

- `invited`: `call:incoming` or foreground push call payload accepted into bridge.
- `joining`: lifecycle invokes `RealtimeController.join(sessionId)`.
- `joined`: socket `session:join` ack applied by `RealtimeController`.
- `mediaNegotiating`: `_ensureMediaReady`, `_reconcileRtcPeers`, `session:offer`, `session:answer`, `session:ice-candidate`.
- `connected`: remote track/renderer/peer health or defined audio-only equivalent; not merely REST participant `ACTIVE`.
- `transportDegraded`: `socket:disconnected`, `socket:connect_error`, peer health `needsRestart/dead`, signaling grace.
- `ended`: `call:terminal`, `session:removed`, `realtime:removed`, `session:ended`, `session:replaced`, explicit local end/leave.

Critical UI invariant:

- The full room must not display pre-join `Connecting...` after the canonical lifecycle owner has observed `joinState=joined` for the same `sessionId + userId`.
- After `joined`, UI may show `Waiting for participant`, `Negotiating media`, or `Connection issue`, but not the pre-join `Connecting...` surface.

## 5. Caller/Callee Symmetry

Current caller path:

- Thread screen calls `ensureCorrespondenceLive(..., joinAfterCreate:false)`.
- Caller navigates to `/realtime/:sessionId?action=join`.
- Room route calls `RealtimeController.join(sessionId)`.

Current callee path:

- Overlay receives payload.
- Accept calls `RealtimeController.join(sessionId)` before navigation.
- Overlay then navigates to `/realtime/:sessionId`.

Legitimate asymmetries:

- Caller creates the session and invite; callee does not.
- Existing peer offers to the newcomer after `session:participant.joined`; newcomer answers.
- Caller may initially be alone and see ringing/waiting until recipient joins.

Asymmetries to normalize:

- Both caller and callee should enter through one lifecycle API.
- Both should share the same in-flight join dedup.
- Both should route only after the lifecycle has captured intent.
- Both should clear incoming/ring UI through the same terminal/join-success handling.
- Both should use the same definition of joined/media-negotiating/connected presentation.

## 6. Terminal Synchronization

The app-level lifecycle owner must consume terminal signals idempotently:

- `call:terminal` with `ACCEPTED`: remove incoming overlay for that `sessionId`; if this device is not the active joined owner, stop any local joining/ringing presentation. Do not end an active local room solely because another device accepted unless the local runtime is not the winner or receives `session:replaced`.
- `DECLINED`: remove incoming overlay; if current active Thread session is this call and no participant is connected, show ended/declined and leave route cleanly.
- `EXPIRED`: remove overlay and stale joining state; stale taps should land on unavailable state.
- `ENDED`: remove overlay, clear joining intent, and detach room/PiP state.
- `participant.left`: retain existing Thread behavior that non-meeting one-on-one calls end when participant count drops to one; do not alter Meeting waiting behavior.
- `continuity timeout` / `session:removed` / `realtime:removed`: clear pending and active Thread call presentation, idempotently.
- `session:replaced`: park this device in the existing `replaced` state and clear pending incoming state for that session.

Implementation detail:

- Terminal handling should live in the app-level lifecycle owner and call through existing `incomingCallBridgeProvider.removeBySession()` and `RealtimeController` state where needed.
- Repeated terminal events must be no-ops after the first state transition.

## 7. Platform Matrix

WEB:

- Foreground: app-root lifecycle consumes socket `call:incoming`; root overlay presents interruption independent of shell/route.
- Background: existing Web Push service worker remains current path. Stage 1 does not redesign it.
- Resumed: lifecycle reconciles pending incoming calls and active joined session; no backend change.
- Route change: lifecycle/overlay survives because mounted above router shell.
- Auth-shell change: authenticated root owner remains alive while token exists; clears on auth drop.

DESKTOP:

- Foreground: same app-root socket/overlay path as web; no Web Push dependency.
- Background/minimized: not solved beyond whatever foreground socket survives; native OS notification deferred.
- Resumed/window focus: lifecycle ensures correspondence socket and active realtime health check.
- Route/shell change: root overlay survives.
- Auth-shell change: same auth root behavior.

ANDROID:

- Foreground: same app-root socket/overlay path as web/desktop.
- Background/terminated: native FCM display/handler deferred.
- Resumed: lifecycle reconciles bridge state and active realtime session.
- Route/shell change: root overlay survives.
- Auth-shell change: same auth root behavior.

IOS:

- Foreground: same app-root socket/overlay path as web/desktop.
- Background/terminated: APNs/FCM registration/display deferred.
- Resumed: lifecycle reconciles bridge state and active realtime session.
- Route/shell change: root overlay survives.
- Auth-shell change: same auth root behavior.

Remaining unresolved after Stage 1:

- Activity entry doctrine for active calls.
- Multi-device first-action-wins arbitration.
- Desktop native OS notifications.
- Android/iOS background and terminated notification display.
- iOS production device registration/config evidence.

## 8. Exact Implementation Inventory

| File/provider | Current responsibility | Stage 1 responsibility | Risk | Meetings impact | Regression requirement |
| --- | --- | --- | --- | --- | --- |
| `lib/features/realtime/application/thread_call_lifecycle_controller.dart` (new) | None | App-root Thread-call lifecycle owner; boot incoming subscriptions; own call intent and phase; delegate to existing services | New orchestration must not duplicate RealtimeController | THREAD-ONLY if it gates to Thread/DM calls | Unit tests for incoming, dedup, join intent, terminal idempotency |
| `lib/app/aura_app.dart` | Auth lifecycle, device registration, root notification bridge, resume reconciliation | Boot lifecycle owner after auth; mount root incoming layer; call lifecycle resume/teardown hooks | Root rebuild/ordering | THREAD-ONLY if Meeting routes untouched | Widget/provider tests for root consumer survival |
| `lib/features/updates/incoming_call_bridge.dart` | Dedup socket/realtime incoming calls and terminal removal | Remain pending-call store; expose public ingest/terminal methods if lifecycle needs them | Changing private methods/API carelessly | THREAD-ONLY | Unit tests for socket/push duplicate sessionId dedup and terminal removal |
| `lib/features/realtime/presentation/incoming_live_overlay.dart` | Shell-mounted overlay and accept/decline actions | Presentation-only root overlay; delegate accept/decline to lifecycle owner; remove shell socket ownership duty | Overlay route gates, double mount, accept timing | THREAD-ONLY if call payload gates exclude meetings | Widget tests for route-independent single overlay and accept flow |
| `lib/app/shell/member_shell.dart` | Shell UI; currently mounts `AuraIncomingLiveLayer` | Remove shell-local incoming overlay after root mount; keep meeting return/live banners | Double overlay if not removed | ActiveMeetingReturnLayer must remain unchanged | Shell tests/smoke for no duplicate overlay and nav unchanged |
| `lib/app/app_shell.dart` | Shell selection | No direct change expected; may only be test fixture context | Low | None | Existing shell behavior preserved |
| `lib/core/notifications/notification_bridge.dart` | FCM/Web notification foreground/tap handling; refreshes notifications on foreground call | For foreground call payloads, feed lifecycle/bridge directly or refresh plus lifecycle reconciliation; no separate call UI | Duplicates with socket/poll | THREAD-ONLY for call payload branch; meeting notification semantics unchanged | Foreground FCM call dedup; non-call snackbar unchanged |
| `lib/features/realtime/application/realtime_providers.dart` | Provides global realtime services/controller | Usually unchanged; may export new lifecycle provider | Provider dependency loops | SHARED if RealtimeController provider changed; avoid | Provider construction tests |
| `lib/features/realtime/application/realtime_controller.dart` | Single realtime socket/media/session controller | Add minimal presentation/runtime phase evidence only if required; expose stable observations rather than new backend states | HIGH: shared with Meetings | SHARED WITH MEETINGS | Meeting join/reconnect/audio/video regression if touched |
| `lib/features/realtime/domain/realtime_state.dart` | Transport/join/media state | Add client-only call phase fields only if needed and backward-safe | MEDIUM: shared state consumed by Meetings | SHARED WITH MEETINGS | Meeting UI snapshots plus Thread room tests |
| `lib/features/realtime/domain/realtime_enums.dart` | Transport/join enums | Add client-only `ThreadCallPhase` only if kept Thread-specific outside shared `RealtimeState` | MEDIUM if added to shared model | Prefer THREAD-ONLY lifecycle enum | Unit tests for phase projection |
| `lib/features/realtime/presentation/realtime_room_screen.dart` | Thread/non-meeting realtime room UI; route action invokes join | Use lifecycle owner for Thread route `action=join`; render from canonical joined/media phase; do not show pre-join Connecting after joined | HIGH: route and UI state | Shared only if meeting kill-switch/meeting routing changed; avoid | Thread caller/callee transition tests; stale route recreation test |
| `lib/features/correspondence/presentation/thread_screen.dart` | Starts Thread calls and navigates to realtime route | Use lifecycle owner `startThreadCall()` instead of ad hoc create+navigate | MEDIUM | THREAD-ONLY | Caller path test |
| `lib/features/correspondence/presentation/thread_state_wrapper.dart` | Thread socket room binding and thread refresh | No expected Stage 1 change unless route join query handling conflicts | MEDIUM if touched | THREAD-ONLY | Thread refresh/socket binding test |
| `lib/core/notifications/notification_open_reconcile.dart` | Invalidates providers on notification taps | May coordinate realtime call tap into lifecycle owner; background tap behavior remains deferred | MEDIUM | THREAD-ONLY for call branch | Existing notification tap tests plus call route test |
| `test/thread_call_lifecycle_controller_test.dart` (new) | None | Pure provider/controller tests for lifecycle | Low | None | Required |
| `test/incoming_call_overlay_lifecycle_test.dart` (new) | None | Widget tests for root overlay consumption/dedup/route independence | Medium | None | Required |
| `test/realtime_thread_call_lifecycle_test.dart` (new or repaired) | Existing realtime golden is skipped/rotted | State transition tests for caller/callee join and connected presentation | Medium | Possible shared fixtures | Required |
| `test/meeting_entry_resolution_test.dart` | Meeting resolver tests | Keep passing; add no Thread behavior here | Low | MEETING | Existing test must pass |
| `test/meeting_live_room_lifecycle_test.dart` (new or existing fixture) | None | Minimal Meeting join/reconnect preservation if shared realtime code is touched | Medium | MEETING | Required if shared realtime files change |

Files intentionally untouched in Stage 1:

- Backend repositories, schema, migrations, `CorrespondenceOrchestratorService`, `MessagesGateway`, `RealtimeGateway`, `RealtimeSessionService`.
- Meetings product code unless shared realtime changes force a regression-only fixture.
- Activity feed implementation.
- Android/iOS platform notification handlers for background/terminated delivery.
- Desktop native notification implementation.

## 9. Meetings Preservation Gate

Thread-only preferred changes:

- New Thread lifecycle controller/provider.
- Root mounting of Thread incoming overlay.
- Thread accept/start/join delegation to lifecycle owner.
- Incoming call bridge public ingestion/dedup methods.

Shared with Meetings, avoid unless necessary:

- `RealtimeController`.
- `RealtimeState`.
- `RealtimeSocketService`.
- `RealtimeMediaService`.
- `RealtimeRoomScreen` only insofar as it may share non-meeting realtime UI.

Meetings behavior that must remain unchanged:

- `/meetings/:id/live` stays on `MeetingLiveRoomScreen`.
- `/realtime/:sessionId` meeting kill switch continues to divert Meeting sessions.
- Guest auth exchange and guest socket `session:join` remain unchanged.
- Waiting room/admission states remain resolver-driven.
- Host controls, recording, conversation panel, materials, screen share, and active meeting return layer remain unchanged.
- Meeting reconnect grace, heartbeat, stale sweep, and leave/end behavior remain unchanged.

Hard stop:

- If Stage 1 implementation requires changing Meeting route behavior, Meeting admission, Meeting guest handling, or backend realtime semantics, stop and request founder approval.

## 10. Release Impact

Stage 1 is shared Flutter work.

| Platform | Impact | Reason |
| --- | --- | --- |
| Web | Web deploy required | Root lifecycle/overlay and Thread call state changes ship in Flutter web bundle |
| Desktop | Desktop build/deploy required | Native desktop foreground consumption needs new Flutter binary/app package |
| Android | Android release required | Installed Android clients cannot receive app-root lifecycle fix without new binary |
| iOS | iOS release required | Installed iOS clients cannot receive app-root lifecycle fix without new binary |

One shared Flutter implementation should serve all four builds for foreground lifecycle correctness. Background/native notification fixes are explicitly outside Stage 1.

## 11. Regression Plan

Focused Stage 1 tests:

- App-root `call:incoming` consumption after auth.
- Foreground web interruption through root lifecycle.
- Foreground desktop-equivalent interruption through platform-agnostic widget/provider test.
- Foreground Android-equivalent interruption through platform-agnostic widget/provider test.
- Foreground iOS-equivalent interruption through platform-agnostic widget/provider test.
- Route-independent overlay across `/home`, Thread route, detail route, and shell transition.
- One logical overlay per call when socket and push/poll deliver the same `sessionId`.
- Caller start path records one active call intent and routes through lifecycle.
- Callee accept path records one active call intent and joins through same lifecycle.
- Caller transitions out of pre-join `Connecting...` when `joinState=joined` for the active session.
- Recipient accept triggers caller-side participant event/offer path in controller tests or harness.
- Terminal events clear pending overlay and active joining state idempotently.
- Provider/navigation recreation does not orphan active Thread call state.
- Thread audio call entry and state transitions.
- Thread video call entry and state transitions.

Meetings regression:

- Meeting join route still uses `MeetingLiveRoomScreen`.
- Waiting room/admission resolution remains unchanged.
- Guest join still works without member REST join dependence.
- Normal Meeting audio/video smoke path remains unchanged.
- Reconnect behavior remains unchanged.
- Leave/end remains unchanged.

Existing test debt:

- `realtime_room_golden_test.dart` is currently skipped due stale fixtures. Stage 1 should add focused non-golden lifecycle tests rather than trying to make visual goldens carry runtime correctness.

## 12. Implementation Sequence

Phase A - App-root incoming-call ownership.

- Add Thread lifecycle owner/provider.
- Boot it from `AuraApp` after auth.
- Mount `AuraIncomingLiveLayer` at root and remove shell-local mounts.
- Add bridge/lifecycle dedup tests.
- Locally test: one incoming `call:incoming` -> one overlay across routes.

Phase B - Canonical active-call intent/controller ownership.

- Add lifecycle APIs for start, accept, and route join.
- Move Thread screen start and overlay accept to lifecycle API.
- Make route `action=join` ask lifecycle to ensure join for the active session.
- Add in-flight join dedup keyed by `sessionId + currentUserId`.
- Locally test: caller and callee paths use the same controller and one join attempt.

Phase C - Caller/callee state synchronization.

- Add client-only phase projection.
- Update Thread realtime room presentation so pre-join `Connecting...` only represents not-yet-joined, and joined/media-negotiating/connected/degraded have distinct presentation.
- Ensure terminal events clear pending and active states idempotently.
- Add tests for participant joined -> offer path and terminal cleanup.

Phase D - Regression certification.

- Run focused Thread lifecycle tests.
- Run notification bridge/open reconcile tests.
- Run realtime controller/provider tests.
- Run meeting entry/live-room preservation tests.
- Run `flutter analyze`.
- Run full Flutter test suite from a healthy runner.
- Build web if founder authorizes implementation certification.

## 13. Founder Gates Still Required Before Commit

1. Review the local Stage 1 implementation and Gate 2 report.
2. Authorize commit if the Stage 1 scope, Meetings boundary, and verification record are acceptable.

Resolved by implementation authorization:

- Stage 1 coding was authorized.
- Root owner placement is `AuraApp` through `ThreadCallLifecycleHost`.
- A small client-only Thread call lifecycle model/provider is approved and implemented.
- Shared realtime files were not touched, so no additional founder approval for shared realtime changes was required.
- Release impact remains web deploy, desktop build/deploy, Android release, and iOS release.
