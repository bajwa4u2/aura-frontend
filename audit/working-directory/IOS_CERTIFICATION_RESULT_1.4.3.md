# iOS Certification — Aura 1.4.3 (38)

**Date:** 2026-09-11
**Build:** Codemagic `6aa3a010438a04ede791c5d4`, workflow `ios-certification`
**Artifact commit:** `1908be06220f00574ef30eb5547a3755e570bee2`
**Instance:** `mac_mini_m2` · Flutter 3.47.3 · Dart 3.13.3 · Xcode 26.6 · iOS SDK 26.5
**Total:** 1h 15m 45s — **bounded, not killed by the build cap**

## VERDICT = FAILED

Stated first, because this document exists to stop it being read any other way.
**iOS is NOT certified for 1.4.3.** Nothing below promotes it, and no result
from Android, Windows or web is permitted to stand in for it.

---

## The full accounting

The founder's requirement: *suites discovered, suites executed, tests executed,
skips with reason, timeout/budget termination, artifact commit.* All six.

```
suites discovered                           25
  executed                                   6
  SKIPPED_NO_BACKEND                         7
  SKIPPED_PLATFORM                           3
  TIMED_OUT (300s per-suite bound)           8
  NOT_RUN (2700s sweep budget spent)         6

tests executed (in the 6 that ran)          35
  passed                                    30
  failed                                     5
```

### Executed (6)

| Suite | Result | Discovered / executed / passed / failed |
|---|---|---|
| `secure_token_storage_certification_test` | **PASS** | 9 / 9 / 9 / 0 |
| `meetings_certification_test` | FAIL | 14 / 14 / 13 / 1 |
| `operator_hub_certification_test` | FAIL | 10 / 10 / 8 / 2 |
| `create_meeting_certification_test` | FAIL | 1 / 1 / 0 / 1 |
| `media_certification_test` | FAIL | 1 / 1 / 0 / 1 |

### SKIPPED_NO_BACKEND (7) — needs the isolated stack on 34999

`android_institution_verification` · `android_institution_governance` ·
`android_institution_migration` · `android_institution_needs_info` ·
`finance_doorway_certification` · `identity_certification` ·
`institution_verification_certification`

**This is "not here", not "not proven".** Every one of these IS exercised
against that stack on the certification host — the four institution lanes on a
physical Pixel 9a through `adb reverse` (60/60), the others on Windows and in
Chrome. The stack is an ephemeral docker environment that exists only on that
host; nothing listens on 34999 on a Codemagic machine.

### SKIPPED_PLATFORM (3)

`android_return_path` · `av_android_certification` · `desktop_lifecycle` —
each asserts another platform's semantics.

### TIMED_OUT (8) — each exceeded the 300s per-suite bound

`av_certification` · `create_landing` · `ipad_reviewer_journey` ·
`operator_bootstrap_timing` · `preferences_certification` ·
`relay_certification` · `sfu_certification` · `sfu_media_service`

**A timed-out suite is recorded as a FAILURE, not a skip.** A suite that cannot
finish has not passed.

### NOT_RUN (6) — the sweep budget was spent before reaching them

`sfu_multiparty_controller` · `sfu_multiparty` · `sfu_thread_call_parity` ·
`sfu_transport_seam` · `signed_in_institution_return` · `trace_lifecycle`

**NOT_RUN is a third answer.** Not a pass, not a failure: the lane ran out of
time before it got here. Eight suites consuming 300s each is 40 of the 45
available minutes, which is why these six were never reached. Written down
because a sweep reporting green over six unexecuted suites is precisely the
false-coverage claim this lane exists to prevent.

---

## What the failures actually are

Classified from the log rather than assumed, because the distinction decides
whether this is a product problem or a harness one.

**ENVIRONMENTAL (2).** `create_meeting_certification_test` and
`media_certification_test` both failed at LOAD with
`Failed to start Dart Development Service`. No test ran; nothing about the
product was exercised.

**PROBABLY SYSTEMIC (8).** Eight suites hitting exactly 300s is not eight
independent defects. The iPad reviewer journey shows the same signature — it
reaches `shell.build ... chose=PublicShell` and then emits nothing for seven
minutes — and it stalls in a region this release never touched. The same image
produced `No tests ran` on an earlier run. This reads as instability of these
integration suites on this simulator image, and it is **not established** as a
product defect.

**GENUINE ASSERTION FAILURES (3).**

* `operator_hub_certification_test` ×2 — *"the seven areas are frozen, in
  order"* expected 7, and *"an owner sees all seven"* expected 7 and found 8.
  A real discrepancy between the test's frozen list and the product's areas.
  **This is the Admin/operator workstream's surface, not the institution
  verification program.**
* `meetings_certification_test` ×1 — *"§XXIV :: no Meetings route renders a
  blank shell cold"*.

---

## What iOS DID prove

**The native layer passed, and it is the half that matters most for App
Review.** Reproduced across two consecutive builds:

```
target=RunnerTests   executed=27  passed=27  failed=0  skipped=2   rc=0
NATIVE VERDICT=PASSED
```

Covering the China/CallKit jurisdiction gate (the surface that caused the 1.4.0
Guideline 5 rejection), the storefront authority state machine, and call
notification matching across the APNs, FCM-data and flattened-FCM shapes.

**The 2 skips are correct abstentions, not gaps.** Both are the
`SKTestSession` storefront-control cases. They skip because the override
produced no observable change in this environment, which is indistinguishable
from a stale read — so the test declines to claim anything in either direction.
A real China storefront read remains **UNPROVEN here and must not be claimed to
App Review**.

**And the TestFlight lane is green end to end** — `aura.ipa`, 1.4.3 (38),
accepted and processed by Apple. See the artifact manifest.

---

## Why this lane had never reported before

Worth recording, because the fixes are the reason there is a result at all.
This lane had not succeeded once since 2026-09-07 on any branch, and each cause
was hidden behind the previous one:

1. The iPad step ran unbounded and consumed the whole 60-minute budget every
   run, so **the two steps behind it had never executed once**. It also starved
   the TestFlight build in the queue for 1h 59m.
2. Once bounded — the native target **had not compiled in weeks**
   (`cannot find 'held' in scope`, reporting `executed=0`, so nothing failed
   because nothing could be built).
3. Once compiled — the one failing native test was about to report the
   China/CallKit gate broken **on reasoning it had not earned**.
4. Once that abstained — the sweep would have failed seven ways on suites
   needing a backend the machine does not run, and then ran unbounded itself.

A gate that is never reached is not a gate.
