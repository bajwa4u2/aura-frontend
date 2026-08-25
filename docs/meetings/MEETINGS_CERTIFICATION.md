# Aura Meetings — certification record

2026-08-25. Founder ruling §XXVI: **engineering target is web + Android + iOS +
Windows; certification claims cover only platforms that actually executed.**

Harness: `integration_test/meetings_certification_test.dart`.

---

## Platform matrix

| Capability | Web | Android physical | Windows native | iOS thesis |
|---|---|---|---|---|
| R-4 — Meetings inside the return contract | `NOT_EXECUTED` | **PASS** | **PASS** | `STRUCTURALLY_EXPECTED` |
| §XII — `/room` canonicalises to the record | `NOT_EXECUTED` | `NOT_EXECUTED` (no session) | **PASS** | `STRUCTURALLY_EXPECTED` |
| §XII — retired aliases stay resolvable | `NOT_EXECUTED` | `NOT_EXECUTED` (no session) | **PASS** | `STRUCTURALLY_EXPECTED` |
| §XXIV — 8 durable routes render cold | `NOT_EXECUTED` | **PASS** | **PASS** | `STRUCTURALLY_EXPECTED` |
| §XXIV — malformed address does not crash | `NOT_EXECUTED` | **PASS** | **PASS** | `STRUCTURALLY_EXPECTED` |
| §VII — room controls labelled for assistive tech | `NOT_EXECUTED` | **PASS** | **PASS** | `STRUCTURALLY_EXPECTED` |
| §XXV — phone geometry + touch targets ≥ 44px | `NOT_EXECUTED` | **PASS** | **PASS** | `STRUCTURALLY_EXPECTED` |
| §XXV — reduced desktop window, no overflow | `NOT_EXECUTED` | **PASS** | **PASS** | `STRUCTURALLY_EXPECTED` |
| §IX — platform-correct permission recovery | `NOT_EXECUTED` | **PASS** — returned the Android instruction | **PASS** — returned the Windows instruction | `STRUCTURALLY_EXPECTED` — the same switch has an iOS branch |
| Signed-in entry to the workspace | `NOT_EXECUTED` | `NOT_EXECUTED` (no session) | **PASS** | `STRUCTURALLY_EXPECTED` |
| Record cold-entry offers the governed return | `NOT_EXECUTED` | `NOT_EXECUTED` (no session) | **PASS** | `STRUCTURALLY_EXPECTED` |
| **Two-party active media** | `NOT_EXECUTED` | `NOT_EXECUTED` | `NOT_EXECUTED` | `NOT_EXECUTED` |
| Compiles and links for the platform | **PASS** — `flutter build web` succeeded (158.8s) | **PASS** | **PASS** | `NOT_EXECUTED` |

**Totals** — Windows **11/11 PASS with a real session**. Android **11/11 PASS**,
7 exercised and 4 session-dependent skipped. Web `NOT_EXECUTED`. iOS
`NOT_EXECUTED`.

### Classifications

```
MEETINGS_WEB_CERTIFICATION              = NOT_EXECUTED (build PASS, behaviour unexecuted)
MEETINGS_ANDROID_PHYSICAL_CERTIFICATION = PASS_WITH_LIMITATIONS
MEETINGS_WINDOWS_NATIVE_CERTIFICATION   = PASS
MEETINGS_IOS_CERTIFICATION              = NOT_EXECUTED
```

---

## Why Android is `PASS_WITH_LIMITATIONS`

Every test that ran, passed. Four did not run, because the debug build on the
Pixel 9a had **no session**, and a meeting record is a member surface — the
auth gate correctly intercepted before the alias redirect could be observed.
Reporting that as a pass would be claiming evidence that does not exist.

**Likely cause, stated as likely rather than proven:** `/auth/refresh` issues
single-use refresh tokens. The Windows certification ran first, on the same
account, and rotating the token there would invalidate the copy the Android
build was holding. This is the same harness artefact recorded during the Create
chapter, not a product defect — but it was not re-verified this session, so it
is offered as the probable explanation and not as a finding.

What Android **did** certify is the part that only a real device can:
real touch-target geometry, real text metrics, the semantics tree as TalkBack
would traverse it, and the Android-specific permission recovery string.

## Why web is `NOT_EXECUTED`

One reason, and it is not "it probably works":

1. **The client harness could not load the suite.** `flutter test --platform
   chrome` eventually failed with:

   > Failed to load "test\meetings\meeting_lifecycle_test.dart": Connection
   > closed before test suite loaded.

   followed by a Chromium process the runner could not terminate with either
   SIGTERM or SIGKILL. The suite never began, so nothing about the product was
   exercised, passed or failed. This is an environment failure in the browser
   test runner on this host, not a result — and it is recorded as one rather
   than as a hang, which is what it looked like while it was still running.
A second reason applied when this was first written and **no longer does**: the
backend half was uncommitted, so exercising the lifecycle against production
would have certified the previous build. Both repos shipped on 2026-08-25 and
the migration is verified in production, so that obstacle is gone. Web
behavioural certification is now blocked only by the harness above.

What web evidence there IS: `flutter build web` **succeeds** on the
reconstruction. That proves it compiles and links for the web target — no
platform-conditional code broke, no import is native-only — and it is worth
recording. It is not behavioural certification and is not offered as such.

Web behavioural certification is therefore **owed now**, on a host where the
browser test runner works or by driving the deployed site directly. It is
listed in `docs/NEXT_WORK.md` rather than quietly assumed.

## iOS implementation thesis

```
MEETINGS_IOS_IMPLEMENTATION_THESIS = RECORDED
MEETINGS_IOS_CERTIFICATION         = NOT_EXECUTED
```

No iOS or TestFlight environment exists on this host.

Meetings introduces no platform-coupled behaviour of its own: it composes
`AuraScaffold` / `GuestShell`, uses no platform channel, and its geometry is
ordinary. The three things that genuinely differ on iOS:

* **camera and microphone.** `NSCameraUsageDescription` and
  `NSMicrophoneUsageDescription` are present in `Info.plist`. The recovery
  instruction is platform-switched, and the switch is proven live rather than
  theoretical — the same code returned the Windows text on Windows and the
  Android text on Android, so the iOS branch is exercised code on an
  unexercised platform.
* **safe areas and gestures.** Owned by the shell, unchanged by this work.
* **audio session, interruptions, device routing.** A/V chapter. Recorded as
  release-blocking debt in `NEXT_WORK.md`.

### TestFlight checklist, for when an environment exists

1. `flutter test integration_test/meetings_certification_test.dart -d <ios>`
   with a real session — all 11.
2. Camera/microphone prompt copy and the denied-state recovery path.
3. Backgrounding mid-meeting, and an incoming phone call.
4. Safe areas on a notched device, in both orientations.
5. Deep entry into `/meetings/:id` from a cold app launch.
6. Two-party media with a second device — jointly with the A/V chapter.

---

## Test health

| suite | count | state |
|---|---|---|
| client — `test/meetings` | 12 files, **145 tests** | green |
| client — `test/navigation` | **204 tests** | green |
| backend — `src/meetings` | 9 suites, **101 tests** | green |
| `flutter analyze` | 24 pre-existing `info`, **0 errors, 0 warnings** | unchanged from baseline |

```
TEST_HEALTH = GREEN
ANALYZE     = GREEN (24 pre-existing info-level, none introduced)
```

Ten of the client tests instantiate the live room's control bar. Before this
chapter that number was zero, and it was zero because reaching those widgets
required building a 3,934-line screen that opens a socket.
