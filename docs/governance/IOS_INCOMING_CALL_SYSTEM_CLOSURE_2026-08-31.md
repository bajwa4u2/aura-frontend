# iOS Incoming-Call System — delivery, presentation and jurisdiction

**Date:** 2026-08-31
**Authority:** founder/management expansion of the China CallKit correction into
one bounded capability: **iOS incoming-call delivery + presentation +
jurisdiction policy**, to be finished as one system before the next binary.
**Release hold:** ABSOLUTE and preserved. No build, binary, submission,
territory change or rollout.
**Predecessors:** `CHINA_CALLKIT_JURISDICTION_REMEDIATION_2026-08-31.md`,
`IOS_CALL_PUSH_COLLISION_REGISTER_2026-08-31.md`,
`DISTRIBUTION_PROVIDER_STATE_2026-08-31.md`.

---

## 0. The product invariant this was measured against

> ONE INCOMING CALL → ONE COHERENT USER-VISIBLE RING → ONE ACCEPT/DECLINE
> AUTHORITY → ONE ACTIVE CALL TRANSITION → CLEAN TERMINAL TEARDOWN.

The instruction that shaped every decision below: **do not solve this by
removing redundancy.** Multiple mechanisms may carry evidence of one call. Only
one may own the user's attention. Delivery redundancy was kept — in one place it
was deliberately kept even though removing it would have been simpler and would
have looked like a fix.

---

## 1. The publicly disclosed build-35 experiences

The published known-issues text is not held in this repository; it is
paraphrased here from management's statement of it, and that limitation is
recorded rather than papered over.

| | Disclosed experience |
|---|---|
| **LOCKED iPhone** | the incoming-call surface can become buried/lost if the user does not act quickly; practical recovery is opening Aura and continuing there |
| **UNLOCKED iPhone** | the full-screen incoming-call experience can appear abruptly, and after acceptance the overlay can survive over the active call / the transition feels wrong |

## 2. Causality — proven and disproven, against source and history

The instruction was explicit: prove or disprove each relationship, and do not
retrofit evidence to the hypothesis. Two of my own early hypotheses were wrong
and are recorded as wrong.

### `C1_DUAL_DELIVERY_CAUSALITY` — **PROVEN for system presentation, DISPROVEN for the in-app card**

One iPhone holds two endpoints and both were rung. `fcm-push.adapter.ts` set
`deviceOwnsCallPresentation = isCallInvite && isAndroidDevice`, so on iOS
`message.notification` was attached and a banner was drawn — beside the CallKit
ring the APNS endpoint produced. Two system presentations, one call.

**Disproven half, and it matters:** I expected the same duplication in Aura's
own card. It is not there. `IncomingCallBridgeNotifier.addIncoming` dedupes by
notification id *and* session id, `_normalizeIncomingPayload` lifts `sessionId`
into `data` for every transport shape, and `IncomingCallPrecedenceGuard`
tombstones a resolved session so a late socket-or-push delivery cannot resurrect
it. The Dart presentation layer was already correct. **The duplication was
entirely at the system layer, which Dart does not control** — which is why the
fix had to be a backend and native one.

### `C7_PHYSICAL_DEVICE_CAUSALITY` — **PROVEN, and the sharpest cause of "abruptly"**

`isPreferred` is a per-**row** flag; `devices_screen.dart:48` lets a person mark
any row preferred and renders every row, so one iPhone appeared to its owner as
two devices, *"iPhone"* and *"iPhone (calls)"*. Under the real policy —
`DEFAULT_RING_POLICY = 'PREFERRED_FIRST_THEN_ALL'` — preferring either half put
**the other half of the same phone in the deferred set**, rung
`RING_STAGGER_MS = 6_000` later if the call was still unresolved.

So a person who had set a preference got one surface at t=0 and **the other
surface of the same phone six seconds into the ring**. If the FCM row was
preferred, that second surface is a full-screen CallKit takeover arriving six
seconds late. That is what "appears abruptly" describes, and it is a *mechanism*
rather than a guess.

Conditional, and stated as such: it requires a preferred row to have been set,
which cannot be established from source. With no preference — the default —
both surfaces fire simultaneously instead, which is the same defect at t=0.

Independent corroboration from history: build 33, founder — *"strange ring came
while zakria was already dropped."* A late ring, not an absent one. Build 34
existed only to make that measurable.

### `C3_CLEANUP_CAUSALITY` — **PROVEN, and the best-evidenced cause of the LOCKED defect**

`cancelNativeCallNotifications()` returns early on `!Platform.isAndroid`, and a
search of `lib/` finds no `removeDeliveredNotifications` and no
`flutter_local_notifications`. **Nothing on iOS ever cleared a delivered call
notification.** The terminal push is `silent` (`content-available`,
`apns-push-type: background`), which carries no alert and therefore cannot
replace a displayed one.

The lifetime mismatch that completes the story: Aura's invite TTL is
`RING_TTL_SECONDS = 90` (verified in `realtime-session.service.ts:59`, matched
by the overlay's own `_ringTimeout = Duration(seconds: 90)` — the two are
**aligned**, so the client timer is not the culprit and that hypothesis is
**disproven**). But the CallKit ring's lifetime is system-controlled and is not
90s, and **no source path observes CallKit giving up**. When it does, the system
surface vanishes while the invitation is still live — leaving a stale,
still-actionable banner and an in-app card reachable only by opening the app.
*"Buried/lost … recovery is opening Aura and continuing there"* is that state
described from outside.

### `C2_COLLAPSE_CAUSALITY` — **PROVEN as an amplifier, not a root cause**

`collapseKey` was carried in the APNs JSON body, where APNs never reads it; the
request sent `apns-topic`, `apns-push-type`, `apns-priority`, `content-type` and
no `apns-collapse-id`. iOS was the only one of four platforms where collapse was
declared and inert, so retries and duplicates **stacked banners** instead of
replacing them. It cannot by itself bury a call, but it multiplies every other
defect here.

### Two hypotheses I disproved, recorded so they are not re-run

1. **"The CallKit answer path reports the call ended."** I read
   `joinThreadCallSession` as calling `removeBySession` (→ `reportEnded`). It
   does not — that call is inside `handleTerminal`. `_startJoin` calls
   `clearAccepted` on success, which reports **connected**. I had inferred from
   grep line numbers instead of reading the body.
2. **"The overlay's ring timer kills the lock-screen ring early."** The client
   timeout and the server TTL are both 90s.

### `BUILD35_LOCKED_DEFECT_ROOT_CAUSE`

**No presentation authority across the system ring's lifetime.** CallKit and the
ordinary banner presented the same call independently; CallKit's ring is
system-lifetime and unobserved, the banner's was never cleared by anything, and
neither handed the call back to a durable surface when it gave up. Amplified by
C2 (banners stacking) and, where a preference was set, by C7 (a second surface
arriving 6s in).

