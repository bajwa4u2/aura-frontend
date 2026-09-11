# Institution Verification — Platform Certification

**Date:** 2026-09-11
**Subject:** the three-proof institution verification program, client and runtime
**Source under certification:** `release/aura-1.4.3-38` on both remotes.
`main` untouched on both.

    client   26f6e882  github.com/bajwa4u2/aura-frontend
    backend  649fad72  github.com/bajwa4u2/aura-backend
    trees    clean (tracked files)

**Not deployed.** Production runs `0b92237d` — `origin/main` — confirmed from
`api.auraplatform.org/health`, and both verification routes answer `404` there
while `/health` answers `200`. The entire program awaits the founder's cutover,
which is the frozen state, and the migration defect below is therefore not live
in production because the feature containing it is not either.
**Rule applied:** no inherited PASS. Each platform carries its own status, and a
platform that could not be exercised says so rather than borrowing another's.

---

## Status by platform

| Platform | Status | What that means here |
|---|---|---|
| **Runtime contract** (isolated stack, real HTTP) | **PASS** | 17/17 |
| **Android / physical Pixel 9a** | **PASS** (journey, authority, migration, NEEDS_INFO) / **EVIDENCE_LIMITED** (system picker) | 60/60 across five lanes |
| **Windows desktop** | **PASS** (logic) / **EVIDENCE_LIMITED** (UI input) | 5/5 |
| **Web / Chrome** | **PASS** (journey) / **EVIDENCE_LIMITED** (acquisition) | pinned artifact, real browser |
| **iOS / iPadOS** | **IN PROGRESS** | Codemagic, on the exact release commit |

---

## Android / physical Pixel 9a — PASS

`Pixel 9a`, serial `53061JEBF08485`, **Android 17 / API 37, arm64-v8a**. Real
device, real ARM64 Dart, real plugin registration, talking to the isolated
certification stack through `adb reverse tcp:34999 tcp:34999`. Nothing here is
inherited from the Windows or web lanes.

Every lane is **re-seeded immediately before it runs**, because three of the
four mutate the fixture, and every lane **asserts its own precondition** and
names the seeding command if it is not met. A stale fixture therefore fails
fast and explains itself, instead of surfacing later as a correct lifecycle
refusal reported as a product defect.

```
android_institution_verification_certification_test.dart   16/16
android_institution_governance_certification_test.dart     13/13
android_institution_migration_certification_test.dart       9/9
android_institution_needs_info_certification_test.dart     14/14
android_return_path_test.dart                               8/8
                                                        -------
                                                           60/60
```

**The verification surface (16).** Standing parses on ARM64; an account without
standing is refused carrying the server's own words AND its machine code;
submitting to somebody else's institution is refused; the reviewer queue is
unreadable without the permission; start is idempotent and never moves a
category already recorded; evidence submitted from the phone moves the proof;
every notification DESTINATION resolves to that institution and no other —
that is route resolution, and this record makes no claim anywhere that a
notification was DELIVERED on any platform; the
mobile layout does not overflow; the three proofs are not collapsed; a deadline
is shown as a date and an unstarted clock is not shown at all.

**Authority and assurance governance (13).** The capability gate tells four
postures apart — no record, base, elevated, and elevated-then-contradicted.
The last is the sharpest: that fixture **holds an approved ELEVATED
submission**, so its refusal can only come from the date-of-birth conflict rule
and from nothing else. Ordinary Aura is proven NOT gated, which is the positive
control every refusal above depends on. Delegation is checked on the TARGET,
not the actor, and is proven to PERMIT as well as refuse. Demotion of an
unverified admin remains possible. Nobody is made OWNER through a role change.

**The 120-day migration (9).** Three historical VERIFIED institutions, same
owner, same notice, differing in exactly one variable: whether a channel
delivered. So a difference the API reports between them has one possible cause.

```
NOTICE_NOT_DELIVERED -> CLOCK_NOT_STARTED    NOT_ANCHORED, no deadline, nothing blocked
FIRST_DELIVERY       -> CLOCK_STARTS         IN_WINDOW, deadline = delivery + 120d
WINDOW_ELAPSED                               only then does institution voice stop
```

No modern proof is fabricated for any of them — not one evidence row — and the
lane asserts that rather than assuming it.

**The NEEDS_INFO loop (14), walked as two different people from one phone.**
Owner submits; it reaches the reviewer's queue; the reviewer cannot ask about a
case they have not taken (asserted first, because the happy path would hide
it); they take it and ask for something specific; the owner is told *that exact
sentence*; is offered the way out; answers; it returns to review; the stale
request is gone. **No hidden operator intervention**: neither identity holds
database access, so had any step needed a poke behind the product, the lane
could not have completed. Plus the reviewer's words rendering on the phone,
survival at 1.5× text scale, and 44dp minimum control heights.

