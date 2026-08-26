# Aura A/V — certification record

**Date:** 2026-08-25. **Chapter:** Audio / Video Call System reconstruction.

Everything below is either measured or explicitly marked as not executed.
Nothing is inferred from another platform.

---

## Measured baseline (before reconstruction)

| Measure | Before |
|---|---|
| Client Dart files | 620 |
| Client realtime files | 35 |
| Backend TypeScript files | 940 |
| Backend realtime files | 82 |
| `getUserMedia` call sites / files | 11 / 3 |
| Consumers of the canonical `classifyMediaError` (lib) | **2** (both Meetings) |
| Hardcoded browser-flavoured media strings | **4** |
| `permission_handler` dependency | **absent** |
| Android `BLUETOOTH_CONNECT` | **absent** |
| Android `FOREGROUND_SERVICE*` | **absent** |
| iOS `UIBackgroundModes: audio` / `voip` | **absent** |
| Native permission *status* query anywhere | **none possible** |
| Preflight before a thread call | **none** |

## TURN / STUN — measured live, not recalled

| Path | Result |
|---|---|
| DNS `turn.auraplatform.org` | 64.23.212.145 |
| TCP 3478 | **open** |
| TCP 5349 | **open** |
| TCP 443 | **closed** |
| TLS on 5349 | **valid** — `CN=turn.auraplatform.org`, Let's Encrypt, `Verify return code: 0 (ok)`, TLSv1.2 |

Prior records claimed TURNS was completed on 2026-08-02. That claim
**re-verified as true**. The 443 gap is new information and is reported rather
than assumed away.

## Findings resolved

| # | Severity | Finding |
|---|---|---|
| AV-1 | **P0** | No explicit native camera/microphone permission request flow. `getUserMedia` triggered the OS prompt mid-join with no explanation; nothing could query status, detect a permanent denial, or open settings. |
| AV-2 | **P0** | Pressing **Call** created the session and rang the other person *before* the caller knew they had a working microphone. |
| AV-3 | **P1** | The media engine bypassed the canonical classifier and hardcoded copy telling Windows, Android and iOS users to check "this browser". |
| AV-4 | **P1** | The permission model lacked `permanentlyDenied` and `unknown`, so a permanent refusal offered a recovery that could not work and a failed check was reported as a refusal. |
| AV-5 | **P1** | In-call camera control read "Camera" when on — named the thing, not the state or effect, while the microphone beside it named the action. |
| AV-6 | **P1** | Call dock controls carried **no** `Semantics` at all: state was conveyed by icon and colour only. |
| AV-7 | **P1** | Android could not route call audio to a Bluetooth headset (`BLUETOOTH_CONNECT` absent) and had no foreground-service declaration, so a backgrounded call could be killed. |
| AV-8 | **P1** | iOS had no `audio` background mode: a call would go silent on leaving the foreground. |

## Certification matrix

Executed 2026-08-25 via `integration_test/av_certification_test.dart`
(session-independent: it certifies the client, not an account).

