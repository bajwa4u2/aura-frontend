# Apple build 38 — the actual review state, read from the console

**Date:** 2026-09-11, post-restart recovery
**Authorisation:** founder — *"Restore/check App Store Connect and establish the
actual review state of build 38. This is read-only release-state recovery, not a
new submission. Do not generate build 39 from this recovery pass."*
**Method:** the founder's own App Store Connect session, which survived the
restart. Read only. Nothing was submitted, created, edited or saved.

---

## The recorded state

**As found, 2026-09-11 during recovery:**

    APPLE_BUILD_38 = BUILD_UPLOADED + TESTFLIGHT_BETA_REVIEW
                     NOT SUBMITTED TO APP STORE REVIEW
                     NO 1.4.3 APP STORE VERSION RECORD EXISTS

**As it stands now — SUBMITTED, 2026-09-11 21:25:**

    APPLE_BUILD_38 = APP_STORE_REVIEW_SUBMITTED
                     iOS App Version 1.4.3, build 1.4.3 (38)
                     sidebar: "1.4.3 Waiting for Review"
                     dialog:  "1 Item Submitted"

**Proven by the check this document exists to define** — a version record AND a
History entry, which TestFlight never creates:

    iOS History -> Version 1.4.3
      Waiting for Review        Sep 11, 2026 at 9:25 PM
      Ready for Review          Sep 11, 2026 at 9:25 PM
      Prepare for Submission    Sep 11, 2026 at 8:40 PM

Build 38 was used unchanged. No build 39. No executable content was touched.

### RESOLVED before submission: the App Privacy gap that held it

The submission was prepared to the point of one click and deliberately stopped
there. Every condition the founder set holds except this one, which is not a
condition they could have known to set:

    App Privacy          PUBLISHED 2026-09-05, 8 data types:
                         Email Address, Device ID, Other User Content, Name,
                         User ID, Customer Support, Audio Data, Photos or Videos

    1.4.3 newly collects DATE OF BIRTH and a SELF-DECLARED COUNTRY

Measured, not assumed: `dateOfBirth` appears 12 times in the 1.4.3 registration
screen and **zero times** in the 1.4.1/1.4.2 line; `country` likewise. Identity
documents are NOT new — that feature shipped before, and `Photos or Videos`
already covers it.

So the declaration is **complete as a form and arguably inaccurate for this
version**. It was published six days before this collection existed. Neither
field maps to a declared type; Apple has no "Date of Birth" category, and the
defensible mapping is `Other Data` — `Sensitive Info` is for race, health,
beliefs and biometrics, and `Location` would be actively wrong, since the
country is declared by the person and explicitly never read from the device.

**This was not a call to make on the founder's behalf.** App Privacy is a public
disclosure on the product page about what the company collects, and an
inaccurate one is both a rejection vector and a statement to users. Submitting
first and amending later would mean asserting something not true at the moment
of assertion — so the submission stopped one click short and the founder decided
the classification.

**Founder decision, 2026-09-11:** `Other Data -> Other Data Types`, purpose
`App Functionality`, linked to the user `YES`, used for tracking `NO`. Not
`Sensitive Info`. Not `Coarse Location` — that would claim a device-location
capability Aura does not have, which is a worse disclosure than the omission.

**Executed in this order, deliberately:**

  1. **The policy first, because the declaration has to be true when made.**
     `/privacy` listed account identity as "name, handle, email, phone" and said
     nothing about either field. Two narrow additions shipped
     (`fea60f9d`) and were verified LIVE at
     `https://auraplatform.org/privacy` before Apple was told anything.
  2. **App Privacy updated and published** — now **9 data types**, adding
     `Other Data Types`. Confirmed by reload: *"Published a few seconds ago"*,
     no "finish setting up" warning, `Sensitive Info` and `Coarse Location`
     still unselected.
  3. **Age rating re-verified**, and one answer corrected — see below.

### The age-rating answer that had also gone stale

