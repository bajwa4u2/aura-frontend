# Draft reply — Guideline 5, China mainland CallKit

STATUS: **DRAFTED, NOT SENT.** The founder sends; nothing here goes to Apple
without that.

Basis: `docs/BUILD_37_CHINA_FORENSICS.md`. Every sentence below is supported by
build 37 (`cbdaab24`, `aura.ipa` 37) and not by current `main`.

BEFORE SENDING: re-read Apple's message in App Store Connect and confirm this
answers the question they actually asked, in their terms.

---

## The reply

> Thank you for the follow-up. We can confirm that Aura does not activate its
> CallKit and VoIP calling integration for users whose App Store storefront is
> mainland China.
>
> The app determines this from the App Store storefront, not from the device's
> locale, SIM, time zone or IP address. The calling capability starts in a
> withheld state and is enabled only once a storefront has been established and
> is permitted. When the storefront is China mainland, the app creates no
> CXProvider, performs no PushKit VoIP registration, reports no call to CallKit,
> and requests no CallKit call action. This is the behaviour of build 37, the
> build currently under review.
>
> Calling itself remains available to users in mainland China through Aura's own
> in-app calling experience and the app's ordinary notification path. Outside
> mainland China the standard CallKit experience is unchanged.
>
> Please let us know if you would like any further detail.

---

## What each sentence rests on

| Sentence | Evidence |
|---|---|
| determined from the App Store storefront | `CallCapabilityPolicy.swift` at `cbdaab24`; the token `CHN` occurs exactly once in the shipped 3.5 MB binary |
| starts withheld, enabled only by an established permitted storefront | `capability: CallKitCapability = .withheld`; `allowsCallKit` true only for `.available` |
| no CXProvider under CHN | constructed only inside `activateCallKitStack()`, whose sole caller is the `allowsCallKit` branch |
| no VoIP registration under CHN | `PKPushRegistry` and `desiredPushTypes` in that same branch; plus two further stops on the token path |
| no call reported to CallKit | every `provider.reportCall` site behind `guard callKitAllowed, let provider` |
| no CallKit action requested | both `callController.request` sites behind `guard callKitAllowed` |
| in-app calling unaffected | native returns `false`; Dart discards it at the only call site |
| this is build 37 | all of the above read from `cbdaab24` and its own artifact |

## What this reply deliberately does not say

- **Not** "no CallKit object is ever constructed." Build 37 eagerly constructs an
  inert `CXCallController` and clears a call observer's delegate during
  teardown. Neither can present a call, write to the system call log, or receive
  a VoIP push. The stronger sentence is true only of current `main`, and is not
  needed.
- **Not** anything about testing on a real China storefront. We have not done
  that.
- **Not** our debugging history, certification runs, or simulator limitations.
- **Not** anything about the earlier sign-in report. That was raised against
  build 36 under Guideline 2.1(a), is not the current rejection, and is answered
  separately if raised.

## If Apple asks for a new binary anyway

The hardening already on `main` — the lazy `CXCallController`, the StoreKit 2
storefront read, `Storefront.updates` — ships as build 38, and the first bullet
above becomes assertable. That is a better build. It is not what makes this
reply true.
