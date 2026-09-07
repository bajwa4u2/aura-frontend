# Draft reply — Guideline 5, China mainland CallKit

STATUS: **DRAFTED, NOT SENT.** Founder sends; nothing here goes to Apple
without that.

BEFORE SENDING: re-read Apple's 2026-09-02 message in App Store Connect and
confirm this answers the question they actually asked, in their words. This
draft was written from the established position (Guideline 5, China CallKit,
reply-only resolution offered) at a moment when App Store Connect was not
readable from this session. Answer exactly what they asked; do not add
architecture they did not ask for.

---

## The reply

> Thank you for the follow-up.
>
> We can confirm that Aura does not use CallKit in mainland China.
>
> The app determines this from the App Store storefront, not from the device's
> locale, SIM, timezone or IP address. On launch the app reads the storefront
> and holds the native calling capability in a withheld state until a
> storefront has been established and is permitted. When the storefront is
> China mainland (CHN), the app does not create a CXProvider, does not register
> for VoIP push notifications, does not report any call to CallKit, and does
> not request any CallKit call action. This is the behaviour of build 37, which
> is the build currently under review.
>
> Calling itself remains available to people in mainland China through Aura's
> own in-app call experience and the app's ordinary notification path. Outside
> mainland China the standard CallKit experience is unchanged.
>
> If it would help, we are happy to provide any further detail you need.

---

## What this reply asserts, and what backs each assertion

| Sentence | Evidence |
|---|---|
| determined from the App Store storefront | `CallCapabilityPolicy.swift` at `cbdaab24`; the only country comparison in the app |
| withheld until established and permitted | `capability: CallKitCapability = .withheld`, `allowsCallKit` true only for `.available` |
| no CXProvider on CHN | constructed only inside `activateCallKitStack()`, reached only when `allowsCallKit` |
| no VoIP registration on CHN | `PKPushRegistry` and `desiredPushTypes` in the same branch |
| no call reported to CallKit | every `provider.reportCall` site behind `guard callKitAllowed, let provider` |
| no CallKit call action requested | both `callController.request` sites behind `guard callKitAllowed` |
| this is build 37's behaviour | all of the above read from `cbdaab24`, the commit built as `aura.ipa` 37 |

## What this reply deliberately does NOT assert

- **That no CallKit object is constructed at all.** Build 37 allocates one
  `CXCallController` as a stored property at launch, on every storefront, and
  clears its observer once while tearing the stack down. Nothing is requested
  through it on CHN. Current `main` removes even that allocation, but build 37
  is what Apple has, and the reply describes build 37.
- **That we tested this on a real China storefront.** We have not. See
  `docs/IOS_RELEASE_GATE.md` for what the simulator harness can and cannot
  prove.
- **Anything about the sign-in report.** That was raised against build 36 under
  Guideline 2.1(a) and is not the current rejection. Server records show the
  reviewer authenticated successfully on build 37. If Apple raises it again,
  it is answered separately.

## If Apple asks for a new binary anyway

Then the hardening already on `main` — the lazy `CXCallController`, the
StoreKit 2 storefront read that can observe a change — ships as build 38, and
the reply's second sentence can become the stronger one. That is a better
build. It is not needed to make this reply true.
