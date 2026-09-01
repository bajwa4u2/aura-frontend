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

**CORRECTED 2026-08-31.** This said the choice followed from a 13.0 deployment
target. It does not: the real floor is **15.0**. `project.pbxproj` claimed 13.0,
but the Flutter toolchain raises it and rewrites the project files on every
build — the CI log reads "Updating minimum iOS deployment target to 15.0.
Upgrading project.pbxproj / AppFrameworkInfo.plist / Podfile" — so StoreKit 2's
`Storefront.current` WOULD have been reachable.

StoreKit 1 is kept, for the reason that actually holds rather than the one first
given: `SKPaymentQueue.storefront` is synchronous, needs no `@available` guard
and no Swift concurrency, and this value is read on the launch path where a
legally consequential gate must resolve without awaiting anything. An async hop
in a jurisdiction check would widen the `withheld` window that costs rings.

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
exists without Swift concurrency.

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

---

# ADDENDUM 8 — the gate re-run green, the lane repaired, and every remaining failure placed

## H1. The corrected gate, run three times

```
6a9622e1 (aadc63b)   XCODE_BUILD PASS   executed=24 passed=24 failed=0 rc=0   NATIVE VERDICT=PASSED
6a96268b (603aad3)   XCODE_BUILD PASS   executed=24 passed=24 failed=0 rc=0   NATIVE VERDICT=PASSED
6a963328 (47d3d78)   XCODE_BUILD PASS   executed=24 passed=24 failed=0 rc=0   NATIVE VERDICT=PASSED
```

Read from the lane's own manifest each time, never inferred from a previous run.
Every trigger was verified field-by-field in the DOM first; the dialog defaulted
to `main` + *Aura iOS — TestFlight* on all three occasions, and once also offered
a third option silently pinned to the previous commit.

## H2. A second lane defect: booted is not the same fact as visible

Build `6a9622e1` passed all 24 native tests and then reported `NO_COVERAGE` for
every integration suite. The suites were not at fault. `flutter test -d $UDID`
answered *"No supported devices found"* and listed only macOS and Chrome —
**Flutter could see no iOS simulator at all** — because the XCTests had run on
*"Clone 1 of iPhone …"*, the clone Xcode makes for testing, and the boot
performed two steps earlier was no longer in force.

The step now re-asserts the boot and waits for Flutter to admit the device
exists, failing once and loudly with both device lists if it never does. The
distinction matters more than the repair: the previous output read like sixteen
broken suites when the truth was one absent device.

## H3. The same false-green family, found in my own tests

Seven seams in `ios_incoming_call_presentation_test.dart` assert against the
**backend repository** through a hardcoded sibling path, guarded by a bare
`return` when absent. In any client-only checkout — CI included — that reported
them **PASSED while asserting nothing**. It is the coverage counter's failure
again in a different costume: a gate that cannot distinguish "did not run" from
"verified".

The pair is now resolved deterministically — `AURA_BACKEND_ROOT`, then the
worktree pairing with an isolated client checkout, then the ordinary sibling —
and never by searching for a directory whose contents match, since a resolver
that shops for a passing tree can always satisfy itself. An unresolved pair calls
`markTestSkipped` with a reason beginning `SKIPPED, NOT PASSED`. Mutation-proven:
forcing the resolver to null converts **8 silent passes into 8 reported skips**.

`FALSE_GREEN_FAMILY_AUDIT` — 11 further bare-return sites exist across
`integration_test`. **None is in the calling path.** Every calling suite
(`relay_certification_test` and all six `sfu_*`) already calls `markTestSkipped`
and therefore reports `NO_COVERAGE` honestly; `av_certification_test` has no
conditional gate at all. The remaining 11 sit in Meetings (protected),
create/landing, institution-return, a legitimate platform gate in media, and the
Android AV suite. Left alone deliberately: the family is closed where it can
affect this certification, and closing it elsewhere would be an unbounded
rewrite of another workstream's tests.

## H4. Three stale-base catches, in three different directions

Isolation caught what discipline had not, three times, and each failure would
have been silent:

| Candidate | What merging it would have done |
|---|---|
| frontend `b298d2a` | deleted `lib/core/discovery/`, the arrival privacy test and the router change |
| backend `3af37fa` | removed `DiscoveryArrival` and its migration |
| frontend `603aad3` | **resurrected** the discovery files the other workstream had just deliberately deleted |
| backend `264f552` | reverted seven commits, including the fix admitting the public arrival route to the fail-closed inventory |

Final candidates, both rebuilt on current `main` and verified path-by-path:

```
FRONTEND_REVISION = 47d3d78   10 owned paths   UNEXPECTED = 0   ADMIN/DISCOVERY = 0
BACKEND_REVISION  = 4b175af   23 owned paths   UNEXPECTED = 0   ADMIN/DISCOVERY = 0
CROSS_AGENT_MUTABLE_PATH_OVERLAP = 0
```

