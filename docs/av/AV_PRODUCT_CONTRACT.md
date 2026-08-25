# Aura Audio / Video Call System — product contract

**Chapter opened:** 2026-08-25, founder ruling *AURA AUDIO / VIDEO CALL SYSTEM
RECONSTRUCTION TO RELEASE QUALITY*.
**Boundary:** Meetings is frozen. Live Broadcast is **closed and untouched**.

---

## 1. What A/V owns, and what it does not

| Owned by A/V | Owned elsewhere |
|---|---|
| Realtime media-session execution | Meeting identity, scheduling, attendance semantics (**Meetings**) |
| Local camera / microphone acquisition | Durable Conversation continuity (**Conversation**) |
| Permission and readiness | Notification delivery authority (**Notifications**) |
| Peer / media presence, media tracks | Consequential leave/end product semantics (**Meetings**) |
| Signaling, TURN/STUN, ICE, reconnect | Broadcast / audience surfaces (**Live — closed**) |
| Device selection and routing where supported | |
| The media failure presentation contract | |

`realtime_lobby_screen.dart` is the **Live directory**, not a call preflight.
It is named "realtime" for historical reasons and belongs to the Live chapter.
Naming does not define ownership — the same rule R-1 froze for Meetings.

## 2. The permission model

One canonical enum, `DevicePermissionState`, distinguishing every state the
ruling requires:

`notRequested` · `granted` · `denied` · `permanentlyDenied` · `restricted`
(OS policy) · `unavailable` (no device) · `inUse` (device busy) · `unknown`

`permanentlyDenied` and `unknown` were **added by this chapter**. They matter
because they change the recovery: a plain denial may re-prompt, a permanent one
never will and only a settings trip fixes it, and "unknown" must never be
reported as a refusal — accusing somebody of refusing access they did not
refuse is worse than admitting the check failed.

Recovery is derived from the state, not written at the failure site. That is
how the copy stays platform-correct by construction.

### Platform mechanism, stated honestly

| Platform | Can query status? | Can detect permanent denial? | Can open settings? |
|---|---|---|---|
| Android | yes (`permission_handler`) | yes | yes |
| iOS | yes (`permission_handler`) | yes | yes |
| Web | no — no reliable cross-browser API | no | no |
| Windows / macOS / Linux | no — OS-level, outside the app | no | no |

Where status cannot be queried, the honest answer is `notRequested` — never
`granted`. A preflight that claims readiness it has not verified is the exact
failure the system exists to prevent.

## 3. The preflight

`CallPreflightSheet` + `CallReadiness` (both in `lib/core/media/`) are the ONE
readiness capability, shared by Meetings and thread calls (§8).

Order matters and is deliberate:

1. **Ask for permission first**, as an explicit act, while the person is
   looking at an explanation of what is needed and why.
2. **Then open the devices**, because a granted permission still does not
   prove a working camera — it may be missing, held by another app, or blocked
   by policy.

Joining is never barred. Listening is a legitimate way to attend, so a refused
camera or microphone changes only what is *said*, never whether the person may
proceed.

The preview stream is released before the room opens its own capture. Two live
captures of one camera is the orphaned-device leak §17 forbids.

## 4. Media track ownership

The engine (`realtime_media_service.dart`) owns local and remote tracks,
renderers and peer connections, and releases all of them on
`resetSessionMedia` / `dispose`: every track `stop()`ed, every stream and
renderer disposed, every peer closed. Leaving releases the devices.

## 5. Controls

Camera and microphone controls name the **effect** of pressing them and
announce thing + state + effect to a screen reader
(`MediaControlLabels`). A control whose device is unusable announces why
instead of promising an action it cannot perform.

## 6. TURN / STUN — measured 2026-08-25

| Path | State |
|---|---|
| STUN | configured |
| `turn:` UDP 3478 | reachable |
| `turn:` TCP 3478 | reachable |
| `turns:` TLS 5349 | **live**, valid Let's Encrypt certificate, `Verify return code: 0` |
| `turns:` TLS **443** | **not listening** |

Credentials are ephemeral REST/HMAC (`sha1` over `expiry:identity`), scoped to
a verified session participant, with a TTL. Guests are authorized only against
the MEETING their token is scoped to.

TLS relay is offered last in the ICE server list: browsers try candidates from
every server and `turns:` is the highest-cost path, but for participants whose
network blocks UDP and plain TCP it is the only one that works.

**Enterprise limitation, stated plainly:** networks that permit egress only on
443 are not served, because nothing is listening there. See §9.

## 7. Platform configuration

Added by this chapter, all previously absent:

* **Android** — `BLUETOOTH_CONNECT` (`neverForLocation`), so call audio can
  route to a paired headset on Android 12+; `FOREGROUND_SERVICE` plus the
  Android 14 `_MICROPHONE` / `_CAMERA` types, so a backgrounded call is not
  killed; `WAKE_LOCK`.
* **iOS** — `UIBackgroundModes: audio`. Without it an iOS call goes silent the
  moment the app leaves the foreground and the other side simply stops hearing
  them. Declared because the implementation requires it; **uncertified** until
  a real device or TestFlight run exercises it.

## 8. iOS thesis — implementation included, certification NOT executed

No macOS host is available, so nothing here is certified. Implementation
targets, to be exercised when a device is available:

* camera and microphone permission via the shared service (already
  platform-correct — `permission_handler` covers iOS);
* `AVAudioSession` category/mode for voice chat, and route changes;
* interruptions (incoming phone call), background/foreground transitions;
* Bluetooth and wired headset routing, speaker vs receiver;
* safe areas and orientation in the call room;
* background audio via the declared `audio` mode.

`IOS_CERTIFICATION = NOT_EXECUTED`. Android and web results are **not** a
substitute and are not presented as one.

## 9. Known limitations

* `TURNS_TLS_443 = BLOCKED_EXTERNAL` — requires a listener on 443 on the
  coturn host, which is infrastructure access this environment does not have.
  Not hidden behind application retries.
* `IOS_CERTIFICATION = NOT_EXECUTED` — no macOS host.
* Real two-party end-to-end calls require a second authenticated account or
  device; see the certification record for exactly which paths were executed.
