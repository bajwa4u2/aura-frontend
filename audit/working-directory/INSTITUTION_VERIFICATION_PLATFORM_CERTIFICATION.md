# Institution Verification — Platform Certification

**Date:** 2026-09-10
**Subject:** the three-proof institution verification program, client and runtime
**Rule applied:** no inherited PASS. Each platform carries its own status, and a
platform that could not be exercised says so rather than borrowing another's.

---

## Status by platform

| Platform | Status | What that means here |
|---|---|---|
| **Runtime contract** (isolated stack, real HTTP) | **PASS** | 17/17 |
| **Windows desktop** | **PASS** (logic) / **EVIDENCE_LIMITED** (UI input) | 5/5 |
| **Web / Chrome** | **PASS** (journey) / **EVIDENCE_LIMITED** (acquisition) | pinned artifact, real browser |
| **Android / physical Pixel** | **EVIDENCE_LIMITED** | no device attached |
| **iOS / iPadOS** | **EVIDENCE_LIMITED** | not buildable on this host |

---

## Runtime contract — PASS

`scripts/identity-certification/institution-verification-journey-proof.mjs`,
run against the isolated certification stack (`auracert`, port 34999, ephemeral
tmpfs database, throwaway secrets, no production integrations). Isolation is
asserted by reading the container's own `DATABASE_URL` before anything is
written; the script exits 2 rather than proceed.

The complete loop, driven as **two different people** over real HTTP, using only
the endpoints a real owner and a real reviewer have:

```
owner sees NOT_STARTED, no clock running
  -> owner starts, submits evidence
  -> it reaches the reviewer's queue
  -> reviewer asks for something specific
  -> owner is told exactly what is needed, and offered the way out
  -> owner answers
  -> the case returns to review, the stale request is cleared
  -> reviewer concludes it at DOMAIN_ONLY
```

**No hidden operator intervention.** Had any step needed a database poke, the
script could not have completed without one.

Also proven on the wire: a step the lifecycle forbids is refused `409` even for
an administrator; the queue answers `403` without the permission; every step
left an audit row (6); the admin log carries no reason or evidence text (0
rows); no transition names an authority outside the three (0 rows).

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

**EVIDENCE_LIMITED for UI interaction.** Synthetic OS input into a Flutter
desktop window is unreliable on this host: clicks land wrongly after layout
reflow and Tab does not move focus between fields. Windows UI interaction is
therefore **not** claimed, and is **not** inferred from the web build.

## Web / Chrome — PASS (journey), EVIDENCE_LIMITED (acquisition)

A pinned release artifact, built against the isolated stack and served on
`localhost:35080` — the origin that stack's CORS actually allows — driven in
Chrome 152.

    artifact  sha256(main.dart.js) = 160f3fa24a79dce800956692597ef02c5fcf9456e705e73008a8582ad670e79d

What was exercised end to end, in a real browser:

* sign-in against the isolated stack (so CORS, auth and the real transport);
* a deep link to the verification route, which correctly bounced to `/login`
  with a `redirect`, and then **honoured it** after sign-in;
* the screen rendering the institution's ACTUAL standing — "Not started", the
  closed-taxonomy picker, a Start disabled until a category is chosen;
* both proofs shown as SEPARATE questions with the third named and kept apart;
* pressing Start, and **the write landing in the database**
  (`NOT_STARTED / GOVERNMENT_CIVIC`).

**THIS LANE FOUND TWO DEFECTS THAT NO TEST HAD.** See below.

**EVIDENCE_LIMITED for evidence acquisition.** The file picker, cancellation,
an oversized file, an upload failure and a retry were NOT driven in the browser.
The screen's acquisition path is the one this release already repaired and
unit-tested, but it has not been exercised here, so it is not claimed.

## What driving the real product found

Three defects, none of which any unit test could see, all in code I had written
and believed correct:

1. **The refusal envelope was read at the wrong level.** `code` and `message`
   nest under `error`; both new repositories read the top level, so EVERY server
   refusal would have reached a person as the generic offline sentence. Found by
   the Windows lane.

2. **The success envelope was read at the wrong level too.** Responses arrive as
   `{ok, data}`; the parser was handed the whole body, found none of its keys,
   and fell to every "unknown" default — so the screen showed BOTH proofs as
   "In review" for an institution that had never started one, and offered no
   action at all. Found by the web lane, on screen, in a browser.

3. **The route policy was circular.** `InstitutionRoutePolicy.admin` resolves to
   `authorizedSpeaker`, which an institution only confers once VERIFIED. So
   reaching the verification screen required being verified. An OWNER of an
   unverified institution — exactly the population the program exists for — was
   refused at their own verification page with the role card beside it reading
   "Founder". Found by the web lane.

Seventeen unit tests, a route-registry gate and eight doctrine gates all passed
over the top of all three.

## Android / physical Pixel — EVIDENCE_LIMITED

**No device is attached.** `flutter devices` finds Windows, Chrome and Edge
only; there is no AVD image on this host either. Nothing about the Android
build of these surfaces has been exercised.

**This needs the founder**: attach the Pixel, or authorise an AVD.

Evidence acquisition on Android — the picker and share flow the founder asked
to see proven — cannot be claimed at all from here.

## iOS / iPadOS — EVIDENCE_LIMITED

**Structurally impossible on this host.** iOS requires macOS and Xcode; this is
Windows. The release lane's route is Codemagic, which the founder triggers.

`integration_test/ipad_reviewer_journey_test.dart` exists from earlier work and
is not evidence for these surfaces.

---

## What must happen before any of these becomes PASS

1. **Web** — the remaining half: real file acquisition, cancellation, an
   oversized file, an upload failure and a retry; and the reviewer queue driven
   in a browser.
2. **Android** — the same, on the attached Pixel, including the system picker
   and share flow.
3. **iOS/iPadOS** — the same through the Codemagic lane.

Until then these three read EVIDENCE_LIMITED, and **`AURA_1.4.3` is not
FREEZE_READY**. Nothing here may be promoted by inference from another
platform's result.
