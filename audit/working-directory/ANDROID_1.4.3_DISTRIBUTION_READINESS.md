# Android 1.4.3 (38) — distribution readiness

**Date:** 2026-09-11
**Authorisation:** founder — *"Proceed read-first… Do not publish or start
production rollout yet. Return with one founder boundary only."*

    ANDROID 1.4.3 READY FOR PRODUCTION = NO
    REASON = AURA IS NOT PUBLISHED ON GOOGLE PLAY AND ITS PRODUCTION
             RELEASE IS CURRENTLY IN GOOGLE REVIEW

    NOTHING WAS UPLOADED, PUBLISHED OR ROLLED OUT.
    NO ARTIFACT WAS REBUILT. NO CALL WAS PLACED.

---

## 1. The artifact — EXISTS, VALID, REUSE IT

    path         build/app/outputs/bundle/release/app-release.aab
    sha256       a1887009fc1bff076ae7031111a601dfa0d8fa9b1de6b82f64cdb574dc231fb2
                 == the pin in RELEASE_1.4.3_ARTIFACT_MANIFEST.md
    size         80,741,455 bytes
    built        2026-09-11 03:25:01 EDT

**Read from the artifact's own protobuf manifest, not from `pubspec.yaml`:**

    base/manifest/AndroidManifest.xml   versionCode = 38
                                        versionName = 1.4.3
                                        compileSdkVersion = 36

**Signing — the release upload key, not a debug key:**

    block        META-INF/UPLOAD.RSA
    subject      CN=Muhammad Sakhawat, OU=Aura Platform LLC, O=Aura Platform LLC,
                 L=Canton, ST=Michigan, C=US
    valid        2026-03-12 → 2053-07-28
    SHA256       84:39:92:54:A2:A1:CA:65:E2:35:17:4D:06:DF:EA:73:
                 2A:B2:28:BB:B9:1A:1C:E9:3F:D8:1B:24:E3:6D:7B:8C
                 IDENTICAL to alias `upload` in android/upload-keystore.jks
    jarsigner    "jar verified"

`jarsigner -strict` also reports *"certificate chain is invalid"* and *"signer
certificate is self-signed"*. **Both are expected and are not defects**: an
Android upload key is self-signed by design and has no path to a public CA.
Recorded because a future reader seeing those two lines could easily mistake a
correct artifact for a broken one.

### Source pin — the AAB predates the manifest's commit, and it does not matter

    AAB built at            9ce85c44  (HEAD at 03:25)
    manifest pins client    191642d3  (04:14)
    current HEAD            9b9ba3a2

    shipped-source diff  9ce85c44 → 191642d3   EMPTY
    shipped-source diff  191642d3 → HEAD        EMPTY

(`lib/`, `pubspec.yaml`, `pubspec.lock`, `android/`, `assets/`, `ios/`, `web/`.)

The 73 files that changed between the build commit and the pin are tests,
goldens and records. **So the bundle on disk is the bundle the pinned commit
produces, and the bundle HEAD produces.** Provenance is sound; it is reused.

**One record correction.** The artifact manifest states the AAB size as
`80,741,457 bytes`; the file is `80,741,455`. The sha256 matches exactly, so the
bytes are the pinned bytes and the size line is a two-digit transcription error.
Corrected there.

## 2. Play inventory — versionCode 38 HAS NEVER BEEN ACCEPTED

Read from the Play Developer API:

    bundles      versionCode 1, 3, 24, 25, 27, 35, 36, 37
    apks         none
    38           ABSENT

    tracks       production  37 (1.4.2)   completed
                 alpha       37 (1.4.2)   completed
                 beta        no releases
                 internal    3            completed

    release objects referencing 38 :  ZERO

**This is the opposite of Apple.** On Apple, build 38 is CONSUMED — accepted,
spent, unrepeatable. On Play, **38 is free and unused.** The same number is in
two different states on the two stores, which is exactly the kind of thing that
gets collapsed into one sentence and then acted on wrongly.

## 3. Certification reconciliation — the artifact IS the certified behaviour

The Android certification (`60/60 ×2`, physical Pixel 9a `53061JEBF08485`,
Android 17 / API 37, arm64-v8a) was earned at client commit `26f6e882`.

    shipped-source diff  26f6e882 → HEAD

    lib/core/continuation/acquisition_contract.dart   | 15 +++++++++++++++
    1 file changed, 15 insertions(+), 0 deletions(-)

Measured rather than asserted, over every added line in `lib/`:

    ADDED executable lines : 0
    REMOVED lines (any)    : 0

All fifteen are documentation comments — and their subject is, fittingly, the
Play 404 cause. **The certified behaviour and the artifact's behaviour cannot
differ**, so re-running the 60 lanes would re-prove a premise already proven
identical. That is why they were not re-run: the founder asked for only what is
necessary, and this is the thing that makes the rest unnecessary.

## 4. What WAS re-verified, because it could have moved

**The backend moved under the certified client** — `0b92237d` → `07dcd29b` →
`3f64c17` → `725f5d6d`. A client is certified against a server generation, and
that generation is gone, so the shipped binary's contract was re-checked.

