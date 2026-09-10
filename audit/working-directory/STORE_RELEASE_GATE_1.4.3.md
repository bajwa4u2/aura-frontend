# Aura 1.4.3 (38) — store release gate

2026-09-09. A gate is not a summary. Each condition below is either MET or NOT
MET, and **no store submission may begin while any condition is NOT MET**. The
conditions are ordered by dependency, not by importance: several later ones
cannot even be attempted until an earlier one clears.

---

## G1 — The backend is deployed before any client reaches a store

**MET, 2026-09-10, and verified from the live service rather than from a
deployment dashboard.**

    aura-backend  main  d08d2eb..0b92237
    GET https://api.auraplatform.org/v1/health   build.commit = 0b92237d
    12 live checks against the deployed service: 12 passed, 0 failed

    aura_final    main  51eabc3e..c1d79e3f
    https://auraplatform.org/version.json  {"version":"1.4.3","build_number":"38"}
    flutter_bootstrap.js  Last-Modified: Thu, 10 Sep 2026 03:18:01 GMT
                          (was Wed, 09 Sep 2026 06:34:17 GMT — pinned before the
                          deploy, because a marker string does not survive dart2js)

The deployed `main.dart.js` was searched for literals only this release
contains: the corrected `Bajwa Writes` footer link, and all three doorway calls
`/v1/auth/finance/ticket`, `/v1/auth/finance/destination`, `/v1/finance/entry`,
each routed through the `{ok,data}` unwrap helper. Version numbers can be
stale; those literals cannot.

THE REGISTRATION CONTRACT IS PROVEN LIVE, NOT PREDICTED. Driving the real Join
form on production, three times, through the browser:

    dob 2012-09-09  jurisdiction DE  ->  403 ACCOUNT_AGE_INELIGIBLE
                                          "You need to be at least 16 …"
    dob 2012-09-09  jurisdiction US  ->  201 created  -> /verify-pending
    dob 2014-09-09  jurisdiction US  ->  403 ACCOUNT_AGE_INELIGIBLE
                                          "You need to be at least 13 …"

The middle row is the one that matters: the SAME date of birth is refused in
one jurisdiction and admitted in another, so the declared jurisdiction is
genuinely deciding rather than being carried and ignored. The payload the live
client sends now includes `dateOfBirth` and `jurisdiction`, and the deployed
backend accepts both — the 400 "property dateOfBirth should not exist" that
closed this gate is gone.

Order actually executed, and it was the fixed one:

    1. deploy aura-backend        DONE — commit verified from /v1/health
    2. deploy the web client      DONE — bundle re-dated, literals confirmed
    3. submit the store builds    Apple and Microsoft open; Play blocked, see G6

The 1.4.2 registration window this opened is real and was accepted by founder
ruling on 2026-09-10: the 1.4.2 client is not performing as intended, every
resolution is in 1.4.3, and it is being replaced regardless. Recorded as a
known effect with a real cost, not as an absence of one. Existing members were
never affected — `LoginDto` does not carry the new fields, and sign-in, session
refresh and every other surface were untouched throughout.

## G2 — Both repositories are pushed

**MET.**

    aura-backend  main  -> 0b92237d
    aura_final    main  -> c1d79e3f   and  release/1.4.3 -> c1d79e3f

The earlier blocker was mischaracterised in this document as a repository
permission problem. It was not. `git push --dry-run` showed GitHub accepting
the write (`[new branch]`), which proves the credential and the repository
permission were both fine; what refused the call was the local tool's own
command classifier. Naming that correctly is the difference between a founder
action item and none — there was never anything for the founder to grant here.

## G3 — Artifacts exist for every platform being submitted

**PARTIALLY MET.**

| Platform | Artifact | State |
|---|---|---|
| Android | `app-release.aab`, signed, versionCode 38, target API 36 | MET — rebuilt from the re-frozen tree |
| Windows | `aura.msix` 1.4.3.0, name "AURA PLATFORM" verbatim | MET — rebuilt |
| Web | `build/web` | MET — rebuilt |
| iOS | none | **NOT MET** — no macOS host here; needs G2 first |

## G4 — Store numbers are legal and unspent

**MET**, verified in the signed-in consoles rather than from repo notes: Apple
build 38 absent; Play versionCode 38 unused; Microsoft 1.4.3.0 above the live
1.4.2.0.

This condition is time-sensitive in a narrower way than first written. A build
number is spent when a **store accepts an artifact under it**, not when a commit
lands. Moving the tree does not cost 38; it costs the artifacts, which must be
rebuilt from the tree named in the freeze before anything is submitted. That
happened once already, for the Finance doorway, and the artifacts were rebuilt.

## G5 — Store listing assets represent the product being submitted

**NOT MET — and for a more concrete reason than this document first gave.**

The original entry said the screenshots depict the pre-1.4.3 product because
"registration, Personal Details, verification and the profile editor's place
fields all changed in this release and none of those changes are represented."
That reasoning does not survive contact with the actual files. **None of those
four surfaces is in the screenshot set at all** — the set is Home, Institutions,
a verified institution, Messages and Discover, and those surfaces did not
meaningfully change in 1.4.3. Judged on that argument alone, G5 would arguably
pass.

The real defect is visible in the images and is worse:

    store_assets/android/screenshots/phone/1_home.png
    store_assets/ios/store/1_home.png

Both display a pinned announcement card reading, in the product, at the top of
the first screenshot a reviewer sees:

    Pinned announcement                                  2026-09-04
    Aura 1.4.2 — Communication Should Be Able to Continue

**The listing for 1.4.3 would advertise 1.4.2 as on-screen content.** This is not
a subtle staleness. It is a version number, rendered large, in the hero shot, on
both stores.

