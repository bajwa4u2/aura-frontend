# What build 37 itself does on the China mainland storefront

Written 2026-09-07, to answer one question and not a broader one:

> Does the binary Apple already reviewed truthfully support the sentence
> Apple asked us to confirm?

Everything below is read from build 37's own tree — commit `cbdaab24`,
Codemagic `Aura iOS — TestFlight` #41, artifact `aura.ipa` build 37 — not from
current `main`. Where current `main` differs, the difference is named as
POST-REJECTION HARDENING and kept separate on purpose.

## The gate is in build 37

`ios/Runner/CallCapabilityPolicy.swift` is present at `cbdaab24`. It carries
the storefront policy, the three-state capability, and the authority that
resolves it. This is not a change made after the rejection; the rejection this
file cites by submission id is the earlier one, against 1.4.0 (35).

The capability has three states, and the initial one is `withheld`:

```swift
private(set) var capability: CallKitCapability = .withheld
var allowsCallKit: Bool { self == .available }
```

CallKit is enabled by an affirmative, established, permitted storefront. Every
other condition — no App Store account, StoreKit not yet answered, a hang, an
outage — leaves the app with CallKit off. The gate fails closed.

## What is and is not constructed on CHN, in build 37

| Object | Build 37 on CHN | How it is established |
|---|---|---|
| `CXProvider` | **not constructed** | built only inside `activateCallKitStack()`, reached only when `capability.allowsCallKit` |
| `PKPushRegistry` | **not constructed** | same branch |
| VoIP registration (`desiredPushTypes = [.voIP]`) | **never performed** | same branch |
| CallKit call reporting (`provider.reportCall`) | **never performed** | every site guarded by `callKitAllowed, let provider` |
| CallKit call actions (`callController.request`) | **never performed** | both sites guarded by `callKitAllowed` |
| `CXCallController` | **constructed** | `private let callController = CXCallController()` — a stored property, built at `AppDelegate` init on every storefront |
| `callObserver.setDelegate(nil)` | **executed once** | `retractCallKitStack()` runs on the `withheld → prohibited` transition and clears the observer unconditionally |

Every CallKit *invocation* was checked individually rather than inferred from
line ranges. The two `callController.request` sites sit behind
`guard callKitAllowed`, and `callObserver.calls` sits behind
`guard callKitAllowed, let provider`.

So build 37 activates nothing. What it does do is allocate one CallKit client
object at launch, and touch its observer once while tearing the stack *down*.

## The precise claim build 37 supports

TRUE of build 37:

> Aura determines mainland-China availability from the App Store storefront,
> and when that storefront is CHN the app does not activate CallKit — no
> provider is created, no VoIP push registration is performed, no call is
> reported to CallKit, and no CallKit call action is requested.

NOT true of build 37:

> Aura constructs no CallKit object at all on the China storefront.

That second sentence is true only of current `main`, where `callController`
became `lazy` with a `callControllerRealized` flag so teardown cannot bring it
into being. The reply to App Review must assert the first sentence, and must
not drift into the second.

## Why the storefront-caching question does not change this answer

A separate open question asks whether the storefront value is cached per
process, so a person who *moves into* the China storefront might keep CallKit
until restart. That question is real, and it is what the post-rejection work
addresses.

It does not bear on the reviewer's case, or on a China-based person's ordinary
case. Build 37 reads the storefront synchronously at launch and starts from
`withheld`. For an account that is on the CHN storefront when the app launches,
the FIRST read is the China read, and the first read has never been in doubt.
Caching can only make a stale value persist; it cannot invent a permitted
storefront that was never read.

## Hardening after the rejection, listed so it is not confused with the above

- `6778f32f` — observe the platform's own storefront change signal
- `8c32ff21` — a storefront read (StoreKit 2 `Storefront.current`) that can see a change
- `0ba9d047` — `CXCallController` becomes lazy, so CHN constructs no CallKit object
- `dba419fa` — a test that asks which explanation is true, before claiming either

None of these are required to make the TRUE sentence above true of build 37.
They make a stronger sentence true of the next build.

## The shipped binary, audited

Source is not the artifact. `aura.ipa` build 37 (37,524,465 bytes) was pulled
from its own Codemagic build — `Aura iOS — TestFlight` #41 — and unpacked.

| Fact | Value |
|---|---|
| bundle id | `org.auraplatform.app` |
| version | 1.4.2 (37) |
| minimum iOS | 15.0 |
| `UIBackgroundModes` | `remote-notification`, `audio`, `voip` |
| signing profile | AURA PLATFORM App Store Profile, team `4WZQA8T5MT` |
| entitlements | `aps-environment=production`, associated-domains, app-group `group.org.auraplatform.app`, `usernotifications.communication`, `get-task-allow=false` |
| linked frameworks | CallKit, PushKit, StoreKit, AVFoundation, UserNotifications (48 dylibs total) |

Framework presence is not the consequential fact — CallKit is linked because
the app uses it everywhere it is permitted to. What the binary adds:

- `StorefrontAuthority` and `StoreKitStorefrontSource` are present as real
  classes (`_TtC6Runner19StorefrontAuthority`,
  `_TtC6Runner24StoreKitStorefrontSource`). The gate is compiled in, not only
  written down.
- `CallKitCapability` is present, and so are all three of its raw values —
  `available`, `prohibited`, `withheld`. The three-state design survived into
  the binary; it was not optimised into a boolean.
- **The token `CHN` occurs exactly once in the whole 3.5 MB binary.** That is
  the strongest single corroboration of the policy file's claim to be the only
  place in the app that names a country.

`voip` is declared in the shipped `UIBackgroundModes` on every storefront,
because a background mode is a static build-time declaration and cannot be
varied per storefront. It is a declaration of capability, not an activation:
build 37 performs no VoIP registration on CHN, so no VoIP push is ever
delivered there. Worth stating plainly in our own record because a reviewer
reading the plist alone would see `voip` and could ask.