| Capability | Web | Android (physical) | Windows native | iOS |
|---|---|---|---|---|
| Permission model / classification | PASS¹ | NOT_EXECUTED² | **PASS** (8/8) | NOT_EXECUTED |
| Platform reports its own queryability honestly | PASS¹ | NOT_EXECUTED² | **PASS** | NOT_EXECUTED |
| Recovery copy names no browser off the web | PASS¹ | NOT_EXECUTED² | **PASS** | NOT_EXECUTED |
| Permanent denial distinguishable + actionable | PASS¹ | NOT_EXECUTED² | **PASS** | NOT_EXECUTED |
| Control labels + announcements | PASS¹ | NOT_EXECUTED² | **PASS** | NOT_EXECUTED |
| Preflight opens, checks, releases on dismiss | NOT_EXECUTED³ | NOT_EXECUTED² | **PASS** (real hardware) | NOT_EXECUTED |
| Preview stream released (no orphaned capture) | NOT_EXECUTED³ | NOT_EXECUTED² | **PASS** | NOT_EXECUTED |
| Joining never barred by a refusal | PASS¹ | NOT_EXECUTED² | **PASS** | NOT_EXECUTED |
| Build integrity with new manifest + plugin | — | **PASS** (APK built) | **PASS** | NOT_EXECUTED |
| Meetings integration unregressed | PASS¹ | NOT_EXECUTED² | PASS¹ | NOT_EXECUTED |
| Audio call end-to-end | NOT_EXECUTED⁴ | NOT_EXECUTED⁴ | NOT_EXECUTED⁴ | NOT_EXECUTED |
| Video call end-to-end | NOT_EXECUTED⁴ | NOT_EXECUTED⁴ | NOT_EXECUTED⁴ | NOT_EXECUTED |
| Incoming call delivery | NOT_EXECUTED⁴ | NOT_EXECUTED⁴ | NOT_EXECUTED⁴ | NOT_EXECUTED |
| Reconnect under real loss | NOT_EXECUTED⁴ | NOT_EXECUTED⁴ | NOT_EXECUTED⁴ | NOT_EXECUTED |
| TURN relay reachability (UDP/TCP 3478) | **PASS** | — | — | — |
| TURNS TLS 5349 (listener + certificate) | **PASS** | — | — | — |
| TURNS TLS 443 | **BLOCKED_EXTERNAL** | — | — | — |
| Relay-path ICE certification | NOT_EXECUTED⁴ | NOT_EXECUTED⁴ | NOT_EXECUTED⁴ | NOT_EXECUTED |

¹ Covered by the widget suite (1523 green) on the shared, platform-independent
logic. Not a substitute for device execution and not presented as one.

² **The Pixel 9a disconnected between the Meetings chapter and this one.**
`flutter devices` lists only Windows, Chrome and Edge. The Android A/V run was
attempted and failed to find the device. The earlier Meetings Android result is
**not** carried over — it certified a different chapter's code. No PIN was
attempted. `ANDROID_PHYSICAL_CERTIFICATION = NOT_EXECUTED_DEVICE_DISCONNECTED`.

³ The preflight is a Flutter widget; its real-hardware behaviour was certified
natively on Windows. A browser run was not executed.

⁴ **A real two-party call was not executed.** It requires a second
authenticated account or a second device signed in as a different person; only
the founder's account is available here. Reported rather than simulated.

## What is explicitly NOT claimed

* No iOS execution of any kind.
* No two-party audio or video call.
* No relay-path ICE certification (needs a real call).
* No reconnect-under-loss certification (needs a real call).

---

# Android physical certification — executed 2026-08-25

Device: **Pixel 9a**, `53061JEBF08485`, Android 17 (API 37).
Harness: `integration_test/av_android_certification_test.dart` — **18/18 PASS**
on the final current A/V code. Baseline harness
`av_certification_test.dart` — **8/8 PASS** on the same device.

The previous `NOT_EXECUTED` classification is retired. No Meetings-chapter
Android evidence was reused; that certified different code.

## A defect the handset found and Windows could not

**`CallReadiness` notified after disposal.** `check()` is asynchronous, and on
Android it is genuinely slow — a permission request plus a real device open.
Dismissing the preflight while it runs disposed the notifier, and the
continuation then called `notifyListeners()` on a dead `ChangeNotifier`:

```
A CallReadiness was used after being disposed.
#3  CallReadiness.check (package:aura/core/media/call_readiness.dart:146:7)
```

Windows never exposed it: its check returns almost instantly, so there is no
window to be dismissed inside. The fix guards notification, and releases
anything the in-flight check opened, so a preflight abandoned mid-check cannot
leave the camera running. Pinned by *"disposing DURING a check does not explode
or leak"*.

## Measured permission evidence

| Observation | Value |
|---|---|
| `hasQueryablePermissions` on Android | **true** (false on Windows, by design) |
| Status query without a system dialog | **works** — never returned `unknown` |
| Fresh-install state, read live | `mic=denied camera=denied` — the real denied path |
| OS grant via `adb pm grant` | `CAMERA`, `RECORD_AUDIO`, **`BLUETOOTH_CONNECT`** all `granted=true` |
| After that grant, read live | `mic=granted camera=granted` |