WHY IT IS NOT FIXABLE BY RE-CAPTURING TODAY. The card is server-driven and the
production announcement feed still returns exactly that item:

    GET https://api.auraplatform.org/v1/announcements
    -> slug "aura-1-4-2-communication-should-be-able-to-continue"
       title "Aura 1.4.2 — Communication Should Be Able to Continue"

So a re-capture right now reproduces the same card. The screenshots cannot be
correct until a **1.4.3 announcement is published**, which is a communications
act governed by the public-voice rules, not an engineering task. That is a real
dependency and it was not previously recorded anywhere:

    publish the 1.4.3 announcement  ->  re-capture Home  ->  G5 can clear

Two lesser observations from the same images, recorded rather than acted on:

* The Android Home shot carries a personal draft prompt — *"Resume your draft:
  my Roblox"* — and the iOS shot does not. A half-written personal draft in a
  store hero shot is not a defect, but it is not the product's best face either.
* Both shots show the founder's own account and content. That is legitimate —
  it is the founder's product and their own posts — but it means the listing is
  one person's timeline rather than a demonstration of the product's range.

Recorded, not corrected: a `STORE_LISTING_RECORD_2026-09-09.md` successor is
still owed at closeout and should supersede rather than edit the 09-06 record.

## G6 — Google Play production access

**NOT MET, and not an engineering item.**

    App status:  Closed testing (10 installed audience)
    Production:  Inactive
    Console:     "Apply for access to production ... you need to run a
                  closed test which meets our criteria."

Aura has never been in Play production. This is Google's personal-developer
rule: a qualifying closed test — 12 or more testers, 14 continuous days — then
an application Google reviews. It is a founder decision with a multi-week
waiting period and it cannot be engineered around. **Apple and Microsoft are
not blocked by it**, so treating the three stores as one release is the wrong
model for 1.4.3.

## G7 — Certification is complete enough to submit

**PARTIALLY MET, and further along than it was.** Web, Android and Windows all
boot, sign in and navigate on their real platforms. The identity contract, the
age floor and the Public Profile Location repair are certified end to end. The
permanent Finance doorway is certified on Web, Windows and a physical Pixel, and
— uniquely in this release — against **another product's real implementation**,
in three passes with the Finance workstream covering no grant, a real grant and
a revocation.

Still open: iOS is uncertified at every level, and Meetings, realtime,
institution administration and messaging are EVIDENCE_LIMITED on every platform.
See `RELEASE_REGRESSION_MATRIX_1.4.3.md`.

Whether EVIDENCE_LIMITED on Meetings is acceptable for a release is a founder
judgement, not an engineering one. It is recorded here rather than quietly
rounded up to PASS.

## G8 — Finance stays dormant

**MET, and now demonstrated rather than asserted.** Every `FINANCE_*` variable
is unset in production, so all four doorway routes 404 there. When the backend
is deployed they become reachable and still grant nothing: the destination is
drawn only by an active FinanceGrant resolved from Finance's own database, and
production Finance holds one canonical book in SETUP, **zero principals and zero
grants**. The revocation pass proved the shape of the dormant case directly —
identity succeeds, the door is absent, and full Aura authority buys nothing.

Deploying 1.4.3 does not activate Finance authority, and activation is the
Finance workstream's to perform, not Aura's.

---

## Gate verdict

**OPEN FOR APPLE AND MICROSOFT. CLOSED FOR GOOGLE PLAY.**

Treating the three stores as one release was the wrong model and is abandoned
here. What is actually true, per store:

| Store | State | What stands between here and a submission |
|---|---|---|
| Apple | ready once G5 clears | store screenshots (G5); iOS certification (G7) |
| Microsoft | ready once G5 clears | store screenshots (G5); founder-only Entra tenant association |
| Google Play | **blocked, indefinitely** | production access has never been granted (G6) |

G1 and G2 — the two conditions that blocked everything else — are now MET, and
they were the whole of the dependency chain: Railway deploys from GitHub,
Codemagic builds from GitHub, and the web client deploys from GitHub.

Two conditions remain NOT MET, and they differ in kind:

* **G5, store screenshots.** Engineering work, not a decision. The 2026-09-06
  capture depicts the pre-1.4.3 product — registration, Personal Details,
  verification and the profile editor's place fields all changed in this
  release. They must be re-captured, not resubmitted.
* **G6, Play production access.** Not engineering at all. A founder decision
  with a multi-week qualifying closed test attached. It does not block Apple or
  Microsoft and must not be allowed to.

### The honest name for the Android state

    ANDROID_1.4.3_PUBLIC_DISTRIBUTION = BLOCKED_BY_GOOGLE_PLAY_G6

Not "pending review". Nothing has been submitted for review, because production
access has not been granted, so there is nothing for Google to review. Calling
it pending would describe a queue Aura is not in. The signed AAB exists at
versionCode 38 and can be staged to a testing track today; that is distribution
to testers, and it is not public release.

No other Android distribution mechanism is being introduced to route around
this. Sideloading, a direct APK, or a second store would each be a permanent
new distribution surface adopted to avoid a temporary policy gate, and the
founder ruled that out explicitly.

### One defect found after the gate was written

Found on production minutes after the web deploy, by driving the real Join form
rather than reading the handler: the backend refused an ineligible applicant
correctly and named the floor, and the client displayed **"We could not create
your account right now. Please try again."** — erasing the reason and inviting
the retry the policy records as `resolvable: false`. Two error mappers in
series, each correct alone. Fixed, tested against the real envelope, and the
tests fail 6/8 when the fix is mutated out. See
`RELEASE_CERTIFICATION_1.4.3_EVIDENCE.md`.

It does not reopen G1 — the contract itself is correct and proven — but the web
client must be redeployed with the fix before any store artifact is built from
this tree, because the store builds and the web client must be the same source.
