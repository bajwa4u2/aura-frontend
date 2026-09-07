# iOS release gate

Written 2026-09-07, after App Review rejected 1.4.2 (37). The standing rule
this replaces:

> "Flutter tests are green, therefore iOS is release-ready."

That sentence was false twice in one week, and both falsifications are recorded
below rather than summarised away.

## What the gate is

The `ios-certification` Codemagic workflow, run against the release candidate
commit **before** any TestFlight submission. It boots a simulator and runs:

1. `flutter analyze`
2. the Dart suite
3. **XCTest against the `RunnerTests` target** — the native layer Dart cannot reach

Step 3 is the part that matters. Dart can pin the wiring of a native capability;
it cannot prove the capability behaves.

## What it has actually caught

**2026-09-07 — a storefront the harness would not present, and a wrong
explanation for it.** The China CallKit gate passed source review and every
policy unit test. The simulator showed no read ever returning `CHN`. The first
explanation offered — that the value is cached per process — was written up as
a finding and acted on in the product. Certification #15 disproved it: the same
process reads `USA` correctly and repeatedly. The real answer is that Apple's
storefront test authority will not present `CHN` here at all. Both the fact and
the wrong explanation were invisible to inspection and to Dart.

**2026-09-07 — four product-gate violations from a single feature.** The
operator External console introduced `toLocal()` in a data layer, a locally
written time humanizer, an eighth hub area outside the frozen register, and a
second undismissable dialog. All four were written by an author who ran only
test *subsets* locally. The full suite found them in minutes.

The lesson is the same in both: **a subset is not a suite, and a suite is not a
platform.**

## Coverage today

| Area | Proven by | State |
|---|---|---|
| Call capability policy — CHN / non-CHN / unknown | XCTest, 8 cases | PASS |
| Storefront authority — transitions, idempotence, withdrawal | XCTest, 9 cases | PASS |
| Call notification matching | XCTest, 6 cases | PASS |
| A storefront change observed through the production read | XCTest, USA → JPN control | PASS |
| Real `CHN` storefront read via `SKTestSession` | XCTest | **NOT AVAILABLE** in this environment — see below |
| Auth entry at iPad geometry | Dart widget tests | PASS (geometry only) |
| Public header entry affordance | Dart widget tests | PASS |
| Product gates (drift, conformance, modal exit) | Dart | PASS |

## What this gate structurally cannot prove

Recorded so nobody mistakes a green run for release readiness:

- **Physical device behaviour.** A simulator is not an iPad. Real touch, real
  Mail, real universal-link return, real StoreKit storefront and real network
  conditions are all out of reach.
- **The App Review journey.** Apple reviewed on an iPad Air 11-inch (M3),
  iPadOS 26.6.1, and reported a sign-in symptom this gate does not reproduce.
- **The distributed artifact.** The gate builds from source. It does not
  exercise the signed `.ipa` that Apple actually receives.

Closing those needs remote real-device hardware. As of today BrowserStack has no
session available and the AWS account is not activated for service use, so both
paths are blocked on a commercial decision rather than on engineering.

## The question this gate raised, and answered

Certification **#15** (commit `f5d0bb8`) answered it. Two explanations had been
live:

- **A** — the storefront value is cached per process, and Aura has a real
  defect: a person moving into the China storefront would keep CallKit until
  restart.
- **B** — `SKTestSession` cannot drive a `CHN` storefront in this environment,
  and Aura has no defect this harness can see.

**The answer is B, and A is disproven.** One process, storefronts driven by
`SKTestSession`, in execution order:

| storefront set | read path | observed |
|---|---|---|
| CHN (first read of the process) | both | not CHN |
| USA | synchronous | **USA** |
| CHN | synchronous | not CHN |
| USA | synchronous | **USA** |
| USA then CHN | StoreKit 2 | **USA**, then not CHN |

USA was read correctly, repeatedly, through both read paths, in a process where
CHN had already been set first. A value cached for the process could not have
tracked USA like that. What this environment does is present every storefront
asked of it **except China mainland**.

That distinction was worth nothing while it rested on inference, so the test
that used to assert the China read now runs a **control** first: it changes the
storefront to a third, non-China territory and ASSERTS the read follows it.
The control is not skippable. Only with it passing does an absent `CHN` get
recorded as an environment limit rather than a failure — so there is no path
that turns a real staleness defect into a skip.

### What this cost, and what it is worth saying about it

The StoreKit 2 read was added to `main` on the strength of explanation A, stated
at the time as a proven finding. It was not proven, and #15 disproves it. The
code that acted on that reason now records the retraction in place rather than
replacing the reason with a better-sounding one. The read itself stays: a second
independent observation path, plus `Storefront.updates`, is a real improvement
on asking once. It is just not a fix for a defect anyone has demonstrated.

### Standing classification

| Claim | State |
|---|---|
| Storefront-derived policy (CHN / non-CHN / unknown) | **PROVEN** |
| Unknown storefront fails closed to prohibited | **PROVEN** |
| Authority transitions, idempotence, withdrawal | **PROVEN** |
| A storefront change is observed through the production read | **PROVEN** (USA → JPN control) |
| CallKit/PushKit construction boundary | **STATICALLY PROVEN**, source and shipped binary |
| Real CHN storefront runtime read | **NOT AVAILABLE IN THIS TEST ENVIRONMENT** |

The last row is a limit of Apple's own simulator tooling. It is not a licence to
claim the China behaviour was tested on a China storefront — it was not, and no
message to App Review may say otherwise.

## Rule

Run this workflow, on the candidate commit, before every iOS submission. A red
gate is not a formality to override — both times it went red, it was right.
