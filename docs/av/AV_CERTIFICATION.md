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