The check before every certification is not ceremony. It has now caught a
different silent revert on three separate occasions inside one workstream.

## H5. Where each remaining failure actually belongs

The lane's own record settles most of it. `docs/2026-08-27-ios-certification-lane.md`
already documents build **#7** (`2ed6f94`, 2026-08-29 — before this workstream
existed) with an identical outcome:

```
FAIL  relay_certification_test   4 executed, 2 passed, 2 FAILED
FAIL  sfu_certification_test     1 executed, 1 FAILED
NO_COVERAGE  the five sfu_* suites
RESULT: failures=1 no_coverage=1  →  VERDICT=FAILED
```

**relay / SFU — PRE-EXISTING, and not evidence of a calling defect.** The control
plane passes: credentials issue, and the set carries TURN/TLS on 443. Transport
fails on this host. The recorded analysis holds, and its central argument
re-verified: the ORDINARY-call case creates two peer connections **in one process
on one host** with no transport policy — needing no TURN, no camera and no
external network — and it fails too, so whatever stops the relay case is upstream
of Cloudflare entirely. `bf7c54a` records the same suite passing on Windows and
on a physical Pixel 9a with `localType=relay, remoteType=relay,
relayProtocol=tls`. Classification: **infrastructure limit of the CI simulator
host**, not a product defect, and not a regression from this candidate.

**The five `sfu_*` NO_COVERAGE — missing CI configuration, already documented.**
They require `AURA_SFU_CERT_EMAILS` and `AURA_SFU_CERT_PASSWORD`, which the
`aura_cert` group does not carry; only `AURA_CERT_EMAIL` / `AURA_CERT_PASSWORD`
are forwarded. Supplying them means real Aura accounts and their passwords, so it
is a founder-only step. Until then these suites correctly report `NO_COVERAGE`
rather than a false pass — the behaviour this lane exists to produce.

**Meetings §XXIV — the one genuine delta from the recorded baseline, and it is
not calling-owned.** Build #7 recorded `meetings_certification_test` at
**14/14**; build `6a96268b`, on candidate `603aad3`, reported 13/14, failing
*"no Meetings route renders a blank shell cold"*. It did not survive the base
moving forward — see H9, where the final candidate is 14/14 again — but the
causal work is kept here because the classification, not the outcome, is what
had to be right. Established causally rather than by file ownership:

- the candidate's `lib/` delta against `main` is **zero paths**, so the app code
  under test is `main`'s and never this workstream's;
- run locally on Windows the suite is **14/14**, §XXIV included — and it also
  passes with the exact router the failing build carried, so it is not that
  router change either;
- it therefore reproduces only on the iOS simulator, and its cause is **not
  established**.

Classification: **PRE-EXISTING / OTHER WORKSTREAM**, Meetings-owned, untouched
per instruction. Recorded rather than dismissed, because cold entry into a
Meetings route is adjacent to accepting a call from a terminated app. The routes
it covers are `/meetings/*` and `/meet/*`, not the call route, but the shape is
close enough to name plainly.

`GATE_DIAGNOSTIC_GAP` — the runner prints `FAILED : <test name>` without the
assertion's reason, so the failing route could not be identified from CI output
alone. Recorded and deliberately not changed here: altering the runner during a
certification would invalidate the evidence this addendum rests on.

## H6. Migration ordering, answered rather than assumed

The calling migrations are dated `20261014`/`20261015` and sort **before** a
migration already applied in production (`20261101`). Replayed on a disposable
Postgres — main's migrations first to reproduce production, then the candidate's
on top:

```
Applying 20261014000000_user_device_installation_id
Applying 20261015000000_call_presentation_ack
All migrations have been successfully applied.  ·  Database schema is up to date!
```

`_prisma_migrations` records the pair as applied *after* the later-named
discovery migration, which is exactly what production will record.
`MIGRATION_OUT_OF_ORDER_RISK = none observed`.

A separate drift — removed `User` indexes, altered `updatedAt` defaults on
`TrustedDevice` and `UserContactDiscoveryConsent` — reproduces on clean `main`
with no calling work present. Not calling-owned; recorded, not fixed here.

## H7. A production-risk finding handed to its owner

`discovery-intelligence/arrival.controller.ts` was committed with `@Public`,
absent from the reviewed inventory and carrying no recognised reason, failing the
fail-closed public-route authority suite on clean `main` — an unauthenticated
surface on the branch that auto-deploys. Reported to the owning workstream and
not touched. It has since been fixed there (`3cb3a41`), which is why the backend
candidate is now fully green.

## H8. The iOS floor

`CANONICAL_IOS_MINIMUM_VERSION = 15.0`, consistent across all five authorities.
Confirmed by the toolchain rather than by inspection: Flutter no longer emits
*"Updating minimum iOS deployment target to 15.0"*, because it no longer needs to
rewrite anything. iOS 13/14 support is not reopened by this workstream.