Checking the September 2026 questionnaire as instructed found the social
capabilities already declared truthfully — User-Generated Content YES, Social
Media YES, Messaging and Chat YES, Advertising NO, Unrestricted Web Access NO,
Social Media Disabled for Users Under 13 NO (correct: Aura does not call
Apple's Declared Age Range API).

**But `Age Assurance` was NO, and 1.4.3 made that false.** Apple's definition is
*"mechanism to confirm an individual's age meets the age requirement for
accessing specific content or services"*, and `auth.service.ts` does exactly
that: registration requires a date of birth and a jurisdiction, runs
`decideAgeEligibility(...)`, and REFUSES the account with
`ACCOUNT_AGE_INELIGIBLE` and a per-jurisdiction `minimumAge` before any write.

Corrected to YES. Nothing else in the questionnaire was touched, and **the
calculated rating did not move: 13+ before and after** — which is the point. It
was a truthfulness correction, not a rating change. Persistence confirmed by
reload (`Age Assurance` radio reads `true`).

## What the console actually shows

**TestFlight → iOS Builds → Version 1.4.3**

    BUILD   38
    STATUS  Waiting for Review          (amber)
            Expires in 90 days
    GROUPS  Aura Platform Exrternal
    INVITES 1     INSTALLS 1     SESSIONS 6     CRASHES –

**Build Uploads**

    1.4.3 (38)   Complete   Sep 11, 2026 2:29 AM
    1.4.2 (37)   Complete   Sep  6, 2026 6:50 AM

**Distribution → iOS App** — the sidebar carries exactly one version:

    1.4.2 Ready for Distribution

The version page is titled **"iOS App Version 1.4.2"** and its Build section
reads `BUILD 37 · VERSION 1.4.2`. Navigating directly to
`/distribution/ios/version/inflight` **redirects to the 1.4.2 deliverable page** —
there is no in-flight version to show.

**Distribution → History (iOS History)** — newest first, and the newest group is:

    Version 1.4.2
      Ready for Distribution   Apple   Sep 8, 2026 4:05 AM
      In Review                Apple   Sep 8, 2026 3:54 AM
      Rejected                 Apple   Sep 7, 2026 7:54 AM
      In Review                Apple   Sep 7, 2026 7:40 AM

**There is no `Version 1.4.3` group in the App Store submission history at all.**

## What this corrects

`RELEASE_CERTIFICATION_1.4.3.md` and commit `515a3e35` both record:

    APP_REVIEW   SUBMITTED — AWAITING APPLE
    submitted    2026-09-11, by the founder

**The console does not support that.** An App Store submission creates a version
record and a History entry; neither exists for 1.4.3. What does exist, and what
is genuinely sitting in a review queue, is the **TestFlight beta** submission.

**The most likely explanation, and it is an easy one to fall into.** Codemagic's
`ios-testflight` workflow submits the build to beta review automatically as the
last step of the lane. The session log for that run records it plainly:

    Submit build 'adf9d5ea-…' to TestFlight beta review
    -- Beta App Review Submission (Created) --
    Beta review state: WAITING_FOR_REVIEW

That is the `betaAppReviewSubmissions` endpoint — **TestFlight's queue, not the
App Store's**. The two use the same words on screen and are different
submissions to different reviewers with different outcomes. "Waiting for Review"
on a TestFlight build says nothing about App Store availability.

**Why the original record could not have caught this.** It says so itself, and
honestly: *"Recorded on the founder's direct statement, which is authoritative;
no re-verification against a console this session has no credential for."* The
record was correctly labelled as unverified. This pass had the console, so it is
now verified — and the answer differs.

The three-state distinction that record introduced — UPLOADED / SUBMITTED /
APPROVED — was exactly the right instinct. It needs a fourth term, because the
gap it missed sits inside "submitted":

    UPLOADED               binary accepted into ASC                     TRUE
    BETA-SUBMITTED         in TestFlight review                         TRUE
    STORE-SUBMITTED        version created and sent to App Review       FALSE
    APPROVED               reviewers acted                              FALSE

## What this does NOT change

  * **Build 38 is still consumed.** Apple has the binary under versionCode 38;
    any further iOS artifact for 1.4.3 needs 39. Acceptance is what spends a
    build number, and acceptance happened.
  * **No build 39 from this pass.** Founder instruction, and nothing here is a
    defect in the artifact.
  * **The artifact is unchanged and still verifies.** `aura.ipa` sha256
    `cc61b21f76aa334b0e4868bafb94e48e43acd1a02dfbaa8e3b97f7f52e9d9d10`,
    re-hashed this session, matches the manifest.
  * **Nothing about Android, the backend, the web deployment or the call
    investigation.**

## What it does change, and it is not small

**1.4.3 is not on its way to the App Store.** It is on its way to TestFlight
testers. If the intent is a public 1.4.3 iOS release, a version record has to be
created and submitted for App Review — a founder action, deliberately not taken
here.

Aura 1.4.3 therefore has **no store distribution in progress on either mobile
platform**: Play production still carries `37 (1.4.2)` with build 38 on no track,
and the App Store still carries 1.4.2 with no 1.4.3 version record.

## Session state, recorded because the last record's staleness is the lesson

    READ AT              2026-09-11, post-restart
    ASC SESSION          SURVIVED the restart — no re-authentication needed
    CHROME               was NOT running; launched for this check
    CRASHED SESSION      restore available and deliberately NOT triggered


---

# THE RELEASE-STATE VOCABULARY — FROZEN, founder 2026-09-11

These exist because "submitted" was used for two different things and a release
was recorded as being in App Review for a day while it sat in TestFlight. Each
term names a state that a DIFFERENT system can confirm. Use them verbatim; do
not coin synonyms.

    BUILD_UPLOADED               the binary is accepted into App Store Connect.
                                 Confirmed on TestFlight -> Build Uploads.
                                 THIS is what spends a build number.

    TESTFLIGHT_BETA_REVIEW       in TestFlight's beta queue. Renders as
                                 "Waiting for Review" — the same words the App
                                 Store queue uses, which is the whole trap.
                                 Codemagic's ios-testflight lane puts a build
                                 here AUTOMATICALLY. Says nothing about the
                                 App Store.

    APP_STORE_VERSION_PREPARED   a version record exists, carries metadata and
                                 has a build attached. Renders as
                                 "Prepare for Submission". NOT submitted.

    APP_STORE_REVIEW_SUBMITTED   "Add for Review" was pressed. A version record
                                 AND a History entry now exist.

    APP_STORE_REVIEW_IN_PROGRESS Apple is reviewing. Visible in iOS History.

    APP_STORE_APPROVED           reviewers approved it. Not yet public if the
                                 release option is manual.

    READY_FOR_DISTRIBUTION       live on the App Store.

**THE ONE CHECK THAT SEPARATES THEM.** An App Store submission creates a VERSION
RECORD and a HISTORY ENTRY. TestFlight creates neither. If the Distribution
sidebar shows no in-flight version, nothing is in App Review — whatever a build's
status badge says.

**Never record a state from a build badge, a lane log, or a recollection of
having pressed submit.** Read the version record.
