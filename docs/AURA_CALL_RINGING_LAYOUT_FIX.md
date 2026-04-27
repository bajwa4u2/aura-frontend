# Aura Call Ringing & Active Call Layout Fix

## Summary

Improves the call experience to behave more like a real-time communication product. Addresses two critical categories: (A) incoming call overlay wiring and suppression logic, and (B) active call stage layout in thread screens.

---

## Priority A — Incoming Call / Ringing Behavior

### Problem

`AuraIncomingLiveLayer._isInterruptCandidate()` suppressed the full-screen overlay for **any route containing `/thread/`**. This meant:
- You were in Thread A. Thread B's call started. The overlay was silently suppressed.
- Any ongoing thread navigation completely blocked the incoming call UI.

### Fix — `incoming_live_overlay.dart`

**Old logic:**
```dart
if (currentPath.contains('/thread/') ||
    currentPath.contains('/realtime') ||
    currentPath.contains('/live') ||
    currentPath.contains('/activity')) {
  return false;
}
```

**New logic:**
```dart
// Hard suppress: already in a dedicated call room or live sub-route.
if (currentPath.contains('/realtime') ||
    currentPath.contains('/live/') ||
    currentPath.contains('/activity')) {
  return false;
}

// Thread routes: only suppress if already joined into this exact session.
// A call from a different thread must still show the overlay.
if (currentPath.contains('/thread/')) {
  final alreadyInThisSession = sessionId.isNotEmpty &&
      liveState.isJoined &&
      liveState.sessionId == sessionId;
  if (alreadyInThisSession) return false;
}
```

`_currentIncoming()` and `build()` now receive and forward `RealtimeState` so the session-match check can be made. `realtime_state.dart` import added.

### Notification click behavior

Existing `_joinCurrent()` logic is preserved:
- Extracts `sessionId` from notification payload
- Calls `controller.join(sessionId)` 
- Marks notification read
- Routes via `CommunicationResolver` to the correct thread or realtime room

Missed/ended calls (no `attention: INTERRUPT`, or `readAt` set) are skipped by the overlay and shown as snackbars by `NotificationBridge` — intentional behavior preserved.

---

## Priority B — Active Call Layout

### Problem

`_ThreadLiveDock` was embedded **inside** `_ThreadModeHeaderCard`'s `AuraCard` padding. The video stage (`_ThreadVideoStage`) used `GridView.count` with `shrinkWrap: true` and `childAspectRatio: 1.08`, causing:
- On mobile (375px): 2-tile grid produced ~694px of vertical content — taller than the viewport
- On desktop: equal-sized tiles for caller and local video; no dominant primary view
- Controls were tiny 34×34 strip icons, difficult to tap on mobile
- No visual distinction between caller/self video

### Fix — `thread_screen.dart`

#### 1. Live dock promoted out of header card

`_ThreadLiveDock` is no longer a child of `_ThreadModeHeaderCard`. It is rendered as a sibling widget in the parent `Column`, after the header card. The four live callbacks (`onJoinLive`, `onLeaveLive`, `onToggleMicrophone`, `onToggleCamera`) are removed from `_ThreadModeHeaderCard`'s constructor.

This means the live stage is no longer visually constrained inside a card's padding, and does not force the header card to grow vertically during calls.

#### 2. New `_ThreadVideoStage` — PiP layout

Old grid replaced with a `LayoutBuilder`-constrained `Stack`:

| Breakpoint | Stage height |
|---|---|
| < 600px (mobile) | 260px |
| 600–960px (tablet) | 320px |
| ≥ 960px (desktop) | 380px |

Layout inside the stage:
- **Remote (primary)**: `Positioned.fill` — occupies the full stage. Dark background placeholder (`_CallStatePlaceholder`) if no stream yet.
- **Remote label**: top-left badge showing "Host" or "Member".
- **Extra remote thumbnails** (3+ participants): top-right row of 72×54 clips (`_ExtraParticipantsPip`).
- **Local PiP** (`_LocalPip`): bottom-right corner, 96×72, rounded, mirrored.
- **Floating controls** (`_FloatingCallControls`): bottom-centre pill with mic, camera, end buttons (40×40 circles).