**EVIDENCE_LIMITED — the system file picker and share sheet.** These need
OS-level interaction a Flutter integration test cannot perform. Android
evidence *acquisition* is therefore not claimed and is not inferred from the
web build. The reference path — what may be offered as a non-document fact — IS
exercised, and deliberately from the NEEDS_INFO state where the lifecycle has
no objection, so the guard is the only thing that can refuse.

## Runtime contract — PASS

`scripts/identity-certification/institution-verification-journey-proof.mjs`,
against the isolated certification stack (`auracert`, port 34999, ephemeral
tmpfs database, throwaway secrets, no production integrations). Isolation is
asserted by reading the container's own `DATABASE_URL` before anything is
written; the script exits 2 rather than proceed.

Also proven on the wire: a step the lifecycle forbids is refused `409` even for
an administrator; the queue answers `403` without the permission; every step
left an audit row (6); the admin log carries no reason or evidence text (0
rows); no transition names an authority outside the three (0 rows).

**One deliberate deviation from production, recorded rather than buried.** The
certification compose file raises `RATE_LIMIT_AUTH_MAX`. Production keeps its
default of 30 per 5 minutes and this value exists in no other file. The reason
is the seeder, which registers people and signs fixtures in on every run, so a
certification loop exhausts the budget and the next run fails at setup with a
rate limit instead of a result. No lane asserts a 429 and no lane certifies the
limiter; a 429 during seeding is a false failure, not a defect being hidden.

## Windows desktop — PASS (logic), EVIDENCE_LIMITED (UI input)

`integration_test/institution_verification_certification_test.dart -d windows`,
5/5. Real platform, real networking, real plugin registration, driving the
**shipped** `InstitutionVerificationRepository` rather than a restatement of it.

**This lane earned its keep.** It caught a defect no unit test could: both new
client repositories read `code` and `message` from the TOP level of the refusal
envelope, which nests them under `error`. Every server refusal would have
reached a person as the generic offline sentence. Seventeen unit tests passed
because the doubles were hand-built at the wrong level — a double of a shape
nobody had checked.

**Its positive control was repaired on 2026-09-11.** It had probed a stranger
institution and asserted only that a status code came back, which a refusal
also satisfies — so it could not distinguish "the contract works" from
"everything is refused", the one condition it exists to rule out. It now reads
the owner's own standing and asserts `200` plus the institution it asked about.

**EVIDENCE_LIMITED for UI interaction.** Synthetic OS input into a Flutter
desktop window is unreliable on this host: clicks land wrongly after layout
reflow and Tab does not move focus between fields. Windows UI interaction is
therefore **not** claimed, and is **not** inferred from the web build.

## Web / Chrome — PASS (journey), EVIDENCE_LIMITED (acquisition)

A pinned release artifact, built against the isolated stack and served on
`localhost:35080` — the origin that stack's CORS actually allows — driven in
Chrome 152.

    artifact  sha256(main.dart.js) = 4d2743cb53296c4aff6c041f5dce0f1b133eb47712a82699e7117fb95885adc2

**RE-BUILT AND RE-RUN at the final release commit on 2026-09-11**, not carried
forward. The earlier web PASS was earned at `4aae0990`, and the client has
changed materially since — the standing now carries `mayAct` and the screen
renders a different block when it is false. "No inherited PASS" applies to my
own earlier result as much as to another platform's, so the artifact was built
again and the lane re-run: 6/6.

What that re-run proves, in a real Chromium against the isolated stack:

* the migration owner — who holds NO elevated tier — **can read their own
  standing**, which is the exact request that used to be refused
  `ASSURANCE_REQUIRED`;
* they are told they may not yet act, and the tier is named;
* the verified owner IS permitted, so the two genuinely differ — without which
  both screens could be identical and both would pass;
* a cold deep link to the verification route bounces to
  `/login?redirect=/institution/<id>/verification` and keeps the destination.

**What it does NOT prove, stated rather than implied.** This run did not sign in
through the form and photograph the verification screen. The rendering of the
`mayAct = false` path — the deadline as a date, and "Verify my identity" offered
in place of an action that would refuse — is certified **on the physical Pixel**,
in `android_institution_migration_certification_test.dart`, and is not claimed
for web.


**Reproducibility caveat on that hash.** It was produced from a checkout with
LF line endings (this repo sets `core.autocrlf=false` and carries no
`.gitattributes`). A clone made on a machine where `core.autocrlf` is true
would check the Dart sources out with CRLF and could produce a different hash
for identical content. The hash pins THIS artifact; it is not a claim that any
clone reproduces it byte for byte.

What was exercised end to end, in a real browser: sign-in against the isolated
stack; a deep link to the verification route, which correctly bounced to
`/login` with a `redirect` and then honoured it; the screen rendering the
institution's ACTUAL standing; both proofs shown as SEPARATE questions with the
third named and kept apart; pressing Start, and the write landing in the
database.

**EVIDENCE_LIMITED for evidence acquisition.** The file picker, cancellation,
an oversized file, an upload failure and a retry were NOT driven in the browser.