### `BUILD35_UNLOCKED_DEFECT_ROOT_CAUSE`

**Two system surfaces for one call, and — with a preference set — six seconds
apart.** C1 supplies the duplication, C7 supplies the delay that makes it feel
abrupt, C3 supplies the banner that outlives the accept. Aura's own in-app card
is *not* implicated: it clears on accept and is tombstoned against late
re-delivery, which is why "the overlay survives over the active call" is best
explained by the notification banner, not by `AuraIncomingLiveLayer`.

---

## 3. The architecture built

### `CANONICAL_PHYSICAL_DEVICE_MODEL` — the missing identity layer

`multi-device-authority.ts` already separated USER / DEVICE / TRANSPORT /
SESSION. It was missing the distinction between **an endpoint** (a delivery
credential) and **a phone**. That layer is now expressed:

```
USER  →  PHYSICAL DEVICE  →  ENDPOINT  →  TRANSPORT  →  SESSION
```

**No identity was invented.** `ClientIdentity.runtimeDeviceId` already exists: a
`Random.secure()` 32-hex value persisted in SharedPreferences per installation,
sent on every request as `X-Aura-Device-Id`, parsed by the platform middleware,
and documented in its own source as being for *"grouping same-device sessions"*.
It is now stamped onto `UserDevice.installationId` **server-side from the
request**, never from the body — a client does not get to claim which phone it
is.

Never derived from a push token: tokens rotate, and grouping by one would split
a phone in two the moment APNs reissued a credential. A test pins that.

`installationId` is nullable and **null is not a defect**: pre-existing rows are
each treated as their own physical device, which is exactly the previous
behaviour. Grouping strengthens as clients re-register; nothing regresses while
they have not.

### `CANONICAL_CALL_IDENTITY`

`sessionId`, unchanged. It was already canonical —
`buildCanonicalIncomingCallNotification` sets `collapseKey = sessionId` — and is
now used consistently as the collapse id, the dedup key, the tombstone key and
the notification-cleanup selector. Two simultaneous legitimate calls carry two
session ids and can never collapse or clear each other.

### `DELIVERY_REDUNDANCY_MODEL` / `PRESENTATION_AUTHORITY`

| Layer | Rule |
|---|---|
| Delivery | every endpoint of a phone still receives the call |
| Presentation | exactly ONE endpoint per phone presents |

`resolvePhysicalDevices` groups endpoints; `selectPresentingEndpoint` picks the
presenter — **an eligible iOS APNS endpoint wins, because a PushKit push reaches
CallKit and CallKit is the better presentation and the one Apple intends**;
otherwise the FCM endpoint presents and its banner *is* the ring. Siblings become
**companions**: delivered in the same wave, carrying
`presentationOwnedElsewhere: true`, which makes the FCM adapter drop the
notification block exactly as it already does for Android.

**The China fallback needs no jurisdiction knowledge on the server.** A phone
where CallKit is prohibited has no VoIP endpoint, because the client deregisters
it — so its FCM endpoint is the presenter and rings normally. The client's
registration state already carries the answer.

`FOREGROUND_PRESENTATION` / `BACKGROUND_PRESENTATION` / `LOCKED_PRESENTATION` —
on a permitted storefront the system owns the incoming presentation (CallKit) in
every lifecycle state, and Aura's in-app card is the reconciliation surface
underneath it, suppressed by route once the person is in the call.
`CHINA_PRESENTATION` — the ordinary notification plus Aura's in-app card, which
is the same card every non-CallKit platform already uses.

### `PREFERRED_FIRST_THEN_ALL_BEHAVIOR`

Preserved, not regressed — and a test asserts the constant. The stagger now
separates **phones**, which is what it was always for.

- `SAME_PHYSICAL_DEVICE_TRANSPORT_BEHAVIOR` — never staggered. A companion
  travels with its presenting sibling, in the same wave.
- `OTHER_DEVICE_FALLBACK_BEHAVIOR` — unchanged. Other phones still ring after
  `RING_STAGGER_MS`, still guarded by `isCommunicationResolved`, and a deferred
  phone's companion is deferred with it.
- A preference on an ineligible endpoint still falls back to every phone: a
  preference can never silence a call.

### `IOS_COLLAPSE_IMPLEMENTATION` / `IOS_DEDUPLICATION`

`apns-collapse-id: <sessionId>` is now sent — **on the alert path only**, capped
at the 64 bytes APNs accepts, dropped rather than truncated if longer. It is
deliberately NOT set on the VoIP path: collapse behaviour under
`apns-push-type: voip` is unverified here and a rejected VoIP push is a phone
that does not ring. CallKit already coalesces by the UUID derived from the
session id.

Application-level dedup is unchanged and was already correct: dedup by id and
session id, plus the precedence tombstone, which is what makes socket + push
convergence safe across foreground, background, cold launch and late delivery.

### `IOS_NOTIFICATION_CLEANUP`

New native method `clearCallNotifications`, using
`UNUserNotificationCenter.removeDeliveredNotifications` **and**
`removePendingNotificationRequests`. Deliberately **not** a copy of the Android
code, which cancels a channel the app itself drew; these notifications are
delivered by APNs with system-assigned identifiers, so they are matched on the
payload instead.

`notificationBelongsToCall` reads all three real shapes — the APNs body's nested
`data.sessionId`, FCM's top-level `sessionId`, and FCM's flattened
`gcm.notification.sessionId` — because a matcher that knew one would leave the
other transport's banner on screen. An empty session id matches nothing, so a
malformed terminal event cannot clear the tray.

Wired at the **existing** choke points, so every terminal state is covered by
construction rather than by enumeration:

