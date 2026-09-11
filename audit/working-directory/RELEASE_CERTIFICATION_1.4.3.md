# Aura 1.4.3 (38) — Release Certification

**Date:** 2026-09-11
**Decision:** founder, 2026-09-11 — *"accept the known iOS certification residual
and proceed."*

    SOURCE_FREEZE = ACCEPTED
    RELEASE       = AUTHORIZED WITH DOCUMENTED IOS CERTIFICATION WAIVER

The phrase `FREEZE_READY = BLOCKED` is retired and is not used here.

---

## The frozen source

    FINAL_FROZEN_CLIENT    0bfea435375ce2a283f1ffce8a7335884e7107fd
    FINAL_FROZEN_BACKEND   4856728e641ebe4f7029c5079295682f75005343
    BRANCH                 release/aura-1.4.3-38   (both remotes)
    MAIN                   UNTOUCHED  — 491db357 / 0b92237d
    TREES                  clean (tracked files)

## The evidence set

    ANDROID_PIXEL          60/60 x2       physical Pixel 9a, Android 17 / API 37, arm64
    WINDOWS                5/5
    WEB                    6/6            rebuilt and re-run at the freeze commit
    RUNTIME_CONTRACT       17/17          isolated stack, real HTTP
    BACKEND                5127/5127      406 suites
    CLIENT                 2775/2775
    GOLDEN                 131 PASS / 1 DOCUMENTED SKIP
    IOS_NATIVE_TESTS       27/27          2 correct abstentions

## iOS certification disposition

    IOS_CERTIFICATION_LANE           FAILED
    FAILURE_CLASS                    SIMULATOR / DDS / TIMEOUT INFRASTRUCTURE
    DEMONSTRATED_PRODUCT_DEFECT      NONE
    FOUNDER_RELEASE_WAIVER           ACCEPTED
    IOS_CERTIFICATION_RESIDUAL       KNOWN / WAIVED
    IOS_PRODUCT_DEFECT_FROM_RESIDUAL NOT DEMONSTRATED

**The lane is NOT relabelled PASS.** This is an explicit release waiver taken on
the complete evidence set, not an assertion that a failed lane succeeded. The
distinction is the point of recording it this way.

What the residual consists of, from `IOS_CERTIFICATION_RESULT_1.4.3.md`: two
suites that failed at LOAD with `Failed to start Dart Development Service` (no
test ran), eight that exceeded the 300s per-suite bound, and six never reached
because the sweep budget was spent. Eight suites hitting exactly 300s is not
eight defects; the same image produced `No tests ran` on an earlier run, and the
iPad journey stalls in a region this release never touched.

The three genuine assertion failures the lane found were **real and are fixed** —
see the Operator Hub section below. Nothing remaining in the residual has been
shown to be a product defect.

**No further simulator-certification work is required before submission**, and
the instability is not to be chased again for this release unless it produces
evidence of an actual product defect.

## Apple artifact

    APPLE_BUILD_38              ACCEPTED INTO ASC
    APP_REVIEW                  PENDING
    ASC build                   adf9d5ea-314b-4904-87c0-4839a8d5f616  (app 6772071135)
    artefact                    aura.ipa  37,917,528 bytes
    sha256                      cc61b21f76aa334b0e4868bafb94e48e43acd1a02dfbaa8e3b97f7f52e9d9d10
    CFBundleShortVersionString  1.4.3
    CFBundleVersion             38        read from the artifact Apple processed

    IOS_ARTIFACT_SOURCE         5d9bfcdd
    FINAL_SOURCE_FREEZE         0bfea435
    DIFFERENCE                  15 COMMENT LINES / 0 EXECUTABLE STATEMENTS
    BYTE_EQUALITY               FALSE
    BEHAVIOURAL_EQUIVALENCE     ESTABLISHED TO CURRENT EVIDENCE

**Acceptance into App Store Connect is not App Review approval.** `APP_REVIEW`
stays `PENDING` until reviewers act.

**Build 38 is consumed.** Another iOS binary would require build 39 and should
happen only if App Review identifies an actual defect, a production or runtime
defect is demonstrated, or a consequential executable change becomes necessary.
**Build 39 is not to be created pre-emptively**, and iOS is not to be rebuilt
for source-hash aesthetics.

