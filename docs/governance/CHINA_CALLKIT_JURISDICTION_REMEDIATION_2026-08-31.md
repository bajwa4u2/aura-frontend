# China CallKit Jurisdiction Remediation — source correction

**Date:** 2026-08-31
**Authority:** founder/management ruling of 2026-08-31 — **Option B authorized**.
China mainland stays in Aura's App Store distribution; the capability boundary
is corrected instead.
**Release hold:** ACTIVE and preserved. No build, binary, submission, rollout or
territory change was made under this instruction.
**Provider evidence:** `DISTRIBUTION_PROVIDER_STATE_2026-08-31.md`.

---

## 1. The defect being corrected

Apple rejected Aura Platform 1.4.0 (35) on 2026-08-31 under **Guideline 5 —
Legal** (`5.0.0 Legal: Preamble`), submission
`472dba81-4065-4648-8a29-12ff48549ce4`: MIIT requires CallKit be deactivated in
apps on the China App Store, and the binary shipped CallKit into a territory
list that includes China mainland.

The architectural defect, stated as management stated it: **a
jurisdiction-constrained native capability was introduced globally without a
jurisdiction-aware capability policy.** Build 35's
`didFinishLaunchingWithOptions` called `configureCallKit()` and
`registerForVoIPPushes()` unconditionally, on every device, in every territory.

## 2. What was built

### The canonical decision — `ios/Runner/CallCapabilityPolicy.swift` (new)

One file. One decision. Nothing else in the app compares a country code, and a
test enforces that.

| Type | Role |
|---|---|
| `CallKitCapability` | `available` / `prohibited` / `withheld`, with a single `allowsCallKit` property that is true only for `available` |
| `CallCapabilityPolicy` | Pure, total map from storefront code → capability. Names `CHN`, and is the only place that does |
| `StorefrontSource` | Injection seam; the production implementation reads StoreKit |
| `StorefrontAuthority` | Establishes the storefront, re-reads it on foreground, reports capability transitions |

### The gate — `ios/Runner/AppDelegate.swift`

Launch no longer builds the CallKit stack. It starts the authority and waits.

## 3. The answers management asked for

### `CANONICAL_STOREFRONT_AUTHORITY`

`SKPaymentQueue.default().storefront?.countryCode`.

This is the correct API *for this deployment target*, not merely an available
one. Aura's `IPHONEOS_DEPLOYMENT_TARGET` is **13.0**. `SKPaymentQueue.storefront`
is the App Store storefront API from iOS 13.0. StoreKit 2's `Storefront.current`
is iOS 15.0+ — above Aura's floor — so making it the authority would leave iOS 13
and 14 devices with no storefront at all, which under this policy means no
CallKit for them either. StoreKit 1 covers the whole supported range.

`SKStorefront.countryCode` is ISO 3166-1 **alpha-3**, which is why the
identifier is `CHN` and not `CN`.

**Explicitly not used, and a test forbids each of them in the iOS sources:**
`Locale.current`, `NSLocale`, `TimeZone`/`NSTimeZone`, `isoCountryCode`,
`mobileCountryCode`, `CTTelephonyNetworkInfo`, `CTCarrier`,
`preferredLanguages`, `regionCode`. Every one describes where a handset is. The
obligation attaches to the storefront the app was distributed through — a
Beijing storefront account travelling in Berlin is bound; a German account
visiting Shanghai is not.

### `CHINA_MAINLAND_IDENTIFIER`

`CallCapabilityPolicy.chinaMainlandStorefront = "CHN"`, matched
case-insensitively after trimming.

`callKitProhibitedStorefronts = ["CHN"]` — mainland only. **Hong Kong (`HKG`),
Macau (`MAC`) and Taiwan (`TWN`) are deliberately excluded**: they are separate
App Store storefronts outside MIIT's instruction, and Apple's finding names the
China App Store. This is a judgment call, it is recorded as one, and it is the
one line that changes if Apple extends the instruction.

### `CALLKIT_CAPABILITY_POLICY`

| Storefront | Capability | CallKit |
|---|---|---|
| `CHN` | `prohibited` | never active |
| any other established code | `available` | normal Aura calling capability |
| nil / empty / unresolved | `withheld` | not active |

### `UNKNOWN_STOREFRONT_POLICY`

