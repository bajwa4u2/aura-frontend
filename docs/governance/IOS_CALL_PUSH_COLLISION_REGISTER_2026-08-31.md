# iOS Call Push Collision Register — CallKit vs APNs/FCM

**Date:** 2026-08-31
**Scope:** every surface that can present ONE incoming Aura call on iOS, and
every way two of them can fire at once.
**Standing constraints honoured:** release hold active; **working call and
meeting systems must not be disturbed or stopped**.

## Provenance rule applied to this document

Every claim below is stated from **code or git history read directly**, not from
a code comment. That distinction is not academic here: the first draft of this
register was wrong in two places *because it trusted comments*, and the comments
themselves have now been corrected (§5). Where a comment is quoted it is quoted
as an artefact being assessed, never as authority.

**Nothing in the ring path was changed.** Every candidate remedy either removes
a ring surface or alters delivery on the live call path; neither can be
certified from a Windows workstation, and the do-no-harm instruction rules both
out. Three stale comments were corrected — comments only, no behaviour.

---

## 1. The surfaces — verified

For one incoming call an iPhone is reachable on **two independent device rows**,
and the client writes both.
`aura_final/lib/features/devices/device_service.dart` —
`registerVoipToken` posts `platform: 'IOS'`, `provider: 'APNS'`,
`deviceName: '${_resolveDeviceName()} (calls)'`; `_fcmPayload` posts
`platform: 'IOS'`, `provider: 'FCM'`, `deviceName: _resolveDeviceName()`.

| # | Surface | Trigger | Row |
|---|---|---|---|
| S1 | CallKit full-screen system ring | PushKit VoIP push | `IOS` / `APNS` |
| S2 | iOS notification banner + sound | FCM → APNs alert | `IOS` / `FCM` |
| S3 | In-app ring card (`incomingCallBridgeProvider`) | socket, or S1/S2 folding in | — |
| S4 | Foreground snackbar | FCM foreground | — (suppressed for calls) |

Only `CALL_RINGING` becomes a VoIP push — `apns-push.adapter.ts:106`,
`isVoipInvite = !isSilent && payload.type.toUpperCase() === 'CALL_RINGING'`,
which selects topic `<bundle>.voip` and `apns-push-type: voip`.
**Meetings never enter this path** — `meeting-notification.service.ts` emits no
`CALL_RINGING`; meeting kinds travel the ordinary alert route and are untouched
by the China correction and by everything in this register.

---

## 2. THE ROUTING POLICY — corrected

> **This is the correction that matters.** `push-notification.service.ts`
> carried a comment reading *"The active policy is DEFAULT_RING_POLICY =
> RING_ALL_ACTIVE, which is the platform's existing, preserved behaviour."*
> **That comment was false.**

Read from code: `multi-device-authority.ts:85` —

```ts
export const DEFAULT_RING_POLICY: RingPolicy = 'PREFERRED_FIRST_THEN_ALL'
```

…which the same file documents as a founder decision of 2026-08-15, explicitly
noting that "RING_ALL_ACTIVE was the preserved interim behaviour and is
explicitly NOT the desired final semantics." The authority file was right; two
of its own doc comments and the consuming service's comment were stale.

Actual behaviour of `resolveRoutingDecision` (lines 161-204), verified:

| Condition | `immediate` | `deferred` |
|---|---|---|
| an **ELIGIBLE preferred** device exists | `[preferred]` only | **every other eligible device**, after `RING_STAGGER_MS = 6_000` |
| no eligible preferred device (the default — `isPreferred` defaults false) | all eligible | `[]` |

Eligibility is `classifyDeviceEligibility` (line 123): not revoked, `isActive`,
non-empty token. Both iOS rows qualify.

`scheduleDeferredRing` (line 335) guards the second wave with
`isCommunicationResolved(sessionId)` — so a call answered inside 6s never fires
it. A call still ringing at 6s does.

---

## C1 — Double ring: CallKit *and* a banner, one call, one phone

**Status: CONFIRMED, pre-existing in build 35. Not introduced by the China
correction — and deliberately NOT "fixed".**

`fcm-push.adapter.ts:131` sets
`deviceOwnsCallPresentation = isCallInvite && isAndroidDevice`, and line 179
sets `message.notification` whenever `!isSilent && !deviceOwnsCallPresentation`.
On iOS `isAndroidDevice` is false, so the notification block is set and a banner
is drawn — while the APNS row separately produces the CallKit ring.

**Two shapes, depending on the policy branch above:**

- **No preferred device (default):** S1 and S2 fire simultaneously. One phone,
  one call, a full-screen system ring *and* a banner with sound.
