# Build 37 — China storefront forensics

One question: **could the binary Apple already reviewed activate CallKit / VoIP
calling for a mainland-China App Store storefront?**

Everything below is read from build 37's own source and its own artifact. Where
current `main` differs, the difference is named and classified, never assumed.

## Identity, frozen

| | |
|---|---|
| version | Aura iOS **1.4.2 (37)** |
| commit | `cbdaab240f94012369006d5463d7a685573a1d92` |
| tree | `4af7fa411656ad722d69666ef81e44433941fedc` |
| authored | 2026-09-06 06:37:47 -0400 |
| Codemagic build | `Aura iOS — TestFlight` **#41** |
| artifact | `aura.ipa`, 37,524,465 bytes |
| bundle | `org.auraplatform.app`, CFBundleVersion 37, min iOS 15.0 |
| signing | AURA PLATFORM App Store Profile, team `4WZQA8T5MT` |

A detached worktree at `cbdaab24` was used for every source claim here.

## 1. Reachability under CHN — the call graph as a table

Cold launch, App Store storefront = `CHN`.

```
AppDelegate init
  └─ callController = CXCallController()          EAGER, unconditional   -- REACHED
didFinishLaunchingWithOptions
  └─ storefrontAuthority.start { applyCallCapability }
       └─ resolve() -> step()
            └─ CallCapabilityPolicy.capability(forStorefront: "CHN") -> .prohibited
                 └─ apply(.prohibited): prohibited != withheld -> onChange fires
                      └─ applyCallCapability(.prohibited)
                           └─ allowsCallKit == false -> retractCallKitStack()  -- REACHED
                                ├─ voipRegistry?...            nil -> no-op
                                ├─ callController.callObserver
                                │    .setDelegate(nil)                        -- REACHED
                                └─ provider?...                nil -> no-op
```

| Path | Reachable when storefront = CHN |
|---|---|
| `CXCallController()` construction | **YES** — eager stored property |
| `callController.callObserver` + `setDelegate(nil)` | **YES** — via `retractCallKitStack()` |
| `CXProvider(configuration:)` | **NO** — only inside `activateCallKitStack()` |
| `CXProviderConfiguration` | **NO** — same branch |
| `provider.setDelegate(self)` | **NO** — same branch |
| `callController.callObserver.setDelegate(self)` | **NO** — same branch |
| `PKPushRegistry(queue:)` | **NO** — same branch |
| `registry.desiredPushTypes = [.voIP]` | **NO** — same branch |
| `provider.reportCall(...)` (all sites) | **NO** — `guard callKitAllowed, let provider` |
| `callController.request(CXTransaction...)` (2 sites) | **NO** — `guard callKitAllowed` |
| `CXProviderDelegate` callbacks | **NO** — no provider exists to call them |
| `PKPushRegistryDelegate` callbacks | **NO** — no registry exists to call them |
| `"voipToken"` channel returning a token | **NO** — `result(callKitAllowed ? currentVoipToken : nil)` |
| Dart `registerVoipToken` -> backend VoIP device row | **NO** — never receives a token |
| Ordinary APNs / FCM alert path | **YES** — not gated by any of this |
| Aura in-app calling | **YES** — see section 4 |

`activateCallKitStack()` has exactly one caller: the `allowsCallKit` branch of
`applyCallCapability`. Under CHN that branch is never taken, on launch or on any
later `didBecomeActive` re-resolution — an unchanged capability emits no
transition.

## 2. The consequential facts

| | Build 37 under CHN |
|---|---|
| A. `CXProvider` instantiated | **NO** |
| B. `CXProvider` configured / delegated | **NO** |
| C. incoming calls reported through CallKit | **NO** |
| D. `CXTransaction` created or submitted | **NO** |
| E. `PKPushRegistry` registered for `.voIP` | **NO** |
| F. VoIP-push path used | **NO** — three independent stops: no registry; `didUpdatePushCredentials` guarded by `callKitAllowed`; `"voipToken"` returns nil |
| G. any other CallKit-mediated call presentation | **NO** — presentation requires a provider |
| H. ordinary APNs / in-app Aura calling | **YES**, unaffected |