## Artifacts, from the freeze commit

    AAB      build/app/outputs/bundle/release/app-release.aab
             sha256 a1887009fc1bff076ae7031111a601dfa0d8fa9b1de6b82f64cdb574dc231fb2
             versionCode 38 · versionName 1.4.3 · signed META-INF/UPLOAD.RSA
             (versionCode and versionName read from the artifact's own manifest)

    WEB      build/web_final/main.dart.js
             sha256 4d2743cb53296c4aff6c041f5dce0f1b133eb47712a82699e7117fb95885adc2

    IOS      accepted at Apple as build 38, provenance above

    WINDOWS  not rebuilt for 1.4.3 and not claimed. Partner Center automation
             became available on 2026-09-11 but no Windows artifact was produced
             or certified for this release.

## Operator Hub correction — accepted into release truth

The iOS lane's three genuine assertion failures were one omission seen four
ways. Commit `e1d9e808` added an eighth `OperatorArea` (`external`,
`/admin/external`, gated on `EXTERNAL_CONSUMERS_READ`) and changed
`operator_area.dart` and nothing else.

    EIGHT-AREA CATALOGUE      now the frozen list, in order, ending `external`
    OWNER-PERMISSION GUARD    part of the release truth

Repaired: the freeze list; both owner fixtures, which had hand-copied the
permission catalogue and missed `EXTERNAL_CONSUMERS_READ/WRITE`; and the render
harness, which rendered External at no width behind a comment promising every
area was rendered at every width.

**The guard is the durable part.** OWNER is founder-frozen as the complete
current catalogue, so a fixture short of one entry describes somebody who does
not exist. The guard reads the backend's `ALL_ADMIN_PERMISSIONS` and fails when
the fixture is missing any of it — comparing against the source rather than
against other tests sharing the same assumption, which is the only thing that
could have caught this. A second test asserts every area is reachable by
somebody, because an area gated on a capability no role holds is invisible to
every operator alive and looks exactly like a correctly-secured area.

Verified with a control: 12/12 on Windows, and with one permission deliberately
removed the suite fails with *"external is unreachable even for an owner"*.

The 70 golden movements are an **explained** acceptance: `OperatorShell` renders
`OperatorArea.visibleFor(authority)`, so granting the owner its real permission
puts External in every surface's navigation. 64 stale references plus 6 that had
never existed; dimensions unchanged on sample; suite returns 131 / 1.

## Android distribution — kept separate, deliberately

    ANDROID_GENERAL_AVAILABILITY = FALSE

Not a client-certification fact and must not be used to falsify one. The Android
client is certified 60/60 twice on a physical Pixel; what is not true is public
availability.

    PLAY_404_CAUSE   production release 37 (1.4.2) "Start full rollout" is IN
                     GOOGLE REVIEW. App status remains "Closed testing" and the
                     Console checklist reads "4 of 5 complete", the incomplete
                     step being "Publish your app on Google Play".

Ruled out, each checked: countries/regions (177), device catalogue, managed
publishing (off), store listing (present), package identity, policy gate or
rejection (none), Android developer verification (registered, 3 keys).

The Play Developer API's track status `completed` means the developer-side
rollout reached 100% — **not** that Google has published it. Reading it as
"live" is how a release gets announced before it exists.

Separately: neither Aura nor Orchestrate is currently returned by Play search
(verified with a control query). Orchestrate is genuinely live by direct URL;
Aura has never been published. Play state is to be reported as it changes.

## Outstanding — founder action

Store submission is the founder's action by standing doctrine, and is also
outside this session's credentials: the Codemagic integration uploaded the build
to App Store Connect, but submitting for App Review is a separate App Store
Connect action for which no key is held here.

    1. App Store Connect -> Aura Platform (6772071135) -> 1.4.3
       select build 38 (adf9d5ea-314b-4904-87c0-4839a8d5f616) -> Submit for Review
    2. Google Play — no action. Release 37 is already in Google review; build 38
       is NOT to be submitted as a probe for the listing problem.

Until reviewers act: `APP_REVIEW = PENDING`. If they raise an issue — sign-in,
China/CallKit, completeness or anything else — the response works from their
exact evidence, not from anticipation.
