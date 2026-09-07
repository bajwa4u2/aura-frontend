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

**2026-09-07 — a storefront the harness would not present, and two wrong
explanations for it.** The China CallKit gate passed source review and every
policy unit test. The simulator showed no read ever returning `CHN`. Two
explanations were then offered in turn, each stated too strongly, and each
corrected by the next run: see below. The fact, both wrong readings of it, and
a defect in the test built to settle it were all invisible to inspection and to
Dart.

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
| A storefront change observed through the production read | XCTest, fresh-session control | **OPEN** — see below |
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

## The question this gate raised — and two wrong answers to it

Two explanations have been live for never observing `CHN`:

- **A** — the storefront value is cached per process, and Aura has a real
  defect: a person moving into the China storefront would keep CallKit until
  restart.
- **B** — the harness cannot present a `CHN` storefront here, and Aura has no
  defect this gate can see.

Both wrong answers below were mine, and both are recorded rather than tidied
away, because the pattern in them is the finding.

### Wrong answer 1 — "the value is cached per process" (#14)

Stated as a proven mechanism, and the product was changed on it: a StoreKit 2
read was added specifically to defeat a cache. The evidence was three
observations that a cache would explain. So would several other things.

### Wrong answer 2 — "caching is disproven" (#15)

The reasoning was: `USA` was read correctly *after* `CHN` had been set first,
and a cached value could not track `USA`. That argument silently assumes the
first test actually read `CHN`. It never established that. If the first read
returned `USA` — because `CHN` simply does not apply — then every observation in
#15 is equally consistent with caching AND with the harness limit, and
distinguishes nothing.

The one solid fact from #15 is narrower and still stands: **a fresh session set
to `USA` reads as `USA`; a fresh session set to `CHN` does not read as `CHN`.**

### What actually decides it (#17)

A fresh session per territory, `GBR` → `JPN` → `DEU` → `FRA`, using the same
construction that demonstrably works for `USA`:

- any territory read back as itself → the read follows a change; caching is
  dead, and `CHN`'s absence is the harness. **B.**
- every territory still reading `USA` → the value is stuck at this process's
  first storefront. **A**, and a shipping defect.

### The instrument was wrong too (#16)

The first version of that control mutated **one** session's `storefront` four
times. Every StoreKit read that has ever worked in this suite constructs a
fresh session first. So "the read never followed the change" and "assigning
`.storefront` on a live session does nothing" produced an identical failure —
and the second is a defect in the test, not in Aura. It came very close to
being reported as a product defect.

The gate also could not say which of its own branches had fired: assertion text
lives in the `.xcresult` and never reaches the build log, so the reason had to
be chased through a downloaded 57 MB artifact and was still unreadable on this
machine. The workflow now extracts failure messages into the manifest, and each
branch of that test carries its actual readings in its message.

### Standing classification until #17 reports

| Claim | State |
|---|---|
| Storefront-derived policy (CHN / non-CHN / unknown) | **PROVEN** |
| Unknown storefront fails closed to prohibited | **PROVEN** |
| Authority transitions, idempotence, withdrawal | **PROVEN** |
| A fresh session's storefront is read truthfully (USA) | **PROVEN** |
| A storefront CHANGE is observed through the production read | **OPEN** |
| CallKit/PushKit construction boundary | **STATICALLY PROVEN**, source and shipped binary |
| Real `CHN` storefront runtime read | **NOT AVAILABLE IN THIS TEST ENVIRONMENT** |

None of this moves the reply to App Review. That reply rests on build 37
starting `withheld` and reading the storefront at launch, so an account already
on `CHN` gets the China read first. Caching could only make a stale value
persist; it could never invent a permitted storefront that was never read.

## Rule

Run this workflow, on the candidate commit, before every iOS submission. A red
gate is not a formality to override — both times it went red, it was right.