**Unknown is treated as prohibited.** `withheld.allowsCallKit == false`.

The safety argument is structural rather than procedural: `callCapability`
**starts** at `withheld` and the stack is built only by an affirmative
transition to `available`. A StoreKit outage, an offline launch, a device with
no App Store account, a hang, or a future refactor that forgets to call
`start()` all leave the gate closed. CallKit is enabled by evidence that it is
permitted — never by absence of evidence that it is forbidden.

The cost is bounded and does not fall on calling. The first read is
**synchronous inside `didFinishLaunchingWithOptions`** — the storefront is
cached on device and needs no network round trip — so on a healthy launch the
VoIP registration is made at exactly the same point in launch as before this
policy existed. When StoreKit genuinely has not answered, an escalating retry
schedule (`0.05, 0.1, 0.2, 0.4, 0.8, 1.0×5, 2.0×5` seconds), re-armed on every
foreground, closes the window in milliseconds rather than a second. And while
withheld, Aura calling continues through the in-app path (§4), which a ringing
call reaches over the separate FCM device row that none of this gates.

That redundancy is load-bearing, and it is why the duplicate-ring collision it
causes was deliberately left in place — see
`IOS_CALL_PUSH_COLLISION_REGISTER_2026-08-31.md` (C1).

### `STOREFRONT_CHANGE_POLICY`

Re-read on `UIApplication.didBecomeActiveNotification`, and re-retried from
there. Changing an Apple Account's country or region happens in Settings or the
App Store, so the app is always backgrounded across the change and foregrounded
after it — `didBecomeActive` catches every real transition using only API that
exists on the 13.0 floor.

**Never persisted.** No `UserDefaults`, no Keychain, no backend write, no
attachment to a person. It is a runtime distribution fact re-established from
StoreKit on every launch; a test asserts the absence of storage.

## 4. The gates, path by path

`CALLKIT_CREATION_GATE` — `activateCallKitStack()` is the sole construction site
for both `CXProvider` and `PKPushRegistry`, is idempotent, and is reached only
through `applyCallCapability`'s `if capability.allowsCallKit`. Tests assert
there is exactly one `CXProvider(configuration` site and exactly one
`desiredPushTypes = [.voIP]` site in the file, so there is exactly one thing to
gate.

`CALLKIT_INCOMING_GATE` — `didReceiveIncomingPushWith` guards on
`callKitAllowed` **before** `reportNewIncomingCall`; a test asserts the gate's
index precedes the report's.

`CALLKIT_OUTGOING_GATE` — Aura has no outgoing-call CallKit path
(`CXStartCallAction` is absent). The one Dart-driven CallKit *invocation* is
`callController.request(CXAnswerCallAction)` in `callConnected`, and it is
gated. `endCall`, `endStaleCalls` and `voipToken` are gated too.

### `PUSHKIT_CHINA_BEHAVIOR` — the gate is at registration, not at reporting

**This is the load-bearing decision.** Registering for VoIP pushes *obliges* the
app to report every one of them to CallKit; iOS terminates an app that does not.
Gating only the report would leave the app receiving pushes it was forbidden to
answer — terminated, or in breach.

So in a prohibited or withheld jurisdiction Aura **never registers for VoIP
pushes**. No token is requested, Dart registers no VoIP device row, the backend
therefore never sends a VoIP push to that device, and the obligation never
arises. The prohibition is satisfied upstream of the conflict rather than
inside it.

Retraction order matters and is tested: `desiredPushTypes = []` first — which
makes iOS invalidate the token, firing `didInvalidatePushTokenFor`, which tells
Dart to deactivate the backend's VoIP device row — and only then is the provider
invalidated. Reversing it would leave a window with a push and nothing able to
report it. `didInvalidatePushTokenFor` is deliberately **not** gated, or the
server would keep pushing VoIP to a device that can no longer report.

A residual guard remains in the push handler for the in-flight case. It does not
report to CallKit; it hands the call to the in-app surface and completes. That
trade is deliberate and recorded: a terminated process is a recoverable local
failure affecting one call, an active CallKit sheet in China is the breach.

### `CHINA_IN_APP_CALL_BEHAVIOR` — verified, not assumed

Aura calling continues in China. Both delivery legs already exist and were
checked in source:

- **App running:** `incomingCallBridgeProvider` subscribes to the correspondence
  and `/realtime` sockets; `call:incoming` raises the in-app ring card. The
  native prohibited path also emits `incomingCall` into that same bridge.
- **App backgrounded or terminated:** iOS registers an **ordinary APNs/FCM
  device row, separate from the VoIP row** (`DeviceService._fcmPayload`, with
  the bounded `_awaitApnsToken()` wait). `NotificationBridge._onFcmForeground`,
  `_onFcmTap` and `getInitialMessage` all funnel into the same
  `incomingCallBridgeProvider.addIncoming`.

**No broken path was found, so none needed finishing.** The honest limitation:
without CallKit a locked iPhone in China shows a notification banner rather than
a full-screen system ring, and the call is opened by tapping rather than
answered from the lock screen. That is inherent to the requirement and is what
Apple describes — VoIP calling remains allowed, without CallKit's look and feel.

## 5. Audit and tests

`CHINA_CALLKIT_PATHS_AUDITED` — every native path that could activate or invoke
CallKit: `CXProvider` creation; `CXCallController`; provider configuration;
incoming-call reporting; outgoing (none exists); `PKPushRegistry` registration,
token issue, token invalidation and push receipt; the accept path
(`callConnected` → `CXAnswerCallAction`); end (`endCall`, `CXEndCallAction`);
terminal teardown (`endStaleCalls`, `retractCallKitStack`); cold launch
(`didFinishLaunchingWithOptions`); background/locked receipt; the `providerDidReset`
restoration path; and every Flutter bridge method
(`ready`, `endCall`, `callConnected`, `voipToken`, plus the new read-only
`callCapability`).

`CALLKIT_BYPASS_PATHS_FOUND` — four that a `configureCallKit()`-only gate would
have missed: `callController.request(CXAnswerCallAction)` in `callConnected`;
`provider.reportCall(endedAt:)` in `endCall`; `callObserver.calls` plus
`reportCall` in `endStaleCalls`; and a VoIP token arriving in
`didUpdate pushCredentials` from a registration already in flight across a
transition, which would have re-armed the delivery just disarmed.

`CALLKIT_BYPASS_PATHS_REPAIRED` — all four.

### Tests

**`test/release/china_callkit_jurisdiction_gate_test.dart` — 20 tests, all
passing, and they run in existing CI (`flutter test`).** Source-conformance in
the established idiom of `call_accept_is_not_termination_test.dart`: the gate
lives in Swift and cannot be exercised from Dart, but the *wiring* is what a
future reconstruction would remove by accident, so the wiring is what is pinned.

Proven to bite. Three mutations were applied and each was caught, then reverted:

1. removing `callKitAllowed` from the VoIP push handler → **failed**
2. `allowsCallKit` widened to `self != .prohibited`, so withheld would permit → **failed**
3. `activateCallKitStack()` restored to the launch path — a faithful reproduction of the build-35 defect → **failed**

Restored sources verified byte-identical; the suite is green again.

**`ios/RunnerTests/RunnerTests.swift` — 17 behavioural tests** over the policy
and the authority, covering the full matrix management specified: China mainland
prohibited (and case/whitespace variants); USA and seven other storefronts
including `HKG`/`MAC`/`TWN` permitted; unknown and lookup-failure withheld;
transition into China; transition out of China recovering; storefront becoming
unresolvable withdrawing the capability; unchanged storefront producing no
rebuild; `start()` idempotent.

> **CORRECTED 2026-08-31.** This section first said "19 behavioural tests".
> The actual count is 17 (8 policy + 9 authority); 19 was a miscount, not a
> removal. Six more were added later the same day for notification cleanup,
> bringing `RunnerTests.swift` to 23 substantive tests plus Flutter's
> `testExample` boilerplate.
>
> **Also corrected:** this said "No CI workflow currently invokes the iOS test
> target; wiring one is a separate, unauthorized change." It was subsequently
> authorized and done — the `ios-certification` workflow now runs
> `-only-testing:RunnerTests` and fails the build both on XCTest failure and on
> zero executed tests. See `IOS_INCOMING_CALL_SYSTEM_CLOSURE_2026-08-31.md`.
> They still do not execute on this Windows workstation.

