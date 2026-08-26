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