**Two OS states were driven from outside the app and Aura reported each one
correctly** — denied on a fresh install, granted after `adb shell pm grant`,
with the second run asserting it via `--dart-define=EXPECT_CAMERA=granted`.
That is the agreement between Aura and the platform, measured rather than
assumed, and it is the capability that did not exist at all before this
chapter.

`BLUETOOTH_CONNECT` being grantable confirms the new manifest entry is real on
this device — the permission that call audio needs to reach a paired headset on
Android 12+, and which was absent before this chapter.

## The ordering invariant

    CALL INTENT → PREFLIGHT → READINESS → USER PROCEEDS
      → SESSION CREATED → OTHER PARTY RUNG

Proved in two halves, and the structural half was **negative-controlled**: the
pre-chapter defect was reintroduced (hoisting `startLive` above the preflight)
and the test failed with *"a session is created, and the recipient rung, before
the caller has proceeded through readiness"*; restoring the source made it pass
again. A test that cannot fail is not evidence.

* Structural — `test/realtime/call_preflight_ordering_test.dart`, 6/6:
  `startLive` and `context.push` are both unreachable before the
  `if (proceed != true) return;` guard.
* Behavioural, on the handset — dismissal yields `false`, and **system Back**
  also yields a non-proceed answer, so neither route can be read as consent.

## Android capabilities certified on device

| Item | Result |
|---|---|
| Preflight opens, names the person, offers a way out | PASS |
| Touch targets on a real phone viewport | PASS |
| Device state announced (not colour/icon alone) | PASS |
| Composition without overflow on this screen | PASS |
| Foreground → background → foreground | PASS |
| Re-entry re-answers readiness rather than trusting stale state | PASS |
| Dispose during in-flight check | PASS (after fix) |
| Preview release idempotent, nothing left open | PASS |
| System Back closes without starting a call | PASS |
| Android recovery language names Settings › Apps, never a browser | PASS |
| Degraded participation: refusal never bars joining | PASS |
| Audio call never reports the camera as refused | PASS |

---

# Real two-party certification — Pixel ↔ browser, 2026-08-25

**Identities:** browser = **M S Bajwa** (Founder & Steward); Pixel 9a =
**Muhammad Zakria**. Two genuine authenticated accounts; nothing mocked.
**Build:** APK from the current A/V code, installed fresh, permissions granted.

## What the first real call established

| Observation | Evidence |
|---|---|
| Two-party **audio** call connects | session `cmt9ct2xk00ikli0ch7i8s6go`, timer running, 2 participants |
| Two-party **video** call connects | session `cmt9ctuj400l9li0c92k7qci2`, browser showed local + remote video |
| Governed identity in-call | tiles read "You" and "Muhammad Zakria" — never "User"/"Someone" |
| Reconstructed control vocabulary, on device | the Pixel dock read **"Mute"** and **"Turn off"**, not the old bare "Camera" |
| Preflight live in production | "Video call Muhammad Zakria" / "They will be able to see and hear you" / "Microphone ready" / "Camera ready" |
| **TURN relay carrying a real call** | on the Pixel: `tcp ESTAB 10.0.0.44:46105 → 64.23.212.145:3478` |

`ICE_SELECTED_PATH = RELAY (TCP 3478)`. No UDP association to the TURN host was
present, so this call relayed over TCP. Both endpoints were on the same LAN,
which makes the relay selection notable in itself and worth watching for media
quality.

## Four defects found by the real call, all fixed

| # | Defect | Fix |
|---|---|---|
| AV-9 **P0** | **The callee received no remote video.** The answerer attaches local tracks after `setRemoteDescription`, once, guarded by `isNewPeer`. If the offer arrived while `getUserMedia` was still resolving, `_localStream` was null, nothing was attached, and `createAnswer` produced **recvonly**. Permanently dark to the far side; unrecoverable because `setCameraEnabled` only flips `enabled` on existing tracks. | The answerer waits on the in-flight acquisition before concluding it has nothing to send. Negative-controlled test. |
| AV-10 | **Transient PiP on the receiving end.** The 2026-08-22 repair fixed *which signal* is used (route, not `initState`) but not the ORDERING: joining happens before navigation begins, so the PiP rendered in the gap. | A PiP may not precede the room it represents — it stays silent until that session's room has been on screen once. |
| AV-11 **P0** | **The preflight was unreachable on a short viewport.** From a 1512×812 browser window the preview pushed "Start video call" and "Not now" off-screen with no way to scroll. The call could not be started and the sheet could not be dismissed. It fitted on the Pixel, which is why the Android pass missed it. | Sheet bounded to 85% of viewport, content scrolls, actions pinned OUTSIDE the scrollable. |
| AV-12 | The preview cap did not apply — `ConstrainedBox` around `AspectRatio` loses to the stretch cross-axis. | Fixed height, crop to fill. |