- **A preferred device is set:** one row rings at t=0 and **the other half of
  the same phone rings at t=6s**. If the FCM row is preferred, a full-screen
  CallKit ring erupts six seconds into an already-ringing call.

**The obvious remedy is wrong, and this is the most important finding here.**

The obvious remedy — suppress the iOS FCM row for `CALL_RINGING` when a paired
VoIP row exists — is implementable, because the rows pair exactly on the
`" (calls)"` suffix the client writes. It should not be implemented.

**S2 is not a cosmetic duplicate; it is the safety net that makes both the
storefront gate and PushKit itself survivable.** S1 can legitimately be absent:
while the capability is `withheld` there is no VoIP registration by design;
PushKit delivery has its own failure history across builds 28-35; and a cold
launch can race registration. In each case S2 is the only thing that rings the
phone. Suppressing it converts a jarring double-ring into silent missed calls —
the exact failure the standing instruction forbids.

**Recommendation:** keep the redundancy. If the double-ring is judged
unacceptable, the fix is *coordination*, not suppression — S2 sent data-only to
the paired device with the app dismissing it once CallKit has presented — and it
requires device certification of PushKit reliability first.

---

## C2 — `apns-collapse-id` is never sent; iOS collapse semantics are inert

**Status: CONFIRMED by reading every request header.**

`apns-push.adapter.ts:113-121` sends exactly `:method`, `:path`,
`authorization`, `apns-topic`, `apns-push-type`, `apns-priority`,
`content-type`. **No `apns-collapse-id`.** `collapseKey` appears only inside the
JSON body — `buildVoipBody` (line 202) and `buildBody` (line 224) — where APNs
never reads it. `fcm-push.adapter.ts` sets `android.collapseKey` and an Android
notification `tag`, and its `apns.headers` block (lines 170-174) carries only
`apns-push-type`/`apns-priority`, and only when silent.

| Platform | Collapse actually applied |
|---|---|
| Android | yes (`collapseKey` + `tag`) |
| Windows / WNS | yes |
| Web | yes (`collapseKey`) |
| **iOS** | **no** |

Consequences, both "broken system" symptoms: a retried or duplicated ringing
push **stacks a second banner** instead of replacing the first — CallKit
coalesces correctly by derived UUID, the banner does not; and the terminal push
cannot replace the ringing banner.

**Remedy (scoped, not applied):** set `apns-collapse-id` on the **alert path
only**. It must NOT be added to the VoIP path — collapse behaviour under
`apns-push-type: voip` cannot be verified from this workstation, and a rejected
VoIP push is precisely the silent non-ringing phone this work protects.

---

## C3 — A delivered iOS ring banner is never cleared when the call ends

**Status: CONFIRMED.**

`native_call_notification_channel.dart` returns early on `!Platform.isAndroid`,
so `cancelNativeCallNotifications()` is Android-only. A search across `lib/`
finds no `removeDeliveredNotifications`, no `flutter_local_notifications`, and
no iOS notification-clearing path of any kind.

The terminal push is sent silent — `buildBody` emits
`{ 'content-available': 1 }` with `apns-push-type: background` — which carries
no alert and therefore cannot replace a displayed one; and with C2 unfixed it
cannot collapse one either. So after a call is answered elsewhere, declined,
missed or expired, the "Incoming call…" banner stays in Notification Center.

**Remedy (not applied):** clear delivered call notifications from the client at
the existing terminal choke point — the bridge-removal listener in
`AuraIncomingLiveLayer`, which the codebase already routes every real outcome
through. A client change on the live ring path; needs device certification.

---

## C4 — CallKit and the in-app card both hold the same call

**Status: BY DESIGN, working, verified not to regress.**

The VoIP handler emits `incomingCall`, which `aura_app.dart` folds into
`incomingCallBridgeProvider` so terminal reconciliation reaches both surfaces.
`IncomingCallBridgeNotifier.addIncoming` dedupes by notification id **and**
session id (verified, `incoming_call_bridge.dart:100-115`), so the socket's
later `call:incoming` is absorbed rather than stacking a second card.

The historical "accept → full screen ring → call surface buried" defect was
repaired in `callConnected` by requesting `CXAnswerCallAction` instead of ending
the call. **That repair is intact** — the China correction gates the path on
`callKitAllowed` and does not alter its behaviour on a permitted storefront.

---

## C5 — CORRECTED: the ring stagger is **live**, not inert

> **The first draft of this register said "Ring stagger is inert … under
> `RING_ALL_ACTIVE` the routing returns `deferred: []`, so
> `scheduleDeferredRing` never fires." That was wrong**, and wrong precisely
> because it trusted the stale comment corrected in §2.