#### 3. `_FloatingCallControls` + `_ControlButton`

Dedicated floating control bar replaces the strip icon buttons for video mode. Buttons are 40×40 circle targets with clear visual state (active/muted/danger). Rendered over the video via `Positioned`.

#### 4. Call state labels in `_ThreadStatusStrip`

Two new required params: `connectionStatus: RealtimeConnectionStatus` and `joinState: RealtimeJoinState`.

State-aware label overrides the caller name when a non-idle/non-joined state is active:

| State | Label shown |
|---|---|
| `joinState == joining` | "Connecting..." |
| `connectionStatus == reconnecting` | "Reconnecting..." |
| `joinState == requested` | "Waiting for approval..." |
| `joinState == rejected` | "Call declined" |
| `joinState == removed` | "You were removed" |
| `joinState == failed` | "Call failed" |
| `connectionStatus == error` | "Connection error" |
| `joinState == locked` | "Room is locked" |
| `joinState == banned` | "Banned from session" |

The live status dot colour adapts: green (joined), accent (connecting/reconnecting), red (error/removed/failed), muted (idle).

The Join button is hidden in transient states (joining, requested, rejected, removed, failed, banned) to prevent double-taps.

---

## Priority C — Call States Coverage

| State | Where shown |
|---|---|
| Ringing | `_ThreadStatusStrip` "...is calling" label + join button |
| Connecting | `_ThreadStatusStrip` "Connecting..." (joinState = joining) |
| Joined | Green dot, caller label, mic/camera/leave controls visible |
| Reconnecting | `_ThreadStatusStrip` "Reconnecting..." (connectionStatus = reconnecting) |
| Missed | `NotificationBridge` snackbar (not an INTERRUPT) |
| Ended | Session removed from thread state; dock hides when `hasLive = false` |
| Declined | "Call declined" (joinState = rejected) |
| Permission blocked | `BrowserNotificationsSection` "Blocked" state (web push) |

---

## Priority D — Preserved Behavior

All existing call functionality preserved unchanged:
- Start audio call / start video call from thread header
- Join existing session
- Leave / end call
- Mute mic toggle
- Camera toggle
- Thread messaging while in call
- Push notification deep links (session routing via `CommunicationResolver`)
- Realtime WebSocket signaling, offer/answer/ICE flow
- Waiting room, consent, recording, transcript controls

---

## Priority E — Responsive Breakpoints

| Width | Video stage | Thread layout |
|---|---|---|
| 320–599px | 260px PiP stage | Single column, no side rail |
| 600–767px | 320px PiP stage | Single column + side rail below |
| 768–959px | 320px PiP stage | Two-column (expanded + 300px rail) |
| 960px+ | 380px PiP stage | Two-column (expanded + 300px rail) |

---

## Known Backend Gaps

1. **Session ID on thread data**: The dock appears when `liveSessionId`, `activeSessionId`, or nested `live.sessionId` fields are present on the thread API response. If the backend does not populate these fields synchronously when a call starts, the dock relies on `liveState.session` surface-type matching as a fallback. The 20-second poll timer refreshes thread data when not in an active call.

2. **Call expiry / missed call**: The backend marks a notification `readAt` when the call expires or is answered elsewhere. The overlay disappears automatically because `_isInterruptCandidate` rejects `readAt`-set items. There is no client-side ring timeout; the backend drives this.

3. **FCM/APNS for mobile**: Real push notifications on Android/iOS require Firebase integration (not yet configured). Calls are delivered via in-app notification polling only.

---

## Validation

```
flutter analyze  → No issues found!
flutter test     → All tests passed!
flutter build web → ✓ Built build/web
```

## Files Changed

| File | Change |
|---|---|
| `lib/features/realtime/presentation/incoming_live_overlay.dart` | Smart route suppression; thread-route overlay now shows for unrelated calls |
| `lib/features/correspondence/presentation/thread_screen.dart` | Live dock promoted outside header card; PiP video stage; call state labels; new helper widgets |