**AV-9 has history.** Repairs `381c452` and `9815742` were both reverted
(`a77b62e`, `4420602`), and `a77b62e` also deleted the 237-line regression test.
`main` then carried neither repair nor test and the defect stayed live. This
time the fix ships with a negative-controlled test, so a future revert has to
delete the evidence deliberately.

---

# Two founder findings, 2026-08-25 (post two-party certification)

Both were found by USING the product, not by reading it. Neither is a polish
item: each is a case of a capability being expressed through the wrong
mechanism, so the symptom could not have been fixed where it appeared.

## AV-13 — an incoming call was presented as a notification

> "ring is there with notification not as incoming call, if notification
> disappear no ring, after tapping notification goes to accept/decline overlay
> and ring dropped" — founder, Pixel 9a
>
> "ring tied with notification, notification missed or tapped its gone and call
> burried"
>
> "notification naturally a short tenure so if miss tap call burried
> immediately"

### What was actually there — measured, not inferred

There was **no incoming-call surface on Android at all**. What existed was an
ordinary FCM `notification` message, drawn by the Firebase SDK itself, on a
channel (`aura_calls`) whose CHANNEL SOUND happened to be the system ringtone:

* `fcm-push.adapter.ts` set `message.notification` for `CALL_RINGING`;
* nothing in the app subclassed `FirebaseMessagingService`, and nothing used
  `flutter_local_notifications` — confirmed by reading every Kotlin source in
  the app (`AuraApplication.kt`, `MainActivity.kt` — 140 lines between them);
* so **the ring was a property of the notification**.

Every symptom the founder listed follows from that single fact, and the
founder's own summary — *a notification has a short tenure, and the call
inherited it* — is the correct diagnosis:

| Symptom | Cause |
|---|---|
| Notification dismissed → no ring | The sound belonged to the notification |
| Tap → ring dropped | The SDK auto-cancels on tap, **and** `notification_bridge.dart:191` explicitly cancelled it too |
| Call buried after a missed tap | A notification self-dismisses; a call does not |
| Never presents as a call | An SDK-drawn notification cannot carry a full-screen intent |

A codebase comment had also drifted from the code: the adapter described "the
FCM service handler on the device" dismissing prior notifications. No such
handler existed.

### The repair — the ring's lifetime is now the CALL's ring window

| Layer | Change |
|---|---|
| `fcm-push.adapter.ts` | Android `CALL_RINGING` is sent **data-only**. Not cosmetic: while a `notification` block is present the SDK draws its own banner, so the app could not own presentation without ringing the same call twice. Scoped to Android — iOS has no equivalent hook and keeps its APNs alert. |
| `AuraCallPushReceiver.kt` | A `BroadcastReceiver` on `com.google.android.c2dm.intent.RECEIVE`, **alongside** the `firebase_messaging` plugin's own receiver. |
| `IncomingCallPresenter.kt` | Builds the call: `CallStyle.forIncomingCall` (API 31+), full-screen intent, `ongoing`, `FLAG_NO_CLEAR`, and `FLAG_INSISTENT` — the flag that makes a ring a ring rather than one chime. `setTimeoutAfter` is bounded by the invite's own `expiresAt`. |
| `MainActivity.kt` | Takes over from the ring, shows over the lock screen for call intents only, and carries the act to Dart (warm via `onCallAction`, cold via a drained pending slot). |
| `notification_bridge.dart` | **Stopped cancelling the ring on tap.** A tap is not an answer. |
| `incoming_live_overlay.dart` | Executes an explicit Answer/Decline from the notification through the accept/decline paths it already owns — one implementation, not a shadow pair. |

