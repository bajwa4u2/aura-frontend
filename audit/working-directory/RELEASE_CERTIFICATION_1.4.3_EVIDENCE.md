# Aura 1.4.3 (38) — certification evidence

Recorded as it was produced, 2026-09-09, against the frozen source in
`RELEASE_SOURCE_FREEZE_1.4.3.md`. Every row here is something that was
executed and observed. Nothing is inferred from another platform, and nothing
is promoted to PASS because a related thing passed.

---

## 1. Artifacts, built from the frozen tree

| Artifact | Path | Result |
|---|---|---|
| Android App Bundle | `build/app/outputs/bundle/release/app-release.aab` | built, 76.9 MB, signed |
| Web bundle | `build/web` | built, 42 MB |
| Windows executable | `build/windows/x64/runner/Release/aura.exe` | built |
| Windows MSIX | `build/windows/x64/runner/Release/aura.msix` | built, 33 MB |
| iOS IPA | — | **not built**: needs a macOS host; Codemagic builds from GitHub |

### 1.1 The AAB says what it must say

Read from the packaged release manifest, not from the build script:

    versionCode        38
    versionName        1.4.3
    package            org.auraplatform.app
    minSdkVersion      24
    targetSdkVersion   36
    ABIs               arm64-v8a, armeabi-v7a, x86_64
    signed by          CN=Muhammad Sakhawat, O=Aura Platform LLC (upload key, valid to 2053)

`targetSdkVersion 36` satisfies Play's current target-API requirement.

### 1.2 NEGATIVE PROOF — the certification cleartext allowance cannot reach release

The Android certification variant needs cleartext to a LAN address. The founder
required that allowance to be *structurally* incapable of entering a release
build, not merely absent by convention. Counted in the packaged release
manifest:

    android:usesCleartextTraffic        0 occurrences
    android:networkSecurityConfig       0 occurrences
    org.auraplatform.app.certification  0 occurrences

The allowance lives in `src/debug/` and the suffix in the `debug` buildType, so
the release manifest merge never sees either. Proven by counting the shipped
artifact, not by reading the Gradle file that intends it.

### 1.3 Play Billing — asked, and answered with evidence

The release manifest declares **no** `com.android.vending.BILLING` permission
and `pubspec.yaml` pulls in no billing or purchase package. That is only
acceptable if the app sells nothing on Android. It does not, twice over:

* `InstitutionBillingScreen._purchaseAllowed` returns **false** on both
  `TargetPlatform.android` and `TargetPlatform.iOS`; checkout is web/desktop.
* Production is queried live: `GET /v1/monetization/config` returns
  `"monetizationMode":"disabled"`, so the screen renders its `_DisabledState`
  ("Billing unavailable") and the mobile notice is never reached at all.

So there is no in-app purchase, no external purchase call to action, and no
Play Billing obligation at 1.4.3. The monetization surface is also unchanged
since 1.4.2 — `git log v1.4.2..HEAD -- lib/features/monetization` is empty — so
it is not a 1.4.3 review risk that 1.4.2 did not already clear.

### 1.4 MSIX identity

    Identity Name          AuraPlatformLLC.AURAPLATFORM
    Version                1.4.3.0            (live store package is 1.4.2.0)
    Publisher              CN=3E4027A7-4D4D-4492-B8DE-BBE425E307E5
    DisplayName            AURA PLATFORM      (verbatim — a prior submission
                                               failed certification as "Aura")
    Capabilities           internetClient, runFullTrust
    aura.exe FileVersion   1.4.3+38

---

## 2. THE FINDING THAT GOVERNS THE RELEASE

The 1.4.3 client's registration request was sent to the **live production API**:

    POST https://api.auraplatform.org/v1/auth/register
      -> 400 VALIDATION_ERROR
         "property dateOfBirth should not exist"
         "property jurisdiction should not exist"

Production's global `ValidationPipe` runs with `forbidNonWhitelisted: true`,
and today's deployed backend does not know these fields. **If Aura 1.4.3 (38)
reaches any store before the identity backend is deployed, registration is
broken for every new user on that client.**

The founder's rule was: do not create a period where the backend requires the
new registration request while the only public client is an older build that
cannot send it. This is that rule's mirror image, and it is the reason the
release source is frozen as a *pair* of commits. The backend must be deployed
first, and it must be deployed before — not alongside — any store rollout.

No account was created by this probe: the request was refused at validation.

### 2.1 What else production says about itself

