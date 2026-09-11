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
| **Web / Chrome** | **EVIDENCE_LIMITED** | see below |
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

## Web / Chrome — EVIDENCE_LIMITED

The build target is available (`flutter devices` lists Chrome 152 and Edge 152)
and the web picker path is the one this release already repaired. What has NOT
been done is a driven browser pass of the new surfaces against the isolated
stack.

Reported EVIDENCE_LIMITED rather than PASS, because the founder's own rule is
that a browser check is not a proxy for anything and a PASS must be earned by
exercising the journey.

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

1. **Web** — serve the built client against the isolated stack and drive the
   owner journey, the reviewer queue and the NEEDS_INFO loop in a browser,
   including real file acquisition, cancellation, an oversized file, an upload
   failure and a retry.
2. **Android** — the same, on the attached Pixel, including the system picker
   and share flow.
3. **iOS/iPadOS** — the same through the Codemagic lane.

Until then these three read EVIDENCE_LIMITED, and **`AURA_1.4.3` is not
FREEZE_READY**. Nothing here may be promoted by inference from another
platform's result.