**Why not a `FirebaseMessagingService`.** FCM binds exactly one service for
`com.google.firebase.MESSAGING_EVENT`, and the Flutter plugin already holds it.
Subclassing would have silently killed every Dart-side handler —
`onMessage`, the background handler, token refresh. The plugin also registers a
plain `BroadcastReceiver`, and a broadcast reaches every registered receiver, so
call presentation was added *next to* Dart's message handling rather than in
front of it.

### The ring now ends for these reasons, and no others

    answered · declined · cancelled by the caller · another device answered
    · the invite's ring window expired

Not: notification swiped, notification tapped, notification aged out.

### Not claimed

* `USE_FULL_SCREEN_INTENT` is declared, but Android 14+ does not grant it to
  every app that asks. `MainActivity.canUseFullScreenIntent()` reports the real
  state instead of assuming it. Where it is not granted the call degrades to a
  heads-up notification — **and the ring is unaffected**, because the ring is
  no longer a property of how the call is drawn.
* Declining from the notification opens the app to perform the authoritative
  decline. A decline that never foregrounds the app would need network and auth
  from Kotlin; it is named here rather than faked.
* iOS is untouched and remains `IOS_CERTIFICATION = NOT_EXECUTED`.

## AV-14 — Live was offered inside an audio call

> "call was audio, i went live in it, then tried to watch as other user — it was
> giving error. audio should not go live / live enabled for audio. it should be
> deterministic for video." — founder

`_liveControlsEligible` gated Go Live on surface, join state and role. It never
asked whether the call carried video. An audio call could therefore be escalated
to a public broadcast that had nothing for an audience to receive — which is
what the watcher's error was.

The gate now asks the one question that decides whether there is anything to
watch: **is any stage participant actually publishing video or a screen.** It is
derived from published media state — the same values every client in the session
receives — so two people in one call cannot get different answers, which is the
determinism the founder asked for. Observers are excluded; a viewer's absent
camera cannot be the reason a call qualifies as watchable.

**Ending a Live is deliberately NOT gated.** A broadcaster whose camera closed
mid-broadcast must still be able to close the public door.

This changes the ORIGINATION door only. Live Broadcast itself remains out of
scope and untouched, per the standing ruling; `GO_LIVE_CONTROL` behaviour inside
the Live chapter is unchanged.

## AV-15 — answering is instant; connecting is not (measured 2026-08-25)

> "there is bit delay too before connecting too, did you noticed?" — founder

Yes, and it is **6.51 s** from the Answer tap to media connected, measured on the
Pixel 9a from one real answered call (session `cmt9kjdkv007cob0c7o71wlzz`).
About **3.8 s of that is the client's own sequencing**, not network physics.

| Phase | Time |
|---|---|
| Answer tap → Dart receives the act | **1 ms** |
| Session bundle hydrate | **2.62 s** |
| REST join | 0.39 s |
| Gap before the socket is created | **1.15 s** |
| Socket connect | 0.08 s |
| Join ack | 0.20 s |
| `getUserMedia` | 0.32 s |
| Peer created + remote track attached | 0.41 s |
| ICE checking → connected | **1.23 s** |

### The 2.62 s: a serial errand list before the call may begin

`RealtimeRepository._fetchSessionBundle` issues **six HTTP requests, each
awaited before the next**:

```
/realtime/sessions/{id}
/realtime/sessions/{id}/policy
/realtime/sessions/{id}/consent
/realtime/sessions/{id}/recordings     <- the call's RECORD
/realtime/sessions/{id}/transcripts    <- the call's RECORD
/realtime/sessions/{id}/artifacts      <- the call's RECORD
```

Nothing here is individually slow — the same six, unauthenticated from a
desktop, measured 106/85/159/132/84/81 ms, 647 ms sequential. They are simply
serialized, and **three of them are the aftermath of a call, fetched before the
call is allowed to start.** Recordings, transcripts and artifacts belong to the
Meeting Record; answering does not depend on any of them.

Two structural observations, both inside Call Presentation Authority's
"engine state → product adapter" boundary rather than in the media engine:

* the six are independent and could resolve concurrently;
* the join path should require only what joining needs — session, policy,
  consent — and let the record load after the person is in the call.

### The other two costs