| Probe | Result | Reading |
|---|---|---|
| `GET /v1/auth/me` | returns `accountType`, `emailVerified`, `identityBaselineComplete`; **`admissionBasis` absent** | production is pre-merge, and the 1.4.3 client's "unknown means CONTINUITY, never PROSPECTIVE" fallback is being exercised for real right now |
| `POST /v1/auth/finance/authorize` | `404` | the Finance doorway is not deployed. Finance is dormant, as required |
| `PATCH /v1/users/profile` with `city`, `country`, `websiteUrl` | `200` | the Public Profile Location repair is compatible with **today's** backend |
| `PATCH /v1/users/profile` with an unknown key | `400` | today's backend strips unknown keys and then refuses the empty patch; the merged backend refuses by name. Both refuse. Not a blocker |

---

## 2b. THE FINDING IS DISCHARGED — production cutover, 2026-09-10

§2 was written against a backend that did not yet know the fields. It has been
deployed, and the claim is retired by observation rather than by argument.

    aura-backend  main  d08d2eb..0b92237
    GET /v1/health  build.commit = 0b92237d      <- the deploy marker, queried
                                                     live; Railway's own status
                                                     was not accepted as proof
    12 live checks against the deployed service  ->  12 passed, 0 failed

    aura_final    main  51eabc3e..c1d79e3f
    https://auraplatform.org/version.json  1.4.3 (38)
    flutter_bootstrap.js  Last-Modified  Thu, 10 Sep 2026 03:18:01 GMT
                          (control value  Wed, 09 Sep 2026 06:34:17 GMT, pinned
                           at download time BEFORE the deploy)

The `Last-Modified` control matters because a marker string does not reliably
survive dart2js. To prove the bundle is this release rather than a
same-versioned rebuild, `main.dart.js` was searched for literals only this
release contains:

    "Bajwa Writes" -> https://bajwawrites.com   the corrected footer link
    "/v1/auth/finance/ticket"                   the doorway, ticket leg
    "/v1/auth/finance/destination"              the doorway, address leg
    "/v1/finance/entry"                         the one-bit eligibility probe

all four present, and all three doorway calls routed through the `{ok,data}`
unwrap helper — which is the envelope fix, in production, observable from
outside.

### 2b.1 The registration contract, driven three times on the real form

Not a curl against the API: the actual Join form on `auraplatform.org`, in
Chromium, filled and submitted.

| Date of birth | Declared jurisdiction | Bucket | Floor | Result |
|---|---|---|---|---|
| 2012-09-09 (14) | Germany `DE` | EU/EEA | 16 | **403** `ACCOUNT_AGE_INELIGIBLE` — "You need to be at least 16 to have an Aura account." |
| 2012-09-09 (14) | United States `US` | US | 13 | **201** created → `/verify-pending` |
| 2014-09-09 (12) | United States `US` | US | 13 | **403** `ACCOUNT_AGE_INELIGIBLE` — "You need to be at least 13 to have an Aura account." |

The live payload:

    {"email":…,"password":…,"handle":…,"displayName":…,"firstName":…,
     "lastName":…,"dateOfBirth":"2012-09-09","jurisdiction":"DE",
     "termsAccepted":true,"termsAcceptedVersion":"2026-05-26"}

The middle row is the one that carries the argument. The SAME date of birth is
refused under one jurisdiction and admitted under another, which is the only
way to show that the declared jurisdiction is deciding rather than being
collected and ignored. A field that is captured, transmitted and then not used
looks exactly like a working one until you vary it.

`details.resolvable` is `false` on both refusals, and no account row was
created for either — the refusal happens before any write.

### 2b.2 A DEFECT THE CONTRACT PROOF DID NOT COVER

The backend named the floor. The deployed client showed:

> **Registration failed** — We could not create your account right now. Please
> try again.

The reason was erased and replaced with an invitation to retry, on a refusal
the policy records as `resolvable: false`. "Please try again" on an age floor
is the precise prompt that teaches an applicant to enter a different date of
birth.

Cause: two error mappers in series, each correct alone.
`AuthRepository._mapRegisterError` maps the error CODE to the right sentence;
`RegisterScreen._humanizeRegisterError` then re-maps that SENTENCE through its
own `contains(...)` ladder, matches nothing, and returns the generic fallback.
The same pair on sign-in silently ate two more of the repository's own outputs:

    403 -> "This account is not available right now."   (contains none of
            disabled / locked / suspended / forbidden)
    5xx -> "Something went wrong on our side. …"        (contains neither
            "500" nor "server error")

Fixed by making the already-mapped answer final: an `AuthException` is the
repository's finished sentence and is passed through unchanged, with the old
ladder kept only for raw platform errors.

Covered by `test/auth/auth_error_copy_pair_test.dart` — a real `Dio` adapter
answering with the real production envelope, the real repository, and the real
screen copy, so the test holds BOTH halves at once. 8 tests pass. With the fix
mutated out, **6 fail**; the 2 that still pass are deliberate controls — one
that must keep working, and one asserting an unrecognised error does NOT leak
raw server text, which is the over-correction the fix could otherwise have
introduced.