The correction to the earlier reasoning is repeated here so no future work
inherits the old assumption: **the floor was never 13.0 in practice**, and
StoreKit 2's `Storefront.current` would in fact have been available at 15.0.
StoreKit 1 is kept because it needs no availability guard and no async — not
because the alternative was out of reach.

## H9. The final integration run, and the Meetings delta closing itself

Build `6a963328` on candidate `47d3d78`, 28m55s:

| Verdict | Suite | Detail |
|---|---|---|
| PASS | `av_certification_test` | 8/8 |
| PASS | `create_landing_test` | 5/5 |
| PASS | `create_meeting_certification_test` | 8/8 |
| PASS | `media_certification_test` | 26/26 |
| **PASS** | **`meetings_certification_test`** | **14/14** |
| PASS | `operator_hub_certification_test` | 10/10 |
| PASS | `preferences_certification_test` | 6/6 |
| PASS | `signed_in_institution_return_test` | 2/2 |
| PASS | `trace_lifecycle_test` | 7/7 |
| FAIL | `relay_certification_test` | 4 executed, 2 passed, 2 failed |
| FAIL | `sfu_certification_test` | 1 executed, 1 failed |
| NO_COVERAGE | five `sfu_*` suites | identities not supplied |
| SKIPPED_PLATFORM | 3 suites | assert another platform's semantics |

```
RESULT: failures=1 no_coverage=1  →  VERDICT=FAILED
```

**§XXIV closed itself.** The Meetings suite is back to 14/14 on current `main`,
so the single failure seen at candidate `603aad3` did not survive the base
moving forward. It was never reproducible off the iOS simulator — Windows gave
14/14 with both the old router and the new — and it is now not reproducible on
the simulator either. Recorded as **resolved, cause never established**, which
is the honest description; it is not claimed as fixed by this workstream,
because nothing in this workstream touched it.

With that, the run reproduces the documented build-#7 baseline **exactly**.
Every remaining failure is one the lane already recorded on 2026-08-29, before
this workstream existed.

`CALLING_OWNED_INTEGRATION_FAILURES = 0`
`PREEXISTING_OTHER_WORKSTREAM_FAILURES = 0`  (the Meetings delta resolved)
`INFRASTRUCTURE_FAILURES = 3 assertions across 2 suites` — relay transport and
SFU media loopback on the CI simulator host
`NO_COVERAGE_SUITES = 5` — awaiting `AURA_SFU_CERT_EMAILS` /
`AURA_SFU_CERT_PASSWORD`, a founder-only step because it means real accounts

One correction to an earlier statement of mine: I described these integration
suites as executing "for the first time in this lane's history". That was wrong.
Build #7 ran them on 2026-08-29; what the simulator-visibility repair restored
was the ability to run them **again**, after a regression that made Flutter
unable to see the device. The baseline existed, and it is what made this
classification possible at all.

## H10. Status

```
CERTIFICATION_REF = ios-calling-system-certification
FRONTEND_REVISION = 47d3d78    BACKEND_REVISION = 4b175af
CODEMAGIC_NATIVE_BUILD_IDS = 6a9622e1, 6a96268b, 6a963328

XCODE_BUILD = PASS (x3)   DISCOVERED = 24   EXECUTED = 24   PASS = 24   FAIL = 0
CERTIFICATION_GATE_VERDICT = PASS

CANONICAL_IOS_MINIMUM_VERSION = 15.0
UNEXPECTED_FRONTEND_PATHS = 0 · UNEXPECTED_BACKEND_PATHS = 0
CROSS_AGENT_MUTABLE_PATH_OVERLAP = 0

KNOWN_DOUBLE_RING_PATHS = 0
KNOWN_SILENT_RING_PATHS = 0
KNOWN_STALE_ACTIONABLE_RING_PATHS = 0

NATIVE_AUTOMATED_PROOF_COMPLETE = YES
CALLING_AUTOMATED_CERTIFICATION_COMPLETE = YES
READY_FOR_ONE_CONSOLIDATED_PHYSICAL_DEVICE_PROOF = YES

NEW_TESTFLIGHT_BUILD_CREATED = NO · APP_STORE_BINARY_UPLOADED = NO
APPLE_SUBMISSION_CHANGED = NO · TERRITORY_CHANGED = NO · ROLLOUT_STARTED = NO
RELEASE_HOLD_PRESERVED = YES
```

The lane verdict remains `FAILED`, and that is correct behaviour rather than an
outstanding calling defect: it fails on a relay transport limit of the CI host
and on five suites whose identities are deliberately not in CI. **The calling
system and its own dependencies are green**, which is the standard this gate was
asked to hold to.

What a physical iPhone must still prove is exactly what a simulator structurally
cannot: that CallKit presents on a locked device, that a real storefront returns
`CHN` or does not, that PushKit delivers to a terminated app, and that media
traverses a real network. Those are the four things the matrix should be built
from — and nothing else, because everything else is now proven off-device.