* **1.15 s dead gap** between the REST join returning and the socket being
  created. The connect itself takes 81 ms, so this is scheduling, not transport.
* **1.23 s ICE.** Real network work, and worth reading alongside the earlier
  finding that this pair relays over TURN TCP *even on the same LAN*.

### A defect this trace found in the new code

The answer was delivered to Dart **twice** — warm via `onCallAction` at t+1 ms,
then again from the native pending slot at t+225 ms. The overlay's once-only
guard absorbed it and the second `join()` early-returned "already joined this
session", so no harm reached the call. A duplicate delivery that is only
harmless because something downstream catches it is still a duplicate: the warm
path now retires the pending slot on arrival, leaving it as what it was meant to
be — a cold-start fallback.

### The 1.15 s gap was the SAME bundle, fetched a second time

The dead gap between the REST join returning and the socket being created is
not scheduling after all. `RealtimeRepository.joinSession` ends with
`loadSessionBundle(id, forceRefresh: true)` — a second complete six-request
bundle. The accept path therefore paid for the bundle **twice**: once to
hydrate before joining, once to refresh after.

The second fetch is legitimate — joining genuinely changes participant state,
and the client must see it — so it stays. Making the six concurrent repairs
both gaps at once rather than either in isolation.

### Remediated (founder-authorised into this chapter)

| Item | Before | After |
|---|---|---|
| Bundle requests | 6 sequential | 6 concurrent |
| Bundle cost, per fetch | ~2.6 s / ~1.15 s | ≈ slowest single request |
| Bundle fetches per accept | 2 | 2 (unchanged, now cheap) |
| Duplicate native answer delivery | warm **and** pending drain | warm retires the pending slot |

Failure semantics are deliberately unchanged: the session GET still throws,
and the other five still tolerate 401/403/404 — the tolerance a meeting GUEST
depends on, and which a past narrowing to 404-only once broke entirely.

ICE establishment (1.23 s) is untouched: it is real network work, and belongs
to the media transport this chapter may not reconstruct.

## AV-16 — "Call ended" announced over the call being answered

> "before connecting immediately after accept there was call ended banner, its
> odd" — founder, 2026-08-25
>
> "call ended issue not resolved" — after the first repair
>
> "call ended gone" — after the second

Founder-confirmed fixed on build `31145fa`.

### Two wrong attributions before the right one

Recorded because the wrong turns are the useful part.

**First**, the roster-count emptiness test in the socket `participant:left`
handler was suspected, on the reasoning that a join-window roster of one reads
as an emptied room. That reasoning is sound and the guard shipped — but it was
not this defect, and saying so was premature.

**Second**, `isActive == false` was read as conflating "not started" with
"ended". It does not: the server defines `isActive` as exactly
`status ∉ {ENDED, CANCELLED, FAILED}` and the client falls back to the same
rule. `hasEnded` is therefore a naming improvement, not a repair.

What settled it was instrumenting **every** path that can end a call
(`[ended-diag]`) and finding that **none of them fired** while the founder was
still seeing the banner. That is the measurement that killed both theories:
the message was never the call controller's.

### What it actually was

The notification ribbon, rendering a `CALL_ENDED` row:

```dart
// notification_presentation.dart
if (callState == 'ENDED') return 'Call ended';
```

Accepting a call foregrounds the app and triggers a notification refresh; the
previous call's ENDED row arrives into a foreground handler and is drawn as a
four-second floating snackbar over the call being answered.

### Why the existing guard did not catch it

A suppression for precisely this already existed (2026-08-22, founder-observed
on the attendee side). It asks `isCallKind`, and that set is deliberately only
the RINGING vocabulary:

```dart
{'LIVE', 'CALL', 'REALTIME', 'CALL_RINGING', 'LIVE_RINGING'}
```

Terminal kinds are excluded on purpose — the code says why: adding them "would
make the incoming-call layer treat a missed call as an arriving one". So the
guard was asking *"is a call arriving?"* where the question was *"is this about
a call at all?"*, and `CALL_ENDED` was not a call as far as it was concerned.

### Two doors, not one