This is why §2's proof was not enough on its own: it proved the CONTRACT and
said nothing about the SURFACE. Neither repo's green suite could see it,
because each mapper is correct in isolation and only the pair is wrong.

### 2b.3 Authenticated smoke, signed in through the app's own form

Signed in on production as the standing review account and walked every route
the founder named. All resolved; a hard reload kept the session.

| Surface | Route | Result |
|---|---|---|
| Sign in | `/login` | PASS — `201`, landed on `/home` |
| Session refresh | reload `/home` | PASS — still `/home`, still signed in |
| Feed / discovery | `/discover` | PASS |
| Conversations | `/messages` | PASS (routes resolve; no message sent) |
| Meetings | `/meetings/join` | PASS (route resolves; no meeting held) |
| Profile | `/me`, `/me/edit` | PASS |
| Personal Details | `/personal-details` | PASS — DOB stored, jurisdiction unset, and the notice reads "Aura does not have all of these yet. You can add them whenever you like." Admitted, incomplete, never walled |
| Verification | `/verify-identity` | PASS |
| Security | `/security` | PASS |
| Admin | `/admin` | PASS (refusal) — `GET /v1/admin/me` → `403`, redirected to `/home` |

Named deviation: the run drew `429` on `/v1/auth/me` and on a batch of
`/v1/media/:id/url` calls. That is this harness navigating ten routes in under
a minute tripping the production rate limiter — a property of the script, not
of the product. Recorded rather than retried until it looked clean.

### 2b.4 Founder observation, same day

The founder refreshed an existing signed-in session in Chrome, was prompted for
age and country, entered them, and it resolved cleanly. That is the legacy
completeness path on production: an already-admitted member asked to complete,
not walled.

---

## 3. Web — certified

Real Chromium 148, the frozen `build/web` bundle served with a SPA fallback,
talking to the **real production API** (`Config.apiBaseUrl` default, no
dart-define override). Signed in through the app's own form with the founder's
standing review account. No token injection, no planted session.

    POST /v1/auth/login -> 201, landed on /home

**50 routes walked in one session** — 17 public signed-out, 33 member — with
every response recorded. Of 153 API responses, five were not 2xx/3xx:

    2x  401  /v1/auth/refresh      cookie-domain constraint, see below
    1x  401  /v1/users/me          during boot, before the token was held
    1x  401  /v1/discover/people   same
    1x  403  /v1/admin/me          CORRECT: the reviewer is not an operator

The 403 is the authority model working, not a defect.

Observed and deliberate, not a defect: `/safety` and `/trust-safety` both
redirect to `/child-safety`, and `/contact` redirects to `/support/agent`.
These are explicit `GoRoute` redirects, unchanged at 1.4.3. Whether a distinct
Trust & Safety page is wanted for store listings is a founder decision, not an
engineering finding.

### 3.1 Merge blocker 2 — Public Profile Location — CERTIFIED end to end

`City = Canton`, `Country = United States`, `Website = https://auraplatform.org`
were written by a `PATCH /v1/users/profile` carrying the exact payload shape the
1.4.3 client emits, then read back by the client into **two distinct fields**
under "Where you are found", and rendered on the public profile as a composed
`Canton, United States` chip beside a separate website chip. Two fields in, two
fields stored, two fields back, one presentation — no generic `location` string
anywhere in the round trip. Screenshot `f01_edit_location.png`.

Those three fields were set on the review account only to obtain this proof and
have been **reverted to null**, matching the state visible in the walk
screenshot taken before the probe.

### 3.2 Harness constraint, stated rather than hidden

The refresh cookie is issued `Domain=.auraplatform.org`. A bundle served from
`127.0.0.1` can never hold it, so a full document reload signs the session out
and every member route reads as a redirect to `/login`. Navigation in this pass
is therefore client-side (history plus popstate, which this router honours).
This is a property of serving the bundle off-origin. Secure-origin refresh
continuity was proven separately, 12/12, over an HTTPS overlay that left the
production cookie policy untouched — it is not re-proved here and is not
claimed from this pass.

The same constraint explains the console noise: R2 media URLs are presigned and
their CORS allowlist does not contain `http://127.0.0.1:35143`, so images are
blocked in this harness and would not be from the real web origin.

---

## 4. Windows — real desktop, split verdict

The **1.4.3 release executable** was launched on this machine. It booted,
**restored the existing signed-in session from secure storage**, and rendered
live production content: the founder's identity chip ("M S Bajwa · Founder &
Steward · Speaks for Aura"), the pinned announcement dated 2026-09-04, the
composer, and the full Spaces grid. Screenshot `windows_release_boot.png`. That
is real evidence of boot, of session continuity across an app version change,
and of live data rendering on Windows.

