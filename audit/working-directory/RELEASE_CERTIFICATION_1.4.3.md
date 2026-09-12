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

## Commits after the freeze — records only

Both branches carry commits made AFTER the frozen commits above. None of them
changes what ships, and that is measured rather than asserted, because a reader
comparing HEAD to the frozen SHA would otherwise be right to suspect drift.

    client   0bfea435..HEAD    0 files under lib/ ios/ android/ assets/ web/,
                               pubspec.yaml, pubspec.lock
    backend  4856728e..HEAD    0 non-spec files under src/,
                               0 under prisma/ or the package manifests

What they add: the release records themselves, the iOS certification result,
the Operator Hub repair and its goldens, and the vendored finance-step-up
contract with its conformance spec. `tsconfig.build.json` excludes
`**/*spec.ts`, so the spec reaches no build output, and `contracts/*.json` is a
vendored reference read by tests rather than at runtime.

**The frozen SHAs above remain the shipping truth.** Anything that would change
that belongs on a branch off the freeze, not on it.

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
    APP_STORE_REVIEW_SUBMITTED  2026-09-11 21:25, verified in the console
                                iOS App Version 1.4.3 · build 1.4.3 (38)
                                "1.4.3 Waiting for Review"
    HISTORY ENTRY               Version 1.4.3 group exists — the check that
                                TestFlight can never satisfy

    EARLIER RECORD, WRONG       "SUBMITTED — AWAITING APPLE", written
                                2026-09-11 on an unverified statement. The
                                build was in TESTFLIGHT BETA review, not App
                                Review, and no version record existed for a
                                day. Found and corrected post-restart; the
                                real submission is the line above.
                                Evidence: APPLE_BUILD_38_REVIEW_STATE.md
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

**Acceptance into App Store Connect is not App Review approval**, and neither is
submission. Three distinct states that are easy to collapse into one: uploaded,
submitted, approved.

**CORRECTED 2026-09-11, post-restart, against the console.** Three states were
not enough, and the missing one sat inside "submitted". Codemagic's
`ios-testflight` lane ends by submitting to **TestFlight beta review**, which
renders as "Waiting for Review" and is a different queue from App Review. For a
day the console showed build 38 there, with no 1.4.3 App Store version record
and no 1.4.3 iOS History entry, while this document said it was in App Review.

The state at the moment of that discovery, and after the submission that
followed:

                      STATE                                    FOUND   NOW
    BUILD_UPLOADED    binary accepted into ASC                  TRUE   TRUE
    TESTFLIGHT_BETA_REVIEW   TestFlight queue                   TRUE   TRUE
    APP_STORE_VERSION_PREPARED  version record + build          FALSE  TRUE
    APP_STORE_REVIEW_SUBMITTED  sent to App Review              FALSE  TRUE
    APP_STORE_APPROVED          reviewers acted                 FALSE  FALSE

The full vocabulary is frozen in `APPLE_BUILD_38_REVIEW_STATE.md`. Build 38 was
submitted UNCHANGED — acceptance is what spends a build number, and no build 39
follows from any of this.

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

    WINDOWS  CORRECTED 2026-09-11. An artifact WAS produced — aura.msix
             1.4.3.0, packaged 05:31, nineteen minutes after this line was
             written. It was then certified 11/11 on the real platform and
             SUBMITTED to the Microsoft Store (submission 1152921505701875307,
             status Certification). See
             WINDOWS_1.4.3_CERTIFICATION_AND_SUBMISSION.md.
             sha256 05c10922ee11b58a8c3f032c692df9adc9ff68d3bb9af2be259ea9bb65289225

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

## Submission

    APPLE   APP_STORE_REVIEW_SUBMITTED — 2026-09-11 21:25, on founder
            authorisation. iOS App Version 1.4.3, build 1.4.3 (38), unchanged.
            "1.4.3 Waiting for Review"; iOS History carries a Version 1.4.3
            group, which is the check TestFlight can never satisfy.
            App Store Connect -> Aura Platform (6772071135)
            build adf9d5ea-314b-4904-87c0-4839a8d5f616

            Held briefly and released only after three gates:
              APP PRIVACY   Other Data Types added (9 types), App Functionality,
                            linked YES, tracking NO. Published and reloaded.
              POLICY        /privacy now states date of birth and declared
                            country and why; shipped and verified LIVE FIRST.
              AGE RATING    social capabilities already truthful; Age Assurance
                            corrected NO -> YES against auth.service.ts.
                            Calculated rating unchanged at 13+.
            See APPLE_BUILD_38_REVIEW_STATE.md.

    PLAY    NO ACTION. Release 37 (1.4.2) is already in Google review. Build 38
            is NOT to be submitted as a probe for the listing problem.

Store submission is the founder's action by standing doctrine, and was also
outside this session's credentials: the Codemagic integration uploaded the build
to App Store Connect, but submitting for App Review is a separate App Store
Connect action for which no key is held here.

**Nothing further is owed on iOS unless reviewers ask for it.** If they raise an
issue — sign-in, China/CallKit, completeness or anything else — the response
works from their exact evidence, not from anticipation, and build 39 is created
only if their finding requires an executable change.

One thing worth having ready rather than discovered under time pressure: the
China/CallKit storefront cases **abstain** on the simulator, so a real China
storefront read is UNPROVEN and must not be claimed to App Review. The
jurisdiction gate's decision table is separately proven — 27/27 native — but
that is the table, not a live storefront observation.