**The moderation refusal change is wire-compatible with the released client.**
`report_repository.dart` returns the body without inspecting it, and
`report_content_sheet.dart` catches every error and renders one fixed string —
it never reads `error.code` or `error.message`. So changing the refusal text
could not break 1.4.3. *(Aside, not a blocker: that fixed string is "Could not
submit. Please check your connection and try again.", shown for a refusal that
has nothing to do with the connection. A real refusal reaching the person as a
network excuse is worth fixing in a later release.)*

**Live against production `725f5d6d`:**

    monetization        monetizationMode=disabled, all packs credits=0/price=null,
                        stripe/appleIap/googlePlay/windowsStore all enabled=false
                        -> the store-compliant state HOLDS; the steering copy
                           stays unreachable
    bootstrap surfaces  /v1/auth/me, /v1/notifications, /v1/institutions/me,
                        /v1/conversations, /v1/meetings  -> 401 (alive, refusing)
                        control /v1/definitely-not-real  -> 404
    age eligibility     DOB 2020-01-01 -> ACCOUNT_AGE_INELIGIBLE,
                        "You need to be at least 13 to have an Aura account."
                        missing DOB    -> VALIDATION_ERROR, calendar-date required
    version             pubspec 1.4.3+38 == artifact manifest 38 / 1.4.3
    release notes       Play short form 437 chars (limit 500)

**A side effect I caused and reversed, recorded rather than quietly cleaned.**
Probing the age gate with eligible dates of birth did what the product is
supposed to do: it CREATED TWO ACCOUNTS in production. They owned nothing —
0 posts, 0 messages, 0 conversation messages, 0 reports, 0 memberships — and
both rows were deleted immediately, leaving zero `@reachability.test` users.
**The refusal cases were the only ones that needed probing**; they create
nothing by design, and the eligible cases should never have been sent.

## 5. THE BLOCKER — Aura is not published on Google Play

    public listing  https://play.google.com/store/apps/details?id=org.auraplatform.app
                    -> HTTP 404
    control (live)  com.google.android.gm          -> HTTP 200
    control (fake)  org.auraplatform.notreal       -> HTTP 404

The positive control is the point: the check discriminates, so the 404 is a
fact about Aura and not about the method.

**Play Console, read today rather than recalled:**

    Aura          org.auraplatform.app     11 installed   Closed testing
                                                          In review   Sep 10, 2026
    Orchestrate   com.orchestrateops.app    5 installed   Production

    Production checklist                   4 of 5 complete
      check  Select countries and regions
      check  Create a new release
      check  Preview and confirm the release
      check  Send the release to Google for review
      ----   Publish your app on Google Play        <- OUTSTANDING

    Publishing overview  "Your changes are now in review. We may find
                          additional issues when reviewing your app."
                         Managed publishing: OFF

**Orchestrate is the internal control.** Same developer account, same day, and
it reads `Production`. So this is not an account-level block, not a missing
agreement, and not developer verification — it is specific to Aura's own
pending review.

**And this is why 38 must not be uploaded to production yet.** Google is
actively reviewing the production track. Adding a release to a track under
review changes the thing being reviewed, and managed publishing is off, so
nothing would hold it back for a second look. The correct move is to let the
current review resolve.

## 6. Prepared, not published

    artifact          the existing signed AAB 38 — no rebuild
    target track      production
    rollout           full (matching how 37 was configured); staged rollout is
                      available if the founder prefers it
    release notes     RELEASE_NOTES_1.4.3_STORE.md, short form, 437/500 chars
    listing metadata  present and unchanged; no 1.4.3 listing change is needed
    content rating    present; no capability changed on Android in 1.4.3
    policy declarations  App content shows "You're all caught up" — nothing
                         outstanding, nothing flagged by Play

### The one item NOT verified, and it must be before release

**Data safety per-type content was not read.** The declaration exists and Play
flags nothing, but the wizard would not jump to a completed step, and walking it
with `Next` would edit a declaration **currently under Google review**. So it
was left alone.

This is not a neutral gap. **The Apple analogue was wrong for exactly these two
fields**: App Privacy had been published before 1.4.3 began collecting a date of
birth and a self-declared country, and neither was declared until it was fixed
today. Play's Data safety is the same kind of statement, made once, that a new
version can silently falsify. It must be read — and if it omits them, corrected
the same way (**not** as Location; the country is declared by the person and
never derived from the device) — before any production release.

### Also untested, and worth naming

**The 37 → 38 update path.** Every Android certification to date has been a
clean install. Eleven closed-testing users are on 37 and would be the first to
take the update. Nothing suggests a problem — no schema-breaking client change —
but "nobody has run it" is the honest status.

---

## The boundary

    ANDROID 1.4.3 READY FOR PRODUCTION = NO

**Not because of the artifact, and not because of the code.** The bundle is
valid, signed, version-correct and provably the certified build; versionCode 38
is free on Play; the backend is compatible with the released client. Every part
of the release that is Aura's to get right is ready.

It is NO because **Aura has never been published on Google Play**, its
production release has been in Google review since 2026-09-10, and the Console's
own checklist still lists *"Publish your app on Google Play"* as the outstanding
step. A production release of 1.4.3 cannot precede the app existing on the
store.

    FOUNDER ACTION REQUIRED = NONE THAT WOULD HELP YET

The gate is Google's, not ours. When the current review resolves and the app
reaches Production, the remaining work before 1.4.3 ships is small and named:
read Data safety against what 1.4.3 collects, then upload the existing AAB 38,
attach the 437-character note, and authorise the rollout.