## 3. The eager `CXCallController` — what it actually did

Build 37: `private let callController = CXCallController()`. Constructed at
`AppDelegate` init, before any storefront is known, on every storefront.

Under CHN it is used exactly once, inside `retractCallKitStack()`:
`callController.callObserver.setDelegate(nil, queue: nil)` — which brings a
`CXCallObserver` into existence and sets its delegate to **nil**.

What that is:

- an allocation, plus an observer whose delegate is nil and which therefore
  receives no callbacks. Setting a delegate to nil is the opposite of beginning
  to observe.
- `CXCallController` is the object through which an app *requests* call actions.
  No request is ever made under CHN — both `request(_:)` sites sit behind
  `guard callKitAllowed`.

What it is not, and cannot be:

- it cannot present a call. Presentation is `CXProvider.reportNewIncomingCall`,
  and no provider exists.
- it cannot place an entry in the system call log. That also requires a provider
  or a submitted transaction.
- it cannot receive a VoIP push. That is `PKPushRegistry`, never constructed.

The regulated behaviours all belong to `CXProvider` and `PKPushRegistry`,
neither of which build 37 brings into existence under CHN.

**Honest limit:** whether Apple's own implementation of `CXCallController.init()`
performs internal registration is not observable from our code or our binary. It
is asserted here only that it cannot produce any of A-G above, because each of
those requires an object build 37 never creates.

## 4. In-app calling survives the refusal

The native side returns `false` rather than failing, and both layers document
that `false` means *not reported*, never *not called*:

- `case "callConnected"` — `guard callKitAllowed else { result(false); return }`
- `case "startOutgoingCall"` — `guard callKitAllowed, let provider else { result(false); return }`
- Dart `reportConnected` returns `Future<void>` and discards the result.
- Dart `reportOutgoingStarted` is called exactly once, wrapped in
  `unawaited(... .catchError((_) => false))` — the value is discarded.

No product behaviour branches on it.

## 5. Release-binary forensics — build 37's own artifact

Six executable images inside `Payload/Runner.app`:

| image | links CallKit / PushKit |
|---|---|
| `Runner` | **yes** — CallKit, PushKit, libswiftCallKit |
| `Frameworks/Flutter.framework/Flutter` | no |
| `Frameworks/App.framework/App` | no |
| `Frameworks/WebRTC.framework/WebRTC` | no |
| `Frameworks/objective_c.framework/objective_c` | no |
| `PlugIns/ShareExtension.appex/ShareExtension` | no |

**There is no second CallKit or VoIP implementation.** No plugin side-door, and
the share extension links neither framework. In build 37's own iOS sources the
only files referencing CallKit are `AppDelegate.swift`,
`CallCapabilityPolicy.swift` and the tests; two further matches are comments.

Also from the shipped binary: `StorefrontAuthority` and
`StoreKitStorefrontSource` are present as real classes, `CallKitCapability` and
all three of its raw values survive, and the token `CHN` occurs **exactly once**
in the whole 3.5 MB binary.

Entitlements as signed: `aps-environment=production`, associated-domains, app
group `group.org.auraplatform.app`, `usernotifications.communication`,
`get-task-allow=false`. Background modes: `remote-notification`, `audio`,
`voip`.

`voip` is a static build-time declaration and cannot vary by storefront. It
declares a capability; it does not activate one. Under CHN build 37 performs no
VoIP registration, so no VoIP push is ever delivered.

## 6. Policy proof — the same code that passes today

`CallCapabilityPolicy.swift` changed by **+106 / -0** between build 37 and
`main`: purely additive. SHA-256 of the extracted regions:

| region | build 37 | main | |
|---|---|---|---|
| `enum CallKitCapability` | `664383003b817410` | `664383003b817410` | **identical** |
| `enum CallCapabilityPolicy` (the whole decision table) | `27956f28ea05ac55` | `27956f28ea05ac55` | **identical** |
| `StorefrontAuthority.apply(_:)` | `7e9d6043d04ef687` | `7e9d6043d04ef687` | **identical** |
| `capability` initial value (`.withheld`) | `b251f901be1898b7` | `b251f901be1898b7` | **identical** |
| `retrySchedule` values | `0.05 0.1 0.2 0.4 0.8 1.0x5 2.0x5` | same | **identical** |

So the 8 `CallCapabilityPolicyTests` and 9 `StorefrontAuthorityTests` that pass
green in certification #15, #16 and #17 exercise **byte-identical build 37
code**: CHN -> prohibited, non-CHN -> available, unknown/empty/whitespace ->
withheld, withheld before anything resolves, lookup failure leaves it withheld,
an unchanged storefront emits no transition.

`BUILD_37_CHN_POLICY = PROVEN.`

## 7. Authority acquisition — closed, bounded

Separate question: can our test environment make Apple's StoreKit API return
`CHN`? Certification #17, with the failure text the gate now extracts:

```
four storefront changes and every read still reported USA
[GBR->USA, JPN->USA, DEU->USA, FRA->USA]
```

- A fresh session set to `USA` reads as `USA` — repeatedly, through both the
  synchronous and the StoreKit 2 path.
- A fresh session set to `CHN` never reads as `CHN`, including as the first read
  of the process.
- After `USA` is established, four further territories are not observed.

`REAL_CHN_STOREFRONT_SIMULATOR_PROOF = UNAVAILABLE WITH CURRENT APPLE TEST
TOOLING.` That is a limitation of the tooling, not a product finding, and it is
not converted into "CHN product behaviour unknown" — sections 1, 2 and 6 prove
the product's response to `CHN` deterministically.

### The residual, named and parked

The four-territory result has three candidate explanations this harness cannot
separate: the product's read is stale after the first resolution; or
`SKTestSession` will not re-present a storefront within one process; or the test
holds four sessions alive at once, which is not a supported StoreKit pattern and
may leave the first session authoritative.

This concerns storefront **transitions after install**. It has no bearing on a
user already on `CHN` cold-launching build 37, where the first read is the China
read and the first read has never been in doubt. Carried as a hardening question
for the next release, not as a blocker.

## 8. Every post-build-37 change in this surface, classified

Complete. Two files, and in `AppDelegate` exactly four executable lines.

| change | classification |
|---|---|
| `callController`: `let` -> `lazy var` + `callControllerRealized` flag; teardown skips the observer when unrealized | **HARDENING** — removes inert eager construction; makes a stronger sentence true, changes none of A-G |
| `StorefrontSource.currentCountryCode()` + default extension | **ROBUSTNESS / OBSERVABILITY** — a second way to look |
| `StoreKitStorefrontSource.currentCountryCode()` via StoreKit 2 | **ROBUSTNESS** |
| `observeStorefrontUpdates()` / `Storefront.updates` task | **ROBUSTNESS** — storefront-change support |
| `refreshFromCurrentStorefront()` called from `step()` | **ROBUSTNESS** |
| fresh-session control test; gate failure-text extraction | **TESTING / OBSERVABILITY** |

**None is COMPLIANCE-AFFECTING.** No post-rejection change alters whether
`CXProvider`, `PKPushRegistry`, VoIP registration, call reporting or a CallKit
transaction happens under `CHN`. Every one of those was already NO in build 37.

## 9. Decision

**`BUILD_37_CHINA_COMPLIANCE = YES`** — for a mainland-China App Store
storefront, build 37 does not activate its CallKit / VoIP calling integration.

**`NEW_BINARY_REQUIRED = NO`** for Apple's request.

**Wording constraint that follows from section 3:** build 37 still eagerly
constructs an inert `CXCallController` and clears a call observer's delegate
during teardown. Any statement to App Review must therefore be about
*activation* — no provider, no VoIP registration, no call reported, no CallKit
action requested — and must not claim that no CallKit object is ever
constructed. That stronger sentence is true only of current `main`.