Under the real policy, `scheduleDeferredRing` fires whenever an eligible
preferred device exists and the call is still unresolved 6s in. It is the
mechanism behind C1's second, worse shape. Its damage is bounded by the
`isCommunicationResolved` guard and by `RING_STAGGER_MS` sitting far below the
90s ring TTL — but it is not inert.

---

## C6 — Terminal call pushes no longer raise a ribbon

**Status: ALREADY FIXED, verified still in place.**
`_onFcmForeground` returns early for any call-lifecycle kind, so `CALL_ENDED` /
`CALL_MISSED` / `CALL_DECLINED` cannot raise the snackbar. Untouched.

---

## C7 — NEW: one iPhone appears as two devices, and a preference selects half of it

**Status: CONFIRMED, previously unrecorded.**

`isPreferred` is a per-**row** flag (`schema.prisma` `UserDevice.isPreferred`),
but one iPhone owns two rows. `devices_screen.dart:48` lets the person mark any
row preferred — `updateDevice(device.id, {'isPreferred': true})` — and the list
renders every row, so the phone is shown to its owner as two entries: *"iPhone"*
and *"iPhone (calls)"*.

Two consequences: the devices list presents a phantom duplicate device, and
choosing either entry sets a routing preference over **half a phone**, deferring
the other half by 6s (C1's second shape). Nothing in the routing authority knows
the two rows are one device.

**Remedy (not applied):** either pair the rows for presentation and preference —
the `" (calls)"` suffix already makes them pairable — or hide the VoIP row from
the devices list and inherit preference from its paired FCM row. A product
decision with a data-model consequence; out of scope here.

---

## 3. Effect of the China correction on each collision

| | Permitted storefront | China / withheld |
|---|---|---|
| S1 CallKit | unchanged | absent by design |
| S2 banner | unchanged | **the primary surface** |
| S3 in-app card | unchanged | unchanged |
| C1 double ring | unchanged (pre-existing) | **resolved as a side effect** — one row, one ring |
| C2 / C3 / C7 | unchanged | still open, and now matter more |

The correction **removes** a collision in China, **changes nothing** on a
permitted storefront, and introduces no new collision.

## 4. The one risk the correction introduces, and how it was closed

While the capability is `withheld` there is no VoIP registration, so a cold
launch inside that window could miss a CallKit ring.

Two things bound it. The initial storefront read is **synchronous inside
`didFinishLaunchingWithOptions`** — the storefront is cached on device and needs
no network round trip — so on a healthy launch the VoIP registration is made at
the same point in launch as before this policy existed. And the retry schedule
was changed from a flat 1s to an escalating one starting at **50 ms**
(`0.05, 0.1, 0.2, 0.4, 0.8, 1.0×5, 2.0×5`), so an unusual launch closes the
window in milliseconds.

Beneath both, S2 still rings the phone — which is exactly why C1's redundancy
was left alone.

## 5. Records corrected in this pass

| File | Was | Now |
|---|---|---|
| `push-notification.service.ts` | "The active policy is DEFAULT_RING_POLICY = RING_ALL_ACTIVE … this refactor changes WHO decides, not WHAT is delivered" | states the real policy, both branches, and the iOS two-row consequence |
| `multi-device-authority.ts` (`RingPolicy` union) | `RING_ALL_ACTIVE` — "this module's default" | marked as the pre-2026-08-15 interim, explicitly not the default |
| `multi-device-authority.ts` (`resolveRoutingDecision` doc) | "`RING_ALL_ACTIVE` — the default — produces exactly the delivery behaviour the platform has today" | corrected, with why the error stayed invisible |

Comments only; no behaviour changed. `npx tsc --noEmit` clean for both files;
`npx jest src/common/devices src/communications/push` — **50 passed**.

## 6. Verdict

**No working call or meeting system was disturbed.** Meetings never touch the
VoIP path. On a permitted storefront every call path behaves as before. Zero
Dart source was changed. The backend changed only in comments. And the live
1.3.0 build is unaffected in every respect — **verified from git, not from a
comment**: at commit `db3a088` (which introduced `version: 1.3.0+24`)
`ios/Runner/AppDelegate.swift` contained zero occurrences of `CallKit` and
`ios/Runner/Info.plist` zero occurrences of `<string>voip</string>`; `import
CallKit` first appears in `f13fb82`, "iOS gets Apple's incoming-call
architecture instead of a banner", after that tag. 1.3.0 devices therefore hold
no APNS/VoIP row at all.

C1, C2, C3 and C7 are pre-existing iOS defects, now documented with direct code
evidence and scoped remedies. None is a regression, and none is safe to fix
without a device. They belong with the next authorized iOS build, certified on
hardware.