**UI interaction is not certified.** Synthetic OS input into the Flutter desktop
window is unreliable here: three scripted clicks on the left navigation
(Discover, Create, Home) produced no navigation at all. This reproduces the
constraint recorded in an earlier pass and is reported as EVIDENCE_LIMITED. It
is not promoted to PASS by inheritance from Web.

---

## 4a. The release PAIR, certified against the merged backend

The isolated certification stack was rebuilt from the merged backend and its
isolation re-verified before anything ran — 8/8, including "User table exists
and is EMPTY (0 rows) before any case runs".

The 1.4.3 client's exact registration payload was then sent to it:

    ELIGIBLE   US, born 1990-01-01  ->  ok: true, account created
    INELIGIBLE US, born 2014-01-01  ->  HTTP 403  ACCOUNT_AGE_INELIGIBLE
                                        "You need to be at least 13 to have
                                         an Aura account."

The same payload that production refuses at validation is accepted here, and
the refusal for an underage applicant is the **exact 403 plus the age-floor
sentence** — the strengthened assertion, which proves the eligibility rule
executed rather than merely that an expected-looking status came back.

Legacy continuity was re-proved on the merged backend: 12/12 checks, including
that a legacy member is admitted by CONTINUITY, that completeness is reported
honestly as false, that the missing fields are named rather than hidden, and
that verification answers by class rather than by a single boolean.

### On Windows, through the shipped computation

    flutter test integration_test/identity_certification_test.dart -d windows
    All tests passed!   (4/4)

    a legacy member is admitted by CONTINUITY
    completeness is reported honestly, not flattered
    and is NEVER held at a completion wall
    an unrecognised admission reads as CONTINUITY, never PROSPECTIVE

These run the real `IdentityState` provider on the real Windows platform, not a
reimplementation of its logic. This is the strongest identity evidence in the
release, and it is the only PASS in the matrix for the shipped computation.

---

## 4b. Android — physical device

Pixel 9a, Android 17 (API 37). The 1.4.3 certification variant
(`org.auraplatform.app.certification`, versionCode 38, versionName
`1.4.3-certification`) was installed **alongside** production Aura and never
replaced it. Production stayed at 1.4.2 (37) with `lastUpdateTime` unchanged at
2026-09-08 23:36 before, during and after.

Signed in by hand through the app's own form against the live production API —
no token injection, no borrowed production credential, no planted session. The
Google Password Manager offer to save the credential was **declined**.

Certified on real hardware: boot and render; sign-in; the home feed with live
production content; the notification runtime permission (granted, verified in
`dumpsys`); the composer with its Ask / Raise issue / Share update modes;
Discover; Messages; the drawer, which self-reports **"Version
1.4.3-certification"**; the profile screen with its identity tabs and no
completion wall; Preferences; and sign-out.

Nothing was published. The device was left as found: the certification variant
was uninstalled and only production Aura 1.4.2 (37) remains.

### What this proves about identity, specifically

Production does not emit `admissionBasis` at all. The 1.4.3 client therefore
took its "unknown means CONTINUITY, never PROSPECTIVE" path — and the member
reached Home rather than a completion wall, on real hardware, against the real
production API. The fallback is not theoretical; it is what is running.

---

## 4c. Housekeeping

Two empty article drafts were created on the review account by the navigation
passes (opening `/articles/write` creates one). Both were deleted. One
pre-existing draft from 2026-08-31 was left alone.

**OWED — one real account exists on production because of the §2b.1 proof.**
The eligible row of that table creates an account, by design; a boundary you
can only observe being refused is only half a boundary.

    email    cert-us-14@auraplatform.org
    handle   certus14
    id       cmtuyzglz0035o20cw0r5cdca
    created  2026-09-10, unverified email, never signed in

The other two rows created nothing — the age refusal happens before any write,
which is itself part of what §2b.1 proves. This one is left in place rather
than removed silently: deleting a member row is an operator action on live
production data, it is the founder's to authorise, and an undisclosed cleanup
would also destroy the evidence that the eligible path completed. Flagged here
so it is removed deliberately, not discovered later.

---

## 5. Not yet executed

iOS at every level — no macOS host here, and Codemagic builds from GitHub, so
it is blocked behind the push. Meetings actually held, realtime media actually
flowing, messages actually sent, institution administration and the operator
console: all EVIDENCE_LIMITED, and stated as such rather than rounded up. Every
store-side action. See `RELEASE_REGRESSION_MATRIX_1.4.3.md` and
`STORE_RELEASE_GATE_1.4.3.md`.
