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

**2026-09-07 — a storefront read that could not see a change.** The China
CallKit gate passed source review, and passed every policy unit test. The
simulator run showed that after one storefront had been read in a process, no
later read returned `CHN`. The cause is still open (see below), but the fact was
invisible to inspection and to Dart, and would have shipped.

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
| Real storefront read via `SKTestSession` | XCTest | **OPEN** — see below |
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

## The open question this gate raised

Under `SKTestSession`, `CHN` was never observed after a `USA` read. Two
explanations remain live:

- **A** — the storefront value is cached per process, and Aura has a real defect:
  a person moving into the China storefront would keep CallKit until restart.
- **B** — `SKTestSession` cannot drive a `CHN` storefront in this environment,
  and Aura has no defect this harness can see.

A test named to sort first in the suite makes `CHN` the first storefront the
process reads, which distinguishes them. Until it runs, **the China storefront
read is unproven on a simulator, and no claim about it should be made to App
Review.**

## Rule

Run this workflow, on the candidate commit, before every iOS submission. A red
gate is not a formality to override — both times it went red, it was right.