## iOS / iPadOS — IN PROGRESS, and substantially repaired

Codemagic, `ios-certification` and `ios-testflight`, both against the exact
release-branch commit.

**This lane had not succeeded once since 2026-09-07, on any branch** — so its
failures were never something the release branch introduced. Chasing that
produced four findings, each of which had been hidden by the one before it.

**1. The lane could never reach its own evidence.** The iPad step ran unbounded
and consumed the entire 60-minute budget on every run, so the two steps behind
it — the native XCTest layer and the full suite sweep — had **never executed
once**. Most of the iOS evidence was never gathered, and nothing said so.

Bounded now, with a shell-native watchdog rather than `timeout(1)`: the image
has neither `timeout` nor `gtimeout`, which an earlier attempt discovered the
expensive way by logging `running unbounded` and then sitting for 37 minutes.
The step records its verdict and lets the build continue; a gate at the END
reads every recorded verdict and fails the build if any is not PASS, and fails
CLOSED on a missing verdict file. A failure still goes red — it now does so
having collected the rest of the evidence first.

**2. The native test target had not compiled in weeks.**

    ios/RunnerTests/RunnerTests.swift:572: error: cannot find 'held' in scope
    target=RunnerTests executed=0 passed=0 failed=0

A single-session refactor removed an array of `SKTestSession`s and left the line
extending its lifetime naming the deleted variable. No test failed, because no
test could be built. The first run that got past the iPad step found it.

Fixed — and the next run executed **28 native tests, 27 passed, 1 skipped**,
the first native iOS coverage this branch has ever produced.

**3. The one failing native test was not entitled to its conclusion.**

    four storefront changes and every read still reported USA
    [GBR->USA, JPN->USA, DEU->USA, FRA->USA] — the value is stuck

That is the China/CallKit jurisdiction gate, the area that caused the 1.4.0
Guideline 5 rejection, so it matters a great deal whether it is true.

It was not established. The test proved "the authority is reachable" by setting
the storefront to `USA` and reading `USA` back — but **USA is the simulator's
default**, so that read returns USA whether the override works or does nothing
at all. Two explanations fit identically: the product caches a stale value, or
`SKTestSession`'s override has no observable effect here. The product code
decides it, and it is not the defect — `currentCountryCode()` holds no cache;
on iOS 15+ it is `await Storefront.current?.countryCode`, which reports the
storefront as it is now. There is nowhere for a stale value to live.

The file's own comments record that this claim has been **asserted and retracted
twice before** on evidence with more than one reading. The control now comes
first and is never the default: if no non-default territory can be presented the
test SKIPS and says so in both directions, and only once a real change has been
observed is a refusal to move back treated as staleness. Stricter, not looser.

**4. The suite sweep would have failed seven ways on its first run.** Seven
integration suites drive the isolated stack on `127.0.0.1:34999`, which exists
only on the certification host. Three of the seven predate this release. They
are now labelled `SKIPPED_NO_BACKEND`, kept distinct from `SKIPPED_PLATFORM`,
because "needs a backend this machine does not run" and "asserts another
platform's semantics" are different facts. **Neither is a pass, and neither
means uncertified** — every one of those suites IS exercised against that stack
on the certification host.

**No iOS or iPadOS PASS is claimed here.** The iPad reviewer journey has not
produced a result on any run: it either hung or reported `No tests ran`, and it
is recorded as such rather than inferred from Android, Windows or web.

---

## What the certification found, that no test suite had

Every one of these was in code believed correct, and each was found by driving
the real product on a real platform rather than by reasoning about it.

1. **The refusal envelope was read at the wrong level.** Found by Windows.
2. **The success envelope was read at the wrong level too.** The screen showed
   BOTH proofs as "In review" for an institution that had never started one.
   Found by the web lane, on screen, in a browser.
3. **The route policy was circular.** `InstitutionRoutePolicy.admin` resolves
   to `authorizedSpeaker`, which an institution only confers once VERIFIED — so
   reaching the verification screen required being verified. Found by web.
4. **THE MIGRATION JOURNEY WAS A CLOSED LOOP.** Found on the Pixel, by building
   a fixture for the population the migration actually addresses. That
   population is by definition not verified to the elevated tier — obtaining it
   is what is being asked of them — and the only route returning their deadline
   required that tier. The notice arrived, the person tapped it, and the screen
   refused to load. They would have been silently expired without ever being
   shown a date. Repaired in `e375a5b` and `163eb09`.

Seventeen unit tests, a route-registry gate and eight doctrine gates all passed
over the top of the first three.

## Build number

**38 is free on Google Play**, confirmed live against the store on 2026-09-11
rather than assumed: accepted `versionCode`s are `[1, 3, 24, 25, 27, 35, 36,
37]`. Apple has never accepted a 1.4.3 artifact — no `ios-testflight` run since
the 1.4.2 upload of 2026-09-06 has reached the `Build signed IPA` step — and
the running build will get the store's own answer rather than ours.
