# Aura 1.4.3 — release certification

    version        1.4.3+38
    Windows MSIX   1.4.3.0
    scope          identity reconstruction
    branch         identity-registration (both repos)

**This release exists because the reconstructed registration contract requires
a client that can send date of birth and declared jurisdiction.** Founder
ruling, 2026-09-09: the currently released client is *replaceable distribution
state*, not a permanent architectural constraint. The contract is not weakened
for an older store binary; the binary is replaced.

---

## 1. Build number — verified, not assumed

    current  1.4.2 (37)   live on all three stores
    this     1.4.3 (38)

Build 38 is **unspent**. `docs/app-review/DRAFT_REPLY_GUIDELINE_5_CHINA.md`
records it in as many words — *"No binary uploaded; no build 38; no
resubmission"* — and Apple **accepted** that reply on 2026-09-08 against the
binary they already had:

    BUILD_37_CHINA_COMPLIANCE = YES
    NEW_BINARY_REQUIRED       = NO

38 was *contingently* earmarked there — "if Apple asks for a new binary anyway,
the hardening already on `main` … ships as build 38". Apple did not ask, so the
contingency never fired and the number was never consumed. Using 38 here keeps
that statement true rather than contradicting it: the hardening in question
(lazy `CXCallController`, StoreKit 2 storefront read, `Storefront.updates`) is
already on `main`, and `main` is an ancestor of this branch, so this build
carries it.

**OWED TO THE FOUNDER before the number is frozen:** Play Console and Partner
Center confirmation that versionCode 38 is unused. It cannot be read from this
machine — the Codemagic token lives in the founder's authenticated browser
session and store submission is founder-operated. Android 37 is confirmed
consumed; it is the build measured on the Pixel.

## 2. What is certified

All identity certification was performed on **this exact code**, from this
branch, before the version bump. The bump changes no behaviour.

| Item | Result | Evidence |
|---|---|---|
| prospective registration with DOB + jurisdiction | **PASS** | 10/10 boundary cases, isolated stack |
| US 13 / EU_EEA 16 / RoW 16 boundaries | **PASS** | day-before / birthday / day-after, each bucket |
| declared jurisdiction decides, not inferred | **PASS** | same DOB admitted under US, refused under DE |
| date of birth stays a calendar date | **PASS** | 6 stored values byte-equal; renders April 1, not March 31 |
| ineligible applicant creates NO row | **PASS** | 3 refusals, 0 rows |
| CONTINUITY users not completion-walled | **PASS** | 12/12 on a seeded legacy row, and observed on the Pixel |
| Personal Details | **PASS** | reachable, correct values, update path, missing-field prompt |
| private / public identity separation | **PASS** | tested in BOTH directions, public write proven to land |
| verification entry and three classes | **PASS** | distinct classes, submission state separate |
| secure session refresh | **PASS** | 12/12 in a real browser over HTTPS |
| navigation / back behaviour | **PASS** | Android system Back, web Back/Forward, deep link + return path |
| Android physical runtime | **PASS** | full 16-item matrix, Pixel 9a |
| Web | **PASS** | signed-out entry, registration, sign-in, all identity surfaces |
| Windows | **identity contract PASS**, **UI EVIDENCE-LIMITED** | `integration_test` 4/4 with a real sign-in; synthetic input into a Flutter desktop window is unreliable |
| iOS / iPadOS | **NOT_EXECUTED** | no macOS on this host. Structural, not incidental. |

Detailed records live in `aura-backend/docs/`:
`2026-09-09-prospective-registration-boundary-certification.md`,
`2026-09-09-android-identity-certification.md`,
`2026-09-09-web-windows-identity-certification.md`, and the three
`CLOSEOUT_*.md` records.

**Honest labels are kept.** Windows UI is not promoted to PASS by inheritance
from Web or Android, and nothing is inferred for iOS.

### iOS — what would make it certifiable

Not a defect and not a gap in the work: the build host runs Windows on ARM and
has no Xcode. iOS evidence for this release must come from the existing
Codemagic lane and, where applicable, App Store review. The identity surfaces
are platform-neutral Flutter and share the backend contract certified above,
but that is a reason to expect them to work, not evidence that they do.

## 3. Regression floors

    backend   389 suites   4855 tests   typecheck gate 1167 files / 391 specs
    client    2793 pass    1 skip       14 fail

The client's 14 failures are the exact pre-existing floor — 12 admin golden
pixel diffs at 0.03% (environmental) and 2 shell-footer assertions from
`d2c74c63`. Verified as the same 14 files and test names, not merely the same
count. **Goldens are not regenerated**: doing so would launder a rendering
difference into the repository and destroy the baseline's meaning.

## 4. Rollout — the order is not the obvious one

Registration incompatibility is **directional in both directions**, because the
backend runs `forbidNonWhitelisted: true`:

| Combination | Result |
|---|---|
| old client → new backend | 400, fields missing |
| **new client → old backend** | **400, fields forbidden** |

So this client **cannot ship ahead of the backend**. Backend and client cut over
together, and the store release is held until the backend is deployed. Full
ordering in
`aura-backend/docs/2026-09-09-identity-rollout-and-release-sequencing.md`.

## 5. Finance stays dormant

The Finance doorway and identity provider ship in this merge under the settled
fail-closed model. **No Finance authority is activated by this release.**
Becoming non-dormant takes three deliberate acts a deploy does not perform:
setting the environment configuration, creating a book, issuing a grant.
Unconfigured, the provider answers 404 and the client renders the destination
absent — asserted byte-identical to a revoked grant.

## 6. Artifacts

Store submission is founder-operated by standing doctrine. This session's role
ends at certified artifacts and instructions.

    Android   flutter build appbundle --release      → app-release.aab
    Windows   flutter build windows --release        → aura.exe / MSIX 1.4.3.0
    Web       flutter build web                      → Railway aura-frontend
    iOS       Codemagic lane, founder-triggered      → NOT built here
