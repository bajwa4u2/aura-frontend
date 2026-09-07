# Reply sent — Guideline 5, China mainland CallKit

STATUS: **SENT** 2026-09-07, on submission `472dba81-4065-4648-8a29-12ff48549ce4`
(Aura iOS 1.4.2 (37)). No binary uploaded; no build 38; no resubmission.

`APP_REVIEW = WAITING FOR APPLE.` Not PASS. Apple has not cleared it.

## What Apple asked, verbatim

> Recently, the Chinese Ministry of Industry and Information Technology (MIIT)
> requested that CallKit functionality be deactivated in all apps available on
> the China App Store. During our review, we found that the app currently
> includes CallKit functionality and has China listed as an available territory
> in App Store Connect.
>
> If you have already ensured that CallKit functionality is not active in China,
> you may reply to this message in App Store Connect to confirm.

Their finding is *presence*; the remedy they offer is confirming *non-activation*.
The reply therefore addresses both, and separates them.

## What was sent, verbatim

> Hello, and thank you for the guidance.
>
> We confirm that CallKit functionality is not active in mainland China in the
> build under review, 1.4.2 (37).
>
> Aura determines this from the App Store storefront, not from the device's
> locale, SIM, time zone or IP address. The app's call capability starts in a
> withheld state and is enabled only once a storefront has been established and
> is permitted. When the storefront is China mainland, the app creates no
> CXProvider, performs no PushKit VoIP registration, reports no call to CallKit,
> and requests no CallKit call action.
>
> The CallKit framework is linked in the binary because the same binary serves
> territories outside mainland China, where CallKit remains available and
> unchanged. Linking it does not activate it: for the China mainland storefront
> the CallKit and VoIP push path is never initialized.
>
> Users in mainland China continue to have VoIP calling through Aura's own
> in-app calling experience and the app's standard notification path.
>
> Please let us know if you would like any further detail.

Basis: `docs/BUILD_37_CHINA_FORENSICS.md`. Every sentence is supported by build
37 (`cbdaab24`, `aura.ipa` 37), not by current `main`.

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