The first repair added terminal kinds to the POLLED path only — and the founder
saw the banner again on the very next build. The FCM **foreground** handler has
its own `_showForegroundSnackbar` call with no call suppression whatsoever: a
terminal call push is not a "call interrupt", so it fell past the incoming-call
branch straight to the ribbon. That was the door actually in use.

| Path | Before | After |
|---|---|---|
| Polled notification rows | `isCallKind` (ringing only) | `isCallLifecycleKind` |
| FCM foreground push | **no call suppression at all** | `isCallLifecycleKind` |

`isCallLifecycleKind` is new and deliberately separate from `isCallKind`, which
is untouched so ringing semantics do not move.

### A third defect fell out of the same question

`CALL_ENDED` and `CALL_DECLINED` were absent from the Activity group map too,
so an ended call filed under **System** rather than **Calls**. The same
predicate fixes it.

### The test that should have existed

The 2026-08-22 test passed throughout this entire defect, because it only
checked the ringing vocabulary — which was already correct. The replacement
walks the bridge and asserts that EVERY snackbar path carries the refusal, so a
third door cannot be added without one, and adds the inverse assertion that a
terminal kind must never reach the incoming-call layer.

## AV-17 — ending a call never closed its public boundary

> "also after watching person leave, it back to error page and her live on
> header become offline" — founder, 2026-08-26, live with an audience

### Measured in production, not inferred

```
4 sessions: status=ENDED, liveState=LIVE
  cmt9n0tnb…  ENDED 09:18   liveState=LIVE
  cmt9m9khx…  ENDED 08:52   liveState=LIVE
  cmt9icpio…  ENDED 07:03   liveState=LIVE
  cmt9e79eb…  ENDED 05:07   liveState=LIVE
```

**One row for every call that had ever gone live.** `endSession` wrote only:

```ts
data: { status: targetStatus, endedAt: now }
```

So a finished call went on advertising itself as live. That is the founder's
report exactly: a viewer leaving is sent to a session that is over but still
claims LIVE, and lands on an error page.

The fix returns `liveState` to `NORMAL` on end — the canonical closed value
`endLiveBoundary` already walks (LIVE → ENDING → NORMAL). Written
unconditionally because it is idempotent. Observers need no separate handling:
the existing end finalises participant rows by `joinState`, not role, so
OBSERVER rows were already being finalised LEFT by the same end.

Backfill applied to the four historical rows under a terminal-status guard
(a still-running session cannot match): 4 updated, 0 stale remaining, and
0 sessions left falsely advertising as live.

### A diagnosis that was WRONG, recorded as such

The collapsed in-call dock — Mute, Turn off, Share **and** End Live all absent,
leaving only Participants / More / Leave — was attributed to the broadcaster
being demoted to OBSERVER, because that is the single client condition which
hides both sets of controls (`showPublishControls: !_amObserver`, and
`_liveControlsEligible` returning false for an observer).

Querying production disproved it:

```
M S Bajwa        role=HOST
Muhammad Zakria  role=PARTICIPANT
Mrs Bajwa        role=OBSERVER
```

The founder was HOST throughout. **The missing-controls defect is therefore
still unexplained and is NOT fixed.** It is booked to the Live chapter rather
than patched on a theory the data contradicts.

One confound to eliminate before re-measuring: that browser tab was running a
stale web build — the "newer version available" banner had been dismissed
rather than taken — so the code under observation was not necessarily current.

### Booked to the Live Broadcast chapter (founder direction, 2026-08-26)

* watchers have no chat surface;
* the Participants panel does not list watchers (the header does show
  `LIVE · N watching`);
* viewer exit has no defined destination — currently an error page;
* the missing in-call controls while live, per above.

### Structural observation, not repaired here

In `acceptSurfaceJoinWithPresenceOutcome` the PUBLIC_STAGE viewer-admission
branch sits ABOVE the normal invited-party path:

```
if (startedByUserId === actor)  → HOST, return
if (liveState === LIVE)         → viewer admission, return
   … invited-party handling lives BELOW this
```

So while a session is live, every join by anyone who is not the session starter
is routed through viewer admission. Existing rows keep their role on the
`update` branch, so this did not cause the demotion that was suspected — but
the ordering means the live path claims callers it was not written for, and it
belongs on the Live chapter's list.