`ios/Runner.xcodeproj/project.pbxproj` gained the four standard entries for the
new source file (build file, file reference, group child, Sources phase).
Balanced-delimiter check clean, and `ios_firebase_config_is_bundled_test.dart` —
which parses the same project file — still passes.

## 6. Build status

`BUILD_35_STATUS` — **Rejected and noncompliant** for the China CallKit
requirement. Not resubmitted. The whole 1.4.0 line, builds 26–35, carries the
same unconditional CallKit; the correction is not in any uploaded binary.

`TESTFLIGHT_26_STATUS` — 1.4.0 (26), **Waiting for Review** since 2026-08-29
18:28, submitted by API user `RKJH5W6GLQ` (Codemagic), group *Aura Platform
Group*, **1 invite, 0 installs, 0 sessions, 0 crashes, 0 feedback**. Builds
27–35 are all *Ready to Submit* and carry the actual testing.

**It can harmlessly remain, and it was left alone.** TestFlight beta review
governs TestFlight distribution, not App Store territory availability; the
rejection stands against the App Store version, not this build. Build 26 is nine
builds stale with nobody on it. Cancelling would be a distribution action with
no benefit against a standing instruction not to remove distribution casually.
If Apple raises the same CallKit point in beta review it produces a beta-review
note that affects neither the live 1.3.0 nor the 1.4.0 store submission.

## 7. The App Review response — PREPARED, NOT SENT

`APPLE_REVIEW_RESPONSE_SENT = NO`. It asserts things that are true only of a
binary that does not yet exist, so it must not be sent until that binary is
built and its submission is authorized. `‹BUILD›` is the placeholder.

> Hello,
>
> Thank you for the review of Aura Platform 1.4.0 and for identifying the
> CallKit issue under Guideline 5 — Legal.
>
> Your finding on build 35 was correct: that build configured CallKit at launch
> unconditionally, with no jurisdiction check, while China mainland was an
> available territory.
>
> Build ‹BUILD› changes that. CallKit is now gated on the App Store storefront:
>
> • The storefront is read from StoreKit — `SKPaymentQueue.default().storefront`
>   — which identifies the App Store storefront the app was distributed through.
>   We do not use device locale, SIM country, timezone or IP address for this.
> • When the storefront is China mainland (CHN), the app creates no CXProvider
>   and does not register for PushKit VoIP pushes at all. Because no VoIP token
>   is requested, our server never sends a VoIP push to that device, so no call
>   is ever reported to CallKit.
> • The app starts with CallKit disabled and enables it only after affirmatively
>   resolving a permitted storefront. If the storefront cannot be resolved,
>   CallKit stays disabled.
> • If a user changes their Apple Account region into China on an installed app,
>   the app detects this the next time it becomes active, deregisters from VoIP
>   pushes and tears down the CallKit provider.
>
> Aura's own calling continues to work in China through the app's in-app
> incoming-call interface, delivered by our standard APNs alert notification and
> our realtime connection. Only the CallKit system integration is removed, as
> your message describes.
>
> We are keeping China mainland as an available territory.
>
> Please let us know if you would like any further detail.

## 8. What was not touched

Correspondence, realtime-session authority, invitation semantics and unrelated
calling UX are unchanged. The established Aura calling authorities and all prior
iOS calling work are preserved — the `voip` `UIBackgroundMode` stays declared,
because permitted storefronts genuinely still use PushKit and CallKit, and a
test pins that too. No Dart source was modified: the native retraction reuses
the `voipTokenInvalidated` signal Dart already handles.

```
NEW_BUILD_CREATED = NO · NEW_BINARY_UPLOADED = NO · NEW_SUBMISSION_CREATED = NO
APP_STORE_TERRITORIES_CHANGED = NO · ROLLOUT_STARTED = NO
CHINA_DISTRIBUTION_PRESERVED = YES · RELEASE_HOLD_PRESERVED = YES
```

`NEXT_RELEASE_CONSEQUENCE` — the correction exists only in source. Clearing the
rejection requires a new iOS build (≥ 36) carrying it, uploaded and submitted
against 1.4.0, with the §7 response attached. That needs the release hold
lifted. Before that build ships, two things should be done that this instruction
did not authorize: run the iOS test target so the 19 Swift tests execute, and
exercise a real device or simulator on a China-mainland storefront account to
confirm behaviour, since no unit test can prove CallKit did not appear.