| Path | Effect |
|---|---|
| `_onSessionTerminated` | `DECLINE_TEARDOWN`, `CALLER_CANCEL_TEARDOWN`, `EXPIRY_TEARDOWN`, `ANSWERED_ELSEWHERE_TEARDOWN`, superseded — CallKit reported ended **and** the banner cleared |
| `clearAccepted` | `ACCEPT_TRANSITION` — CallKit reported **connected**, banner cleared, and deliberately never `reportEnded` (that is build 30's defect, which hangs up the call) |

**Not gated on the CallKit capability.** In China, and whenever the storefront is
unresolved, the banner is the only incoming-call surface — clearing it matters
more there, not less. A test enforces that the gate is absent.

`LATE_DELIVERY_BEHAVIOR` — a late or duplicate delivery for a resolved session
is refused by the tombstone, whichever transport carries it.

---

## 4. China compliance — preserved as a hard invariant

`CHINA_CALLKIT_POLICY` unchanged: `CHN` → prohibited, other established
storefront → available, unknown/unresolved → withheld, capability starts
withheld and opens only on affirmative evidence. All four discovered bypass
paths remain gated and remain regression cases.

`CHINA_FALLBACK_CALLING` — strengthened, not weakened, by this work. A phone
with no VoIP endpoint is now the *presenter* by policy rather than by accident,
and its banner is now cleared on every terminal state where before it was never
cleared at all.

`NON_CHINA_CALLKIT_REGRESSION` — none. On a permitted storefront the CallKit
path is byte-for-byte the behaviour build 35 shipped, minus the competing
banner. `test/release/china_callkit_jurisdiction_gate_test.dart` (20 tests) and
`call_accept_is_not_termination_test.dart` both still pass.

---

## 5. Proof

| Suite | Count | Executed |
|---|---|---|
| Backend jest — full suite | **4082 tests / 327 suites** | ✅ all pass |
| — of which new: `physical-device-routing.spec.ts` | 16 | ✅ |
| — new `apns-push.adapter.spec.ts` | 5 | ✅ |
| — extended `fcm-push.adapter.spec.ts` | +3 | ✅ |
| — extended `push-notification.service.spec.ts` | +4 | ✅ |
| Dart — call/notification blast radius | **269 tests** | ✅ all pass |
| — of which new `ios_incoming_call_presentation_test.dart` | 16 | ✅ |
| — existing `china_callkit_jurisdiction_gate_test.dart` | 20 | ✅ |
| `SWIFT_XCTESTS_TOTAL` | **24** (23 substantive + Flutter's `testExample`) | ❌ **not on this workstation** |
| Prisma migration | replay-from-empty on disposable Postgres + idempotency re-run | ✅ |

`SWIFT_XCTESTS_EXECUTED = 0` on this machine — it is Windows and XCTest needs
Xcode. That is precisely why the CI gate below now exists.

### `MUTATION_PROOF`

A suite that cannot detect reintroduced duplicate presentation is insufficient,
so each defect was reintroduced and each was caught. Every mutation was reverted
and the sources verified identical afterwards.

| Mutation | Caught by |
|---|---|
| iOS banner suppression reverted to Android-only (restores the double ring) | Dart 1 fail · jest 1 fail |
| Terminal choke point stops clearing the banner (restores the stale ring) | Dart 1 fail |
| Phone identity derived from a rotating token | Dart 1 fail · **jest 13 fail** |
| Companion delivered without the suppression flag | jest 2 fail |
| `apns-collapse-id` removed again | Dart 1 fail · jest 1 fail |
| *(earlier pass)* build-35's unconditional CallKit at launch restored | Dart 1 fail |

A first mutation attempt silently applied nothing — Python could not resolve
Git-Bash paths — and reported five false passes. It was caught, redone with real
paths, and only the second run is reported here. Restoring one file used
`git checkout`, which reverted the *real* `apns-collapse-id` work along with the
mutation; it was detected immediately and re-applied.

### `CODEMAGIC_NATIVE_TEST_GATE`

`ios-certification` gains **"Certify the NATIVE layer — XCTest on the Runner
target"**, before the integration suites:

```
flutter build ios --config-only --simulator --debug
xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner \
  -destination "id=$UDID" -only-testing:RunnerTests \
  -resultBundlePath certification/native-tests.xcresult
```

It fails the build on XCTest failure **and on zero executed tests** — the trap
this lane has already been burned by, where suites that skipped everything
exited 0 and were recorded as passes. Two Dart tests pin the gate itself so it
cannot be quietly removed. The `.xcresult` bundle is an artifact.

---

## 6. Meetings — boundary held

Re-verified against source, not carried forward on trust: only `CALL_RINGING`
becomes a VoIP push (`apns-push.adapter.ts:106`), and
`meeting-notification.service.ts` emits no `CALL_RINGING`. **No meeting path
touches PushKit, CallKit or any code changed here.** No Meetings file was
modified. No contradiction was found; had one been, this work would have stopped
and reported it.

Observation, unfixed and deliberately so: the overlay's route suppression tests
`currentPath.contains('/live/')`, which does not match the meeting-branch route
`/meetings/<id>/live?sessionId=…`. It is currently moot — the accept path
removes and tombstones the entry regardless — and touching it means touching a
protected surface. Recorded, not changed.

---

## 7. Records corrected in this pass

| Record | Correction |
|---|---|
| `push-notification.service.ts` class comment | claimed delivery was "deliberately UNCHANGED — every active device still gets the push" and the ring policy was "still-open". Both false since 2026-08-15 |
| `schema.prisma` `UserDevice.isPreferred` | claimed the field "does not change push delivery … pending the still-open founder ring-policy decision". It is a real input to the governed policy |
| `fcm-push.adapter.spec.ts` iOS test name | said iOS is "left alone: it has no equivalent hook". Now names the actual condition — a phone with no PushKit endpoint, where the banner **is** the ring |
| This session's own remediation doc | said "19 Swift tests" (actual: 17 then, 23 substantive now) and "no CI workflow invokes the iOS test target; wiring one is unauthorized" — since authorized and done |

Earlier in the same session three stale ring-policy comments were corrected for
the same reason. The pattern is recorded as a standing lesson: a comment is an
artefact to be assessed, never an authority.

---

## 8. Status

```
NEW_BUILD_CREATED = NO · NEW_BINARY_UPLOADED = NO · NEW_SUBMISSION_CREATED = NO
APPLE_SUBMISSION_CHANGED = NO · APP_STORE_TERRITORIES_CHANGED = NO
ROLLOUT_STARTED = NO · RELEASE_HOLD_PRESERVED = YES
SOURCE_RECONSTRUCTION_COMPLETE = YES
AUTOMATED_NATIVE_PROOF_COMPLETE = YES (written and gated; not yet executed)
READY_FOR_EVENTUAL_CONSOLIDATED_DEVICE_PROOF = YES
```

### `NEXT_RELEASE_CORRECTION_RECORD` — the public statement this supports

We said publicly that the iPhone incoming-call experience was being
corrected/refined in the next release. The chain behind that statement:

| | |
|---|---|
| **Known issue** | build 35 locked: call surface buried/lost. Build 35 unlocked: full-screen ring appears abruptly, overlay survives acceptance |
| **Root cause** | no presentation authority across two independently presenting system surfaces on one phone (C1), a phone modelled as two devices so one preference staggered it against itself (C7), a banner nothing ever cleared (C3), and inert collapse that stacked what should have replaced (C2) |
| **Correction** | physical-device identity from existing client identity; one presenting endpoint per phone with the sibling delivered but silent; `apns-collapse-id` on the alert path; delivered-notification cleanup at both terminal choke points |
| **Proof** | 4082 backend + 269 Dart tests green, 5 mutations caught, migration replayed and re-run, 23 native tests written and gated in CI |
| **Carried by** | the next iOS binary — build ≥ 36, not created |

### `PHYSICAL_IPHONE_PROOF_REQUIRED = YES` · `PHYSICAL_IPHONE_PROOF_READY_FOR_CONSOLIDATED_CANDIDATE = YES`

Source is stable and no further intermediate builds are needed. When the hold
lifts, ONE consolidated candidate should carry all of this, and the device
matrix must specifically revisit the two disclosed experiences:

1. **LOCKED** — ring, do not act, let the system ring lapse; confirm no stale
   banner survives and the call is still reachable coherently.
2. **UNLOCKED** — ring, accept, confirm exactly one surface throughout and no
   overlay over the active call.

Plus: preferred-device set on each half of the same iPhone; a second physical
device still staggering; decline / caller-cancel / expiry / answered-elsewhere;
cold launch from a locked answer; and a China-mainland storefront account
confirming CallKit never appears while Aura calling still works.

### Remaining debt, stated rather than carried silently

`KNOWN_IOS_RING_COLLISION_DEBT_REMAINING`
- The presenting/companion split only takes effect once a client re-registers
  and the server stamps `installationId`. Until then, legacy rows behave as
  before — correctly, but without the improvement.
- A phone whose PushKit registration exists but whose VoIP push fails to arrive
  now has a companion FCM delivery with **no banner**. The invitation still
  reaches the app, and the socket path still rings it in foreground, but a
  suspended app in that narrow case is quieter than it was. This is the one
  place redundancy was reduced, it was a deliberate trade, and it belongs in the
  device matrix.

`KNOWN_IOS_PRESENTATION_DEBT_REMAINING`
- CallKit's own ring lapse is still unobserved: when the system ends an
  unanswered incoming call, no source path notices, and the in-app card is the
  only remaining surface. The cleanup and collapse work removes the *stale*
  half; handing presentation back deliberately when CallKit lapses is not built.
- The devices screen still lists one iPhone twice. Routing no longer cares, but
  the person still sees "iPhone" and "iPhone (calls)". Presentation-layer fix,
  not attempted here.
- 23 native tests are written, gated and **never executed**. Until one CI run
  goes green, that is a claim about coverage, not a demonstration of it.

---

# ADDENDUM — final architectural pass (same day)

Management held the native lane and asked one question: should presentation
authority belong to an ENDPOINT at all? It should not, and the model below
replaces the endpoint-scoped one. Everything listed in §3 is preserved.

## A1. The correction that mattered

My previous model suppressed the fallback banner whenever a VoIP endpoint
**existed**. That is presentation inferred from registration, and I had named
the consequence myself: *"a phone whose PushKit registration exists but whose
VoIP push fails now gets a companion delivery with no banner."* A registration
is not evidence that this particular push produced a ring. A stale token, a
revoked credential or an APNs rejection would have left a phone that was told
nothing, silenced on the strength of a row in a table.

**`CALLKIT_PRESENTATION_ACK` — two signals, at the two moments they exist.**

| Moment | Signal | Used for |
|---|---|---|
| Send time (server) | the presenting transport's **actual delivery result** for THIS call | whether the companion may present |
| Present time (device) | `reportNewIncomingCall` returning without error | retracting a banner that arrived anyway |

APNs accepting the VoIP push is the strongest evidence the platform gives at
send time. It is evidence, not proof — acceptance is not presentation — so the
device closes the remaining gap: the instant CallKit has actually presented, the
client retracts any delivered banner for that session. Between the two the
invariant holds in both directions.

`FALLBACK_PRESENTATION_POLICY` — the companion is **always delivered**; it
presents unless the presenting transport's send for this call succeeded. The
server logs `call.invite.fallback_presents` with the failure code whenever it
does, so the fallback is observable rather than silent.

## A2. Presentation identity and ownership

`CANONICAL_PRESENTATION_IDENTITY = (sessionId, installationId)` — the canonical
call on one physical installation. Since one app process is one installation,
the device-local identity is `sessionId`, which is exactly what the bridge's
dedup and its precedence tombstone already key on.

`TRANSPORTS_ARE_DELIVERY_ONLY = YES`. PushKit, APNs/FCM alert and the socket
carry evidence. CallKit, the system banner and Aura's in-app card present.
`PRESENTATION_AUTHORITY_OWNER` = the device-local coordinator for
`(sessionId, installation)` — the first mechanism to establish presentation owns
it, and the others converge on it or retract.

**No new coordinator object was created.** The one that was needed already
existed: `IncomingCallBridgeNotifier` plus `IncomingCallPrecedenceGuard` is a
per-installation, per-session presentation state machine — every transport
enters through `addIncoming`, dedup is by canonical call identity, and a
resolved session is tombstoned so nothing can re-present it. What was missing
was not a noun; it was the native half handing its two facts to that authority.
Adding nouns here would have been architecture for elegance.

## A3. `CALLKIT_RING_LAPSE_MODEL`

**iOS exposes no callback for "the incoming-call UI stopped being visible."**
Nothing was invented to pretend otherwise. What it does expose is the call
**ending**, through `CXCallObserver`, and that is the honest proxy — now
observed for the first time.

Every path that ends a call deliberately forgets it first, so a call still in
the ledger when CallKit reports it ended was ended by the platform: the system
ring window elapsed. That window is shorter than Aura's 90s invitation TTL and
is not ours to configure.

`UNANSWERED_CALL_TERMINAL_MODEL` — the backend's invitation lifecycle stays
canonical and nothing fabricates a terminal state from a UI event. A lapse means
only that the SYSTEM surface retired, so: the delivered banner is retracted
(nothing stale competes), Dart evicts the entry if the invitation has genuinely
expired, and the still-live in-app card becomes the surface. Opening Aura then
shows the call, which is the intended recovery and answers the disclosed
locked-iPhone symptom directly.

## A4. Device model and preference

`DEVICE_LIST_PHYSICAL_MODEL` — `groupIntoPhysicalDevices` projects registrations
into phones for every human-facing list. One iPhone is one entry, named
*"iPhone"* rather than *"iPhone (calls)"*. **It groups, it does not merge**: the
rows and their separate credentials are untouched, transport detail stays
available for diagnostics, and removing a phone now revokes *every* one of its
registrations — revoking half a phone would leave it still ringing.

Grouping is by `installationId`, never by device name: two identical iPhones
would otherwise collapse into one entry and a person would lose a device. A test
pins that.

`PREFERRED_PHYSICAL_DEVICE_MODEL` — the write side now agrees with the read
side. Marking any endpoint preferred marks every endpoint of that installation
and clears every other installation, in one transaction. At most one preferred
phone per person, as before; the unit is simply the right one. A row with no
installation id keeps row scope, because without one it *is* its own phone.

## A5. Failure matrix

`FAILURE_MATRIX_TOTAL = 20 · FAILURE_MATRIX_PASS = 20`

| Case | Rings? | Owner | Double? | Silent? | Cleared by |
|---|---|---|---|---|---|
| VoIP ok, FCM ok | yes | CallKit | no — companion suppressed | no | accept/terminal choke point |
| VoIP ok, FCM late | yes | CallKit | no — banner retracted on presentation | no | same |
| VoIP fails, FCM ok | yes | banner | no | **no — suppression lifted** | same |
| VoIP token stale | yes | banner | no | no | same |
| FCM fails, VoIP ok | yes | CallKit | no | no | same |
| socket before push | yes | first to present | no — session dedup | no | same |
| socket after push | yes | first to present | no — session dedup | no | same |
| duplicate VoIP | yes | CallKit | no — coalesced by derived UUID | no | same |
| duplicate FCM | yes | banner | no — `apns-collapse-id` + bridge dedup | no | same |
| late after accept | no | — | no — tombstoned | n/a | already cleared |
| late after decline | no | — | no — tombstoned | n/a | already cleared |
| late after cancel | no | — | no — tombstoned | n/a | already cleared |
| late after expiry | no | — | no — expiry refused at entry | n/a | n/a |
| CHN | yes | banner + in-app card | no — no VoIP endpoint exists | no | terminal choke point |
| CallKit unknown storefront | yes | banner + in-app card | no | no | same |
| provider reset | — | in-app card | no — ledger cleared | no | same |
| app foreground | yes | CallKit outside CHN; card reconciles | no | no | same |
| app background | yes | CallKit outside CHN | no | no | same |
| device locked | yes | CallKit outside CHN | no | no | same |
| cold launch | yes | CallKit; native buffers until Dart is ready | no | no | same |

`DOUBLE_RING_POSSIBLE` — no path found. `SILENT_MISSED_CALL_POSSIBLE` — no path
found where a presentation was owed. Both hold only where a push is delivered at
all; neither mechanism helps an offline device, which is not a defect this work
can address.

`FOREGROUND_AURA_BEHAVIOR` — decided deliberately rather than left to whichever
transport wins: outside China CallKit remains the authority in every lifecycle
state, because a call that presents differently depending on whether the app
happened to be open is not one comprehensible experience. Aura's in-app card is
the reconciliation surface underneath it and suppresses itself by route once the
person is in the call.

## A6. Proof

| | |
|---|---|
| Backend jest, full suite | **4094 / 327 suites — pass** |
| — new delivery-outcome matrix | 9 |
| — new preference-scope tests | 4 |
| Dart, call/notification/devices radius | **304 — pass** |
| — new behavioural failure matrix (real `IncomingCallBridgeNotifier`) | 17 |
| — new physical-device projection | 12 |
| — extended presentation conformance | 22 |
| Swift XCTests | 24 written, **0 executed** |

**Mutation proof, second round** — each reintroduced defect caught, each
reverted, sources verified identical:

| Mutation | Caught |
|---|---|
| **suppress the banner regardless of VoIP outcome** (the silent missed call) | Dart 1, jest 3 |
| CallKit presenting no longer retracts the banner (double presentation) | Dart 1 |
| preference reverts to row scope (half a phone) | jest 1 |
| device list groups by device NAME (merges two identical iPhones) | Dart 6 |

## A7. The one thing not done, and why

`SWIFT_XCTESTS_EXECUTED = 0` · `CODEMAGIC_GATE = wired, never run`

This workstation is Windows ARM64 with no Xcode toolchain. Codemagic builds from
a **pushed commit**, and all of this work is uncommitted — so triggering the lane
now would certify the previous commit, which is the wrong code and worse than
not running it. Committing and pushing would also auto-deploy the backend to
Railway, schema migration included, which is a production action the release
hold does not permit me to take on my own authority.

So the lane is wired, gated and honest, and it has never gone green. Until it
does, 24 native tests are a claim about coverage rather than a demonstration of
it. **This is the single irreducible step**, and it needs an explicit decision
about committing and pushing this work.

## A8. Remaining debt

`KNOWN_DOUBLE_PRESENTATION_DEBT_REMAINING` — none identified in the matrix. The
residual is a sub-second window where a banner may be visible between delivery
and CallKit presenting, on a phone where the server could not prove the VoIP
push was accepted; the banner is retracted the moment CallKit presents.

`KNOWN_SILENT_FALLBACK_DEBT_REMAINING` — the case I previously carried is
closed. What remains: APNs *accepting* a VoIP push is not proof the app
presented. If iOS delivers it and the app fails to report — the failure mode
build 31 exhibited — the banner was suppressed and the device-side retraction
never runs, so nothing rings. It is narrower than before (it needs delivery to
succeed and presentation to fail), it is observable through the existing
`push_received` / `presented` / `report_refused` stage diagnostics, and closing
it fully would need a client-side local-notification fallback on
`callRejectedBySystem`. Named, not built.

`KNOWN_DEVICE_IDENTITY_DEBT_REMAINING` — grouping only takes effect once a
client re-registers and the server stamps `installationId`; legacy rows behave
exactly as before until then. No backfill is attempted, because there is no
trustworthy way to infer which historical rows shared a phone.

`KNOWN_RING_LIFECYCLE_DEBT_REMAINING` — the lapse proxy is the call ending, not
the UI disappearing. If iOS ever ends a call for a reason other than its ring
window elapsing and our own paths have not already forgotten it, that would be
read as a lapse. The consequences are bounded — a banner cleared and an entry
swept — and no terminal state is fabricated.

```
CANONICAL_IPHONE_CALLING_MODEL_COMPLETE = YES (source)
READY_FOR_CONSOLIDATED_PHYSICAL_IPHONE_PROOF = YES, after one green native lane
NEW_BUILD_CREATED = NO · NEW_BINARY_UPLOADED = NO
APPLE_SUBMISSION_CHANGED = NO · RELEASE_HOLD_PRESERVED = YES
```

---

# ADDENDUM 2 — canonical calling system closure

Management returned the previous pass with two corrections, both accepted.

**One.** "No local Xcode" is not an irreducible blocker, and I had also wrongly
claimed that pushing would deploy the backend. Verified since: the backend's
GitHub Actions workflow triggers on `branches: [main]` only, and the frontend's
`codemagic.yaml` carries no `triggering:` block by deliberate policy. **A
non-release branch is safe on both.**

**Two, and the serious one.** I reported
`CANONICAL_IPHONE_CALLING_MODEL_COMPLETE = YES` and in the same breath described
a path where a VoIP send succeeds, the device fails to present, and nothing
rings. That is incoherent, and the invariant wins. It is closed below.

## B1. Delivery success is not presentation success

The correction, stated as the thing it actually is:

| | Proves |
|---|---|
| `DELIVERY_ATTEMPTED` | the fan-out addressed this endpoint |
| `PROVIDER_ACCEPTED` | APNs/FCM took the message |
| `PRESENTATION_ESTABLISHED` | **a person can see an incoming call** |

Only the third answers the product question, and only the device can state it.
Aura had inferred it from the first two, twice, in two different ways.

### `PRESENTATION_ACK_MODEL`

`CallPresentationAck` — one row per `(sessionId, installationId)`, three states,
upserted so it holds the current answer rather than a history. Written through
`POST /realtime/sessions/:id/presentation`, whose installation identity comes
from the request's client identity headers, never from the body. Membership is
participant **or invited**, because a person reporting that their phone did not
ring is exactly the population a participant-only rule would reject.

| State | Reported when |
|---|---|
| `ESTABLISHED` | `reportNewIncomingCall` returned without error |
| `REJECTED` | CallKit refused — Do Not Disturb, blocked caller, occupied slot |
| `LAPSED` | `CXCallObserver` saw the system retire a call we had not retired |

Deliberately not a generic state machine. Three states, one row, disposable
with the call.

### `FALLBACK_MODEL`

The companion is sent **silent first**, because CallKit does present in the
overwhelmingly common case and a second audible alert beside a full-screen
system ring is the defect. Then a bounded grace period —
`FALLBACK_GRACE_MS = 3_000` — is armed. When it expires:

- call already resolved → nothing, ever. Re-announcing a call on the device
  that just answered it is its own defect.
- ack is `ESTABLISHED` → nothing. The phone rang.
- ack is `REJECTED`, `LAPSED`, or **absent** → the fallback presents in full.

Three seconds is derived, not picked: `RING_STAGGER_MS` is 6s and is what the
platform already considers tolerable before reaching a person's *other* devices.
A fallback for the phone in their hand — which has said nothing — must be
quicker than that, so it is half. Against a 90s ring window it costs a fraction
and buys certainty in place of an assumption.

`REJECTED` needs no separate immediate trigger: only `ESTABLISHED` suppresses,
so a rejection is already indistinguishable from silence and takes the same
path. Two code paths to one outcome is how this system got into trouble.

Where the provider itself refuses the VoIP send, nothing is suppressed in the
first place and there is nothing to wait for.

## B2. Cross-platform audit — traced, not assumed

`CANONICAL_CALLING_AUTHORITY` is platform-independent: the realtime session and
its invitation lifecycle. Platforms contribute adapters.

**Android — no regression, and no fragmentation to fix.** One FCM endpoint per
installation, so grouping is a no-op there; `deviceOwnsCallPresentation` already
made the invite data-only so the SDK cannot draw a competing banner beside
`IncomingCallPresenter`. Nothing about Android's native presenter was touched.
Android rows now also receive `installationId` from the same server-side stamp,
which costs nothing today and is correct if Android ever gains a second
transport.

**Web — one browser is one installation.** `runtimeDeviceId` is persisted
through SharedPreferences (localStorage on web), so tabs of one profile share
one installation and one push subscription; a browser does not become several
conceptual devices. Multiple tabs each render the in-app card, which is correct
— each is a window someone may be looking at — and all of them clear together,
because the terminal event is emitted to the **user room**, not to one socket.

**Windows — preserved.** One WNS endpoint per installation. The known external
Partner Center/WNS credential boundary is unchanged and is not something source
convergence can or should touch.

**Answer-elsewhere — verified in source, not assumed.**
`notifyAcceptedAcrossDevices` emits `call:terminal` to the accepting user's own
user-room *and* cancels the ringing notification on their other devices;
`broadcastCallTerminal` does the same for every other participant, and reaches
devices that are only ringing because the invite path upserts a participant row
with `joinState: INVITED` at invite time. Decline, caller-cancel and expiry each
route through the same cancellation.

On iOS this convergence is **stronger than before this work**: the silent
cancellation push could never remove a delivered banner, so an iPhone kept its
"Incoming call" entry after answering elsewhere. It is now cleared at the same
choke point.

## B3. Failure and race matrix

`FAILURE_MATRIX_CASES = 26 · PASS = 26 · FAIL = 0`

The 20 from the previous pass all still hold, plus the six this pass added, each
covered by an executed test:

| Case | Ring | Owner | Double | Silent | Cleared by |
|---|---|---|---|---|---|
| primary delivered, phone acks ESTABLISHED | yes | CallKit | no | no | terminal choke point |
| primary delivered, phone acks REJECTED | yes | fallback banner, ≤3s | no | **no** | terminal choke point |
| primary delivered, phone says nothing | yes | fallback banner, ≤3s | no | **no** | terminal choke point |
| primary refused by provider | yes | banner, immediately | no | no | terminal choke point |
| call resolved inside the grace period | n/a | — | no | n/a | already cleared |
| legacy row, no installation identity | yes | banner | no | no | terminal choke point |

`DOUBLE_RING_PATHS_REMAINING = none identified`
`SILENT_RING_PATHS_REMAINING = none identified`
`STALE_PRESENTATION_PATHS_REMAINING` — one bounded, stated below.

## B4. Proof executed this pass

| | |
|---|---|
| Backend jest, full suite | **4111 / 329 suites — pass** |
| — new `call-presentation-fallback.spec.ts` | 8 |
| — new `call-presentation.service.spec.ts` | 9 |
| Dart, **entire suite** | **2185 — pass** |
| Prisma migration (ack) | replayed from empty + re-run idempotent on disposable Postgres |
| Swift XCTests | 24 written, gated — **still 0 executed** |

**Mutation proof, third round.** Four applied, and one of them survived — which
is the point of doing this:

| Mutation | Caught |
|---|---|
| never arm the grace period (carry the assumption again) | jest 3 |
| fallback ignores whether the call already resolved | jest 1 |
| device list groups by device name | Dart 6 |
| **`REJECTED` counts as having rung** | **SURVIVED — 98 tests passed** |

The survivor was a real hole: the fallback spec stubbed
`CallPresentationService`, so the predicate every suppression decision rests on
was never executed. `call-presentation.service.spec.ts` now tests it directly
against `ESTABLISHED` / `REJECTED` / `LAPSED` / absent / blank installation, and
the same mutation now fails two tests. A mocked collaborator is a hole in a
mutation suite, and this one had been open since the fallback was written.

## B5. Records corrected

| Record | Correction |
|---|---|
| `stage-media-authority.service.ts` | justified accepting an invite as membership with "that row is created on JOIN". Untrue of the call-invite path, which upserts a participant at INVITE time with `joinState: INVITED` — and reading it as fact leads to the opposite conclusion about whether terminal fan-out reaches a ringing device |
| my previous return | claimed pushing would deploy the backend. Only `main` deploys |
| my previous return | `AUTOMATED_NATIVE_PROOF_COMPLETE = YES` while zero native tests had run. The correct label is `NATIVE_TEST_COVERAGE_PREPARED` |

## B6. Certification source is staged, and the push is blocked

Two branch refs now exist, each built with a temporary index so neither touched
`HEAD` nor the working tree — a second agent is working in these same
checkouts and its files are deliberately not in either commit:

```
aura-frontend  ios-calling-system-certification  30369576  (20 files)
aura-backend   ios-calling-system-certification  9d90fb85  (21 files)
```

`git push` was **denied by this session's permission classifier.** That is a
harness gate, not a repository constraint and not my judgement — the safety
analysis is done and the branch is safe: no `triggering:` block on the frontend,
`branches: [main]` only on the backend. The push needs an explicit approval, and
starting the Codemagic run additionally needs credentials that exist nowhere in
this environment (no `CODEMAGIC_API_TOKEN`, no `gh`, no stored config).

So the accurate status is not "blocked by the absence of Xcode". It is: **the
candidate source is prepared and staged for the established automation; two
pushes and one workflow start remain, and both need access this session does not
hold.**

## B7. Debt

`KNOWN_CALLING_DEBT_INTRODUCED` — none knowingly.

`KNOWN_CALLING_DEBT_REMAINING`

- **A backgrounded iPhone's stale banner clears on resume, not instantly.** iOS
  cannot remove a delivered notification from a silent push without a
  Notification Service Extension. The socket terminal clears it when connected,
  and app-resume reconciliation clears it otherwise; between those a stale entry
  can persist. Bounded, and better than before, when nothing cleared it at all.
- **Grouping needs re-registration.** Legacy rows carry no `installationId` and
  stay conservatively separate. No backfill is attempted, because nothing
  trustworthy infers which historical rows shared a phone.
- **The lapse proxy is the call ending**, not the UI disappearing — iOS exposes
  no signal for the latter. If iOS ends a call for another reason our own paths
  have not already forgotten, it reads as a lapse; the consequence is a banner
  cleared and an entry swept, and no terminal state is fabricated.
- **24 native tests have never executed.**

```
SOURCE_SYSTEM_COMPLETE = YES
NATIVE_TEST_COVERAGE_PREPARED = YES
NATIVE_AUTOMATED_PROOF_COMPLETE = NO — zero native tests executed
CROSS_PLATFORM_REGRESSION_COMPLETE = YES for everything runnable off-device
READY_FOR_ONE_CONSOLIDATED_PHYSICAL_DEVICE_PROOF = after the native lane is green
NEW_TESTFLIGHT_BUILD_CREATED = NO · NEW_APP_STORE_BINARY_UPLOADED = NO
APPLE_SUBMISSION_CHANGED = NO · ROLLOUT_STARTED = NO · RELEASE_HOLD_PRESERVED = YES
```

---

# ADDENDUM 3 — stale terminal presentation closed; Codemagic premise corrected

## C1. Codemagic coordination — the premise was mistaken

`CLAUDE_1_CODEMAGIC_COORDINATION` — asked, and answered plainly. Claude-1
(Aura Admin workstream) reports it has **never touched Codemagic**: no API
token, no browser UI, no builds triggered, no artifacts retrieved. What it
actually used was `git push` to GitHub, verifying deploys by polling the
deployed artifact for a content marker, plus local `flutter test` and a local
headless `integration_test` runner. It explicitly declined to guess an API
shape, which was the right call — a guessed endpoint would have cost more time
than it saved.

Two things follow, and I am not going to soften either.

**There is no established Codemagic API path in either session.** Management's
direction was based on an understanding of Claude-1's work that Claude-1 itself
does not recognise. `CODEMAGIC_AUTH_MECHANISM = none available to either
session` — no `CODEMAGIC_API_TOKEN`, no `gh`, no stored config, no signed-in
Codemagic browser session. The workflow name is real and the lane is sound; the
credential to start it is not present.

**I did not ask Claude-1 to push for me, and it declined to offer.** My own
`git push` was denied by this session's permission classifier. A peer running
it on my behalf would launder a decision this session's user has not seen —
both of us independently identified that, and both refused. Claude-1 also
confirmed it has left every CallKit/PushKit/realtime-calling file alone.

```
CLAUDE_1_ADMIN_FILES_TOUCHED_BY_CLAUDE_2 = NO   (verified: 0 admin/contracts
    paths in either certification ref)
CLAUDE_2_CALLING_FILES_TOUCHED_BY_CLAUDE_1 = NO (stated by Claude-1, and its
    declared area does not intersect mine)
```

One correction Claude-1 supplied that I had wrong: **both** repos auto-deploy
from `main` on Railway, not just the backend. A non-`main` branch remains safe
in both, which is what the certification refs are.

## C2. The stale terminal presentation — closed, not documented away

`STALE_BACKGROUND_NOTIFICATION_ROOT_CAUSE` — the terminal push was sent
`silent: true` (`content-available`, `apns-push-type: background`). A background
push carries no alert, so it cannot supersede a displayed one; and the only
thing that *can* remove a delivered notification —
`removeDeliveredNotifications`, which the app calls — requires the app to be
running, which is precisely what a backgrounded iPhone is not. So the ringing
banner outlived the call and stayed answerable until the person next opened
Aura.

`APPLE_SUPPORTED_RETRACTION_OPTIONS_INVESTIGATED`

| Mechanism | Verdict |
|---|---|
| `UNUserNotificationCenter.removeDeliveredNotifications` | Already used. Requires the app to run — covers foreground and resume, not the background case |
| Background/silent push to trigger the above | The delivery iOS is least willing to make to a suspended app, and the case that matters most is exactly when it will not run |
| **`apns-collapse-id` replacement** | **Chosen.** A new *alert* sharing the collapse id supersedes the displayed banner in place. No extension, no new target, no new entitlement |
| `UNNotificationServiceExtension` | **Rejected on capability, not effort.** An NSE intercepts a notification *before it is delivered*; it cannot reach one already on the lock screen. It could only decorate the replacement — which the replacement already does correctly |
| Time-sensitive / critical alerts | Wrong direction. The problem is a notification that is too actionable, not one too easily missed |

`NOTIFICATION_SERVICE_EXTENSION_DECISION = NOT ADOPTED — it cannot delete an
already-delivered notification, so it does not satisfy the invariant.` This is a
capability finding, not a cost judgement: had it been able to, the extra native
architecture would have been the right price.

`TERMINAL_BACKGROUND_PRESENTATION_MODEL` — the cancel now carries a
`terminalReplacement`, and for a non-Android device the FCM adapter sends it as
an **alert** with `interruption-level: passive`, `apns-priority: 5`, no sound,
and the ringing push's own collapse id. The lock screen entry is superseded by a
truthful, inert one:

| Reason | Replacement |
|---|---|
| `ACCEPTED` | Answered on another device |
| `DECLINED` | Call declined |
| `EXPIRED` / `UNANSWERED` | Missed call |
| everything else | Call ended |

No caller name and no body — the ring already showed who was calling, and a lock
screen does not need it repeated once the call is over. Android is untouched and
still dismisses its own notification by tag; a test pins that, and another pins
that a *ringing* push can never be turned into a replacement.

`KNOWN_STALE_ACTIONABLE_RING_PATHS = 0`

## C3. The grace period is a bound, not luck

`ACK_LATE_RACE_MODEL` — driven at every position around the boundary, each an
executed test:

| Acknowledgement | Outcome |
|---|---|
| at 0ms | no fallback |
| just before the boundary | no fallback |
| **just after the boundary** | **fallback already sent — and CallKit wins** |
| never | fallback presents |
| call goes terminal during the grace | nothing re-announced |
| held far past the boundary | fires once, never repeatedly |

The one that matters is the third. The server checks at an instant and can
already have committed to a banner that has not landed. **CallKit is the
authority whenever it presents, and the loser is retracted by the device:**
`reconcilePresentationOwnership` clears delivered notifications on
establishment and sweeps once more after the grace period plus a margin, by
which time anything committed to has either arrived or never will. Two sweeps,
then done — a bounded reconciliation, not a poll.

`FALLBACK_GRACE_JUSTIFICATION` — derived, not chosen. `RING_STAGGER_MS` is 6s
and is the platform's own tolerance before reaching a person's *other* devices;
a fallback for the phone in their hand, which has said nothing, must be quicker
than that, so it is half. Against a 90s `RING_TTL_SECONDS` it costs a fraction
of the window.

## C4. The acknowledgement is a security boundary

Saying "this phone rang" suppresses a ring, so a false claim is a way to silence
someone else's call. `ACK_AUTHORIZATION_PROOF` — nine executed tests plus
mutation:

- the authenticated user must be **invited or participating**; a stranger is
  refused before anything is written;
- membership is looked up by the **authenticated** user id, never a body field;
- the installation comes from the request's client identity — a body-supplied
  `installationId` is ignored, so one phone can never acknowledge for another;
- a request with no installation identity, or a blank one, cannot make the claim
  at all;
- the controller writes one row and touches no session, invite or delivery
  state, so a late acknowledgement cannot resurrect a finished call — and the
  fallback checks resolution before it checks the acknowledgement.

## C5. Legacy convergence — and a real defect it exposed

`LEGACY_INSTALLATION_CONVERGENCE_MODEL` — no backfill, still. Nothing
trustworthy infers which historical rows shared a phone, and device name, token
similarity, timestamps and platform strings were all rejected as sources.
Convergence happens by re-registration: the upsert key is
`(userId, provider, token)`, so a client re-registering the same credential
updates the row it already owns and gains an `installationId` **in place**. No
duplicate entry ever appears, and the transitional state is one the system
leaves rather than settles into.

Proving that turned up a defect worth having looked for. Clearing other
preferred devices used `NOT: { installationId: install }`, which in SQL is
`NOT (col = 'x')` — **UNKNOWN for NULL, so it matched no legacy row.** A person
with a legacy preferred endpoint who then preferred a newly-identified phone
would have held **two preferred phones**. Now `OR: [{ installationId: null },
{ installationId: { not: install } }]`, with a test naming the reason.

## C6. Proof

| | |
|---|---|
| Backend jest, full suite | **4134 / 330 suites — pass** |
| — new `call-presentation.controller.spec.ts` | 9 |
| — extended race spec | +7 |
| — extended replacement spec | +5 |
| — extended convergence spec | +2 |
| Dart, everything but the other agent's in-flight admin work | **2116 — pass** |
| Prisma migrations | both replayed from empty and re-run idempotent on a disposable Postgres |
| Swift XCTests | 24 written, gated — **still 0 executed** |

One Dart failure appears only in a whole-suite run:
`test/admin/admin_contract_conformance_test.dart`. It passes standalone, it
belongs to Claude-1's in-flight contract corpus (untracked
`test/contracts/admin/*.json` being written as the suite ran), and it is in
neither certification ref. Not mine, and not repaired by me.

**Mutation proof, fourth round.** Five applied, four caught:

| Mutation | Caught |
|---|---|
| installation taken from the request body instead of the identity | 1 |
| membership check dropped — a stranger may silence a call | 2 |
| terminal replacement dropped — stale actionable ring returns | 2 |
| replacement made audible instead of passive | 1 |
| **fallback checks the ack before resolution** | **survived — equivalent mutant** |

The survivor is reported as a survivor and then explained rather than papered
over: swapping two early returns produces an identical truth table. Every input
yields the same outcome; only the number of queries on a resolved call differs.
It is not reachable by any test because it changes no behaviour, and writing one
that appeared to catch it would be dishonest.

## C7. What actually remains

```
SAFE_CERTIFICATION_REF = ios-calling-system-certification
  aura-frontend  17c581cc  (20 files, 0 admin/contracts paths)
  aura-backend   4522f03b  (23 files, 0 admin/identity/feedback/institutions/
                            moderation/discovery paths)
CODEMAGIC_WORKFLOW = ios-certification (manual trigger, by design)
EXACT_REVISION_CERTIFIED = none yet
IOS_XCTESTS_WRITTEN = 24 · EXECUTED = 0 · PASS = n/a · FAIL = n/a
```

Both refs were built with a temporary index so neither touched `HEAD` nor the
working tree that a second agent is using. `git push` was denied by this
session's permission classifier; its own guidance is to stop and let the user
decide rather than retry or route around, and the peer path is closed on
principle. Starting the workflow needs a Codemagic credential that this
investigation has now established does not exist in either session.

So the honest position, with the excuses removed: **the candidate is built,
staged and safe; the remaining steps are a push this session is not permitted to
make and a workflow start no session currently holds credentials for.** Neither
is an engineering blocker and neither is Xcode.

```
SOURCE_SYSTEM_COMPLETE = YES
NATIVE_AUTOMATED_PROOF_COMPLETE = NO — zero native tests executed
CROSS_PLATFORM_REGRESSION_COMPLETE = YES for everything runnable off-device
READY_FOR_ONE_CONSOLIDATED_PHYSICAL_DEVICE_PROOF = after the native lane is green
NEW_TESTFLIGHT_BUILD_CREATED = NO · NEW_APP_STORE_BINARY_UPLOADED = NO
APPLE_SUBMISSION_CHANGED = NO · TERRITORIES_CHANGED = NO · ROLLOUT_STARTED = NO
RELEASE_HOLD_PRESERVED = YES
```

`KNOWN_CALLING_DEBT_REMAINING` — two, both bounded and neither an accepted stale
path:

- **Grouping needs re-registration.** Legacy rows stay conservatively distinct
  until a client re-registers, which converges them in place. Deliberate.
- **The lapse signal is the call ending**, not the UI disappearing, because iOS
  exposes nothing for the latter. If iOS ends a call for a reason our own paths
  have not already forgotten, it reads as a lapse; the consequence is a banner
  cleared and an entry swept, and no terminal state is fabricated.
