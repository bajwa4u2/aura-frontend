# Aura 1.4.2 — release certification

**Date:** 2026-09-06
**Release source:** `e8a9a43f` on `main`, tag `v1.4.2`
**Backend at release:** `7d15faa` (deployed to production, healthy)
**Marketing version:** 1.4.2
**Status:** FROZEN. All four platforms have a certified artifact. Windows MSIX
built and exercised; Android built and certified on a physical Pixel 9a; web
certified on live; iOS 1.4.2 (37) built, uploaded, processed and available on
TestFlight. iOS has not been exercised on a physical iPhone.

---

## 1. The baseline, and how it was established

The previous release is `v1.4.1` = `52ff2ee7`, which shipped as build **36** on
iOS and Android and **1.4.1.0** on Windows. No 1.4.2 artifact had ever been
produced: there is no prior 1.4.2 certification record, the AAB on disk was
dated Sep 1 and belonged to 1.4.1, and Partner Center's last accepted package
was 1.4.1.0. **Build 37 and MSIX 1.4.2.0 were both unconsumed**, so no version
number was invented and none was reused.

`v1.4.1..f24d3a1e` is 45 commits. It contains the public composition work, the
Windows desktop composition, the institution visual convergence, the
TR/provenance correction, the shared public and closing state, and the call
system fixes already intended for 1.4.2 (Android Core-Telecom lifecycle,
audio-route selection, call-state truth, presentation reporting). It contains
**no** Aura Meetings external API work, which had not begun.

| Source of version truth | Value |
|---|---|
| `pubspec.yaml` | `1.4.2+37` |
| `aura.exe` FileVersion / ProductVersion | `1.4.2+37` |
| MSIX `AppxManifest.xml` | `1.4.2.0` |
| APK badging | `versionCode='37' versionName='1.4.2'` |
| iOS `Info.plist` | `$(FLUTTER_BUILD_NAME)` / `$(FLUTTER_BUILD_NUMBER)` → 1.4.2 (37) |

Five independent places agree. Nothing is hand-maintained.

---

## 2. A defect found during certification, and fixed before any artifact shipped

The first 1.4.2 MSIX was built, installed and run, and the packaged application
showed a composition defect that had survived code review, the test suite and
the live web deployment.

The public home's discussions section was **indented 185 logical px** relative
to every other section. Measured on the packaged build rather than judged by
eye — left edges in image pixels: hero 447, headline 438, How Aura works 411,
the paid-actions line 409, the discussions section **643**.

Cause: giving that section a reading column was right, but a single `Center`
around the narrower column centred the whole section in the page instead of
seating it on the page's leading edge. Each section was individually correct
and the page had a visible jog.

Fixed at the shared authority (`public_home_screen.dart`), so web, Windows,
Android and iOS all carry it. Repackaged and re-measured: **408** against 409
and 411. This is why `f24d3a1e` and not `7a10dc90` is the release source.

---

## 3. Windows

| Item | Value |
|---|---|
| Artifact | `build/windows/x64/runner/Release/aura.msix` |
| Size | 32,984,560 bytes |
| sha256 | `fe7c583e563f0a39c13492e7332bb4153a8e4e92270293bbc2e3e5ec751dbbe6` |
| Identity | `AuraPlatformLLC.AURAPLATFORM` |
| Package version | `1.4.2.0` |
| Publisher | `CN=3E4027A7-4D4D-4492-B8DE-BBE425E307E5` |
| Display name | `AURA PLATFORM` (the reserved Store product name) |

Packaged with `dart run tool/windows/package_windows.dart`, which is the only
sanctioned command: `msix:create` regenerates the manifest, silently drops the
share-target declaration and still succeeds. The tool opens the finished
package and reads its manifest, and reported *share target declared, with Text,
WebLink, StorageItems*.

**Install of the Store package could not be performed locally, by design.**
`Add-AppxPackage -AllowUnsigned` fails with `0x80073D2C — the package
deployment failed because its publisher is not in the unsigned namespace`. A
package carrying a Partner Center publisher identity must be Store-signed;
only Partner Center can do that. The founder's installed released **1.4.1.0
was left untouched** by the attempt.

**What was exercised instead, and why it is not a substitute for Store
signing.** `AuraPlatformLLC.AURAPLATFORMDEV` is a development-mode registration
whose `InstallLocation` is `build/windows/x64/runner/Release` — the exact
directory the MSIX is packed from. Launching it runs the identical binaries
under a real MSIX package identity. That proves the application; it does not
prove Store signing or the Store upgrade path.

Exercised on the packaged application at 2496×1575 and 1082×1639:

| Path | Result |
|---|---|
| Launch | PASS |
| Public signed-out entry | PASS — new composition, no scoreboard, no chips |
| Sign in | PASS |
| Home | PASS — bar spans the window, composer field, rails aligned |
| Discover | PASS — two-column desktop composition |
| Messages | PASS — real list/detail, no phone-style Back |
| Messages at 1082 | PASS — correctly collapses to one pane, gains New conversation |
| Window resize / restore | PASS — 1100 wide and back to maximised, no overflow |
| Version display / source truth | PASS — see the five-source table above |
| Shared shell | PASS — one `GlobalPlatformShell` across Home, Discover, Messages |

**Not exercised on Windows, deliberately:** the Live control was not clicked,
because activating it starts a public broadcast. That is an outward-facing act
and not something to trigger for a smoke test. Two-party calling was certified
on physical hardware at 1.4.1 and the call architecture is unchanged in a way
that would invalidate it.

**Institution workspace: NOT_EXECUTED.** The reviewer identity holds no
institution membership (`/v1/institutions/me` → 404) and production membership
was not manufactured to produce a screenshot.

---

## 4. Android

| Item | Value |
|---|---|
| Bundle | `build/app/outputs/bundle/release/app-release.aab` |
| Size | 80,441,613 bytes |
| sha256 | `506bb273cd1981147d20f1eaafc98ed2b02a930f94ad6c4ed0aed2bb2d761207` |
| APK (device artifact, same source and config) | `build/app/outputs/flutter-apk/app-release.apk`, 125.3 MB |
| Package | `org.auraplatform.app` |
| versionCode / versionName | **37** / **1.4.2** |
| minSdk / targetSdk | 24 / 36 |
| Signing | `CN=Muhammad Sakhawat, OU=Aura Platform LLC, …` |
| Upload key SHA-256 | `84399254a2a1ca65e235174d06dfea732ab228bbb91a1ce93fd81b24e36d7b8c` |

The signing certificate matches the key recorded for 1.4.1 (`84:39:92:54…`),
so Play will accept the upload against the existing app.

Calling and share capability present in the shipped manifest:
`MANAGE_OWN_CALLS`, `BIND_TELECOM_CONNECTION_SERVICE`, `RECORD_AUDIO`,
`MODIFY_AUDIO_SETTINGS`, `BLUETOOTH_CONNECT`, `USE_FULL_SCREEN_INTENT`,
`POST_NOTIFICATIONS`, `CAMERA`, `WAKE_LOCK`, FCM `c2dm` send/receive, plus
`AuraCallPushReceiver`.

### Physical device certification — PASS

**Device:** Pixel 9a (`53061JEBF08485`, `tegu`), Android 16 / API 36.
Release APK installed over the existing install with `adb install -r`;
the replace succeeded, which is itself proof the signing key matches.

```
versionCode=37  versionName=1.4.2  minSdk=24 targetSdk=36
lastUpdateTime=2026-09-06 03:29:00
```

| Path | Result |
|---|---|
| Launch | PASS |
| Auth / session | PASS — signed-in member session restored |
| Home | PASS — mobile composition: primaries in the bottom bar, header carries identity only |
| Composer | PASS — field treatment adapts to phone width |
| Discover | PASS — single column, correctly adapted from the desktop two-column |
| Messages | PASS — conversation list with group avatars, previews, an institution thread |
| TR / provenance | **PASS — see below** |
| Version display | PASS — drawer reads *Version 1.4.2* |
| Deep links | PASS — see below |
| Calling / OS integration | PASS at the OS boundary — see below |
| Institution surface | NOT_EXECUTED — this account holds no institution |

**TR / provenance is the important one.** The defect the founder reported was
that TR rendered on public Home and not on member Home. On the physical device,
signed in, on the MEMBER feed, the TR mark renders on the media's leading edge,
attached to the image. That is the reported defect closed end to end: backend
projection repaired, client placement repaired, and confirmed on real hardware
against production rather than inferred from an API response.

**Calling, certified at the OS boundary and no further, deliberately.** The
device holds a real person's signed-in session, so no call was placed. What was
verified is the integration this release actually changed — Aura is registered
with Android's Telecom framework:

```
PhoneAccount: ComponentInfo{org.auraplatform.app/org.auraplatform.app}
Capabilities: SelfManaged TransactOps
Audio Routes:  BESW   (Bluetooth, Earpiece, Speaker, Wired)
Extras:        Bundle[{isCoreTelecomAccount=true}]
```

`isCoreTelecomAccount=true` confirms the modern `androidx.core.telecom` path
rather than the deprecated self-managed ConnectionService, and `BESW` confirms
the audio-route capability behind "let a person choose where a call is heard".
Aura sits alongside Gmail and Google Meet, which register through the identical
mechanism. Two-party calling itself remains certified from 1.4.1 on physical
hardware.

**Deep links, verified by Android itself.**

```
auraplatform.org:     verified
app.auraplatform.org: verified
Signature: 84:39:92:54:A2:A1:CA:65:...:E3:6D:7B:8C
```

The signature Android verified the domains against is the release upload key,
matching the APK badging and the 1.4.1 record. Functionally exercised:
`https://auraplatform.org/articles/<slug>` opened Aura directly rather than a
browser and rendered the article with cover, title, byline and body.

`https://auraplatform.org/mission` correctly did NOT resolve to the app. The
manifest claims content and account paths only (`/p/`, `/posts/`,
`/announcements/`, `/articles/`, `/u/`, `/author/`, `/institutions/`,
`/spaces/`, `/meetings/join/`, `/invite/`, `/auth/`, plus four exact paths).
Marketing pages stay in the browser by design; that is scope, not a gap.

---

## 5. iOS

**Nothing was built, and the reason is environmental rather than a defect.**
This is a Windows host. `flutter build ipa` is not merely unavailable, it is
not a subcommand that exists in this toolchain. Archiving requires macOS and
Xcode.

The path is the existing `ios-testflight` workflow in `codemagic.yaml`
(`mac_mini_m2`), which runs `xcode-project use-profiles` and then
`flutter build ipa --release`. It takes build name and number from
`pubspec.yaml`, so it will produce **1.4.2 (37)** with no configuration change.
Build 37 is unused; 36 was consumed by 1.4.1 (Codemagic build #33).

**Configuration check — PASS**, performed from here:

| Item | Value |
|---|---|
| Bundle identifier | `org.auraplatform.app` |
| Version source | `$(FLUTTER_BUILD_NAME)` / `$(FLUTTER_BUILD_NUMBER)` |
| Associated domains | `applinks:auraplatform.org`, `applinks:app.auraplatform.org` |
| App group | `group.org.auraplatform.app` |
| Push environment | `aps-environment: production` |
| Background modes | `remote-notification`, `audio`, `voip` |
| Privacy usage strings | Camera, Microphone, Photo Library (2), Location (2), Tracking |
| Entitlements targets | `Runner.entitlements`, `ShareExtension.entitlements` |

**Known non-blocking limitation: `ios/Runner/PrivacyInfo.xcprivacy` does not
exist.** 1.4.1 shipped and was approved without it, so it is not currently
blocking. It is deliberately NOT created here: a privacy manifest is a set of
claims about what the app collects, and writing one that agrees with the
existing App Store Connect answers without auditing the code would make the
claims look substantiated without making them true. That audit is real work and
belongs to whoever owns the store listings.

### Codemagic #34 and after — what actually blocked iOS

**First attempt failed at `flutter analyze`, not at the tests.** Analyze runs
before them and warnings are fatal there, so the build died at six minutes.
Six errors and two warnings, all from one incomplete deletion: `a41a1b4b`
removed `call_preflight_sheet.dart` on purpose, and two integration tests
still imported it, the full-height sheet census still expected it, and a
CallKit assertion still guarded the workaround the same commit had replaced.
Fixed in `e8a9a43f`. Both gates verified locally with the runner's exact
commands: `flutter analyze --no-fatal-infos` exits 0, and
`flutter test --exclude-tags golden` reports 2521 passing.

**Second attempt reached signing and failed at codesign, which was predicted
in writing.** The Share Extension added in this range gives the project two
signable targets — `org.auraplatform.app` and the embedded
`org.auraplatform.app.ShareExtension` — and both entitlements require the App
Group `group.org.auraplatform.app`. Commit `1339235f` recorded the
consequence when it added the target:

> REQUIRED BEFORE THE NEXT iOS BUILD, and it cannot be done from code: App
> Groups enabled on `org.auraplatform.app` with `group.org.auraplatform.app`
> created, the App ID `org.auraplatform.app.ShareExtension` registered with
> the same group, and both profiles re-fetched. Until then the archive fails
> at codesign.

Neither the second App ID nor the group exists in the portal. This is founder
work in Apple Developer; no repo change fixes it. The commit was made
self-contained on purpose, so reverting the Share Extension restores a project
that signs exactly as 1.4.1 did — that is a scope decision about what 1.4.2
contains, not a technical one.

A secondary item to check if the portal work is done and codesign still fails:
`codemagic.yaml` declares a single `ios_signing.bundle_identifier`, which may
fetch a profile for the main app only and leave the extension unsigned.

### The Apple estate, established 2026-09-06

Done through the authorized Apple Developer session rather than handed back.
Team **MUHAMMAD SAKHAWAT — 4WZQA8T5MT**. State before: two App IDs
(`org.auraplatform.app`, `com.orchestrateops.app`) and **zero App Groups** —
the Identifiers list showed the App Groups empty state, which is why no
profile could be issued for the extension.

| Resource | Action | Result |
|---|---|---|
| App Group `group.org.auraplatform.app` | created | "Aura Platform App Group" |
| `org.auraplatform.app` (id `73VA9G9X9V`) | App Groups enabled + group assigned | Enabled App Groups (1) |
| `org.auraplatform.app.ShareExtension` (id `KW5TXC3RSC`) | registered, explicit, App Groups enabled + group assigned | Enabled App Groups (1) |

**Existing capabilities were preserved, and verified after saving** rather than
assumed. The main App ID still carries `ASSOCIATED_DOMAINS`,
`PUSH_NOTIFICATIONS`, `USERNOTIFICATIONS_COMMUNICATION` and `IN_APP_PURCHASE`
alongside the new `APP_GROUPS`.

One near-miss worth recording: Apple's App Group identifier field pre-fills the
literal prefix `group.`, so typing the full identifier produced
`group.group.org.auraplatform.app`. Caught on the form before submitting.
A wrong identifier here is not easily undone, so the field was cleared and the
suffix appended, and the confirmation screen was read before registering.

Apple warned on save that changing capabilities invalidates existing
provisioning profiles and they must be regenerated. **That warning was taken
too lightly here.** This section originally recorded that regenerating them is
"what Codemagic's automatic signing does on the next run". It is not. Build #37
downloaded the invalidated profile and archived with it, and the failure came
only at codesign. See section 5c.

**CARRY THIS INTO EVERY FUTURE iOS ATTEMPT.** A TestFlight build that fails
PROCESSING consumes its build number permanently. Neither Aura failure reached
upload — one died at analyze, one at codesign, and Codemagic publishes only
after the scripts succeed — so **37 is intact**. But the moment an IPA is
produced and rejected in processing, 37 is spent, and the next attempt is
refused for a reason unrelated to whatever was fixed. Bump the build number
before re-attempting after any failure that reached upload. (Learned from
Orchestrate, which burned 12 exactly this way and shipped on 13.)

### 5c. Behind the estate work: two more faults, neither of them the estate

Establishing the App IDs and the App Group was necessary and not sufficient.
Three further builds were needed, and each failed for a *different* reason, so
each is recorded separately rather than as "signing was broken".

**#36 — the project itself was unreadable.** With the estate in place, `Set up
code signing` dropped from failing to 1s and the build advanced to `Build
signed IPA`, where `xcodebuild` refused the project outright:

> `*** -[NSMutableDictionary addEntriesFromDictionary:]: dictionary argument
> is not an NSDictionary` … `The project 'Runner' is damaged and cannot be
> opened.`

This is the consequence `1339235f` wrote down when it added the Share
Extension target programmatically: *"That proves the reformat lost nothing. It
does not prove Xcode agrees — there is no macOS here."* Two generator faults,
both invisible on Windows because **the file is a well-formed plist and parses
without complaint** — syntax was never the problem:

| Fault | What was written | What it should be |
|---|---|---|
| `TargetAttributes[ShareExtension]` | Python's `str()` of a dict — `"{'CreatedOnToolsVersion': '15.0', …}"`, a **string** where both sibling entries are dictionaries | a dictionary |
| 16 values quoted twice | `productType = "\"com.apple.product-type.app-extension\""` — the identifier *including* quote characters, matching no Apple product type; likewise `sourceTree`, `PRODUCT_NAME`, `TARGETED_DEVICE_FAMILY`, `SWIFT_OPTIMIZATION_LEVEL`, `explicitFileType`, `dstPath`, the copy phase name | singly quoted |

The first is the reported crash verbatim: Xcode merges each `TargetAttributes`
entry with `addEntriesFromDictionary:`, and that entry was not a dictionary.

Fixed in `77a6bb22`. Nothing structural changed — 83 objects, 0 dangling
references, the same three targets, Runner still depending on ShareExtension
and still embedding it into `PlugIns`. Verified on Windows by parsing the file
and then checking value **shapes** rather than syntax, since syntax was never
the problem: every `buildSettings`/`attributes` a dictionary, every
`files`/`buildPhases`/`children`/`dependencies` a list, every `TargetAttributes`
entry a dictionary naming a real target, every product type one Apple defines,
and no parsed string still carrying a quote. #37 then reached **`Xcode archive
done.`**, which is the proof the repair worked.

**#37 — the profile was there and was the wrong one.** Two separate signing
faults, both of which the earlier record got wrong:

1. *Enabling a capability invalidates existing profiles, and CI does not
   notice.* Adding App Groups flipped "AURA PLATFORM App Store Profile" to
   **Invalid**. This document previously said regenerating it is "what
   Codemagic's automatic signing does on the next run". It is not — #37
   downloaded the invalid profile and archived with it, failing only at
   codesign with *doesn't include the App Groups capability* / *doesn't support
   the group.org.auraplatform.app App Group* / *doesn't include the
   com.apple.security.application-groups entitlement*. Regenerated in the
   portal (`78SXU7YZR4`, Edit → Save, form pre-filled) and confirmed no longer
   Invalid in the profiles list.

2. *`ios_signing.bundle_identifier` names ONE bundle id.* The extension is a
   second one and was never fetched. `xcode-project use-profiles` said so and
   **still exited 0**, which is why the miss surfaced two steps later:

   > `- Did not find provisioning profile matching bundle identifier
   > "org.auraplatform.app.ShareExtension" for target "ShareExtension"`

   The fourth error of that build, *"Signing for ShareExtension requires a
   development team"*, is a **symptom** of the same gap: with no profile the
   target keeps `CODE_SIGN_STYLE = Automatic` and no `DEVELOPMENT_TEAM`, both
   of which `use-profiles` sets once a profile exists. It is not a separate
   defect and needs no separate fix.

   This is the "secondary item to check" flagged above, now confirmed. The
   founder's condition for touching signing config — *Runner signs but
   ShareExtension lacks a profile* — is met literally and in writing.

**#38 — the right goal, the wrong instrument.** `341771d1` reached for
`fetch-signing-files`, which fetches profiles *and* certificates with no option
to skip the latter, and saving certificates needs `--certificate-key`, which
managed signing does not hand to build scripts. It died in under a second with
`Cannot save Signing Certificates without certificate private key`, having
created nothing — confirmed by the portal still showing no extension profile.
The certificate was never missing: the managed step already puts it in the
keychain, which is how Runner signed in #37. Corrected in `0a38dc25` to ask for
a **profile and nothing else** (`profiles list --save`, else `profiles create
--save`), which needs no certificate key.

One correction to the reasoning, kept because it changes how the next such
question should be asked: matching is **loose** by default —
`com.example.app` also matches `com.example.app.extension` — so the conclusion
that Codemagic matches strictly rests on behaviour, not on the flag's default:
#36 neither found nor created a profile for an App ID that already existed.
Either way the second bundle id must be named explicitly.

Verified before pushing rather than on the runner, because each round trip is
roughly eight minutes: the generated shell passes `bash -n`, and the three
python one-liners were exercised against representative App Store Connect
payloads — an empty list exits 1 so a profile is created, a populated list
exits 0 so an existing one is reused, and the id extractions return what the
surrounding commands consume.

**#39 and #40 — two lookups written from the wrong name.** `profiles create`
was reached and refused: `argument --certificate-ids: expected at least one
argument`, because `certificates list --type IOS_DISTRIBUTION` matched nothing.
This account holds an *Apple Distribution* certificate, whose App Store Connect
`certificateType` is `DISTRIBUTION`; `IOS_DISTRIBUTION` is the older "iOS
Distribution (App Store and Ad Hoc)" kind. The filter had been written from
what the certificate is called rather than from what Apple calls it. Fixed in
`bb60f4e1`, which also excludes development certificates so a distribution
profile can never be built around one, and exits with a sentence when nothing
matches instead of passing an empty argument two commands downstream.

**#40 proved the extension solved, and isolated the last fault.**
`Aura ShareExtension App Store Profile` was created and applied to
ShareExtension Debug, Profile and Release, and both the *"Did not find
provisioning profile"* and *"requires a development team"* errors disappeared —
confirming the latter was a symptom of the former. What remained was the *main*
app's profile, still rejected for App Groups. Apple's copy was checked rather
than assumed: the App ID reported "Enabled App Groups (1)" and the profile was
Active with App Groups among its capabilities. The machine was simply signing
with content older than Apple's. `cbdaab24` removes the question rather than
reasoning about which copy wins — clear both profile directories, download every
ACTIVE App Store profile fresh, and print what each one actually grants.

**#41 — resolved, and the diagnostic earned its place immediately:**

```
profile: AURA PLATFORM App Store Profile
  app id: 4WZQA8T5MT.org.auraplatform.app
  groups: group.org.auraplatform.app
profile: Aura ShareExtension App Store Profile
  app id: 4WZQA8T5MT.org.auraplatform.app.ShareExtension
  groups: group.org.auraplatform.app
profile: Orchestrate App Store Profile
  app id: 4WZQA8T5MT.com.orchestrateops.app
  groups:
```

Both Aura profiles carry the group; Orchestrate's is downloaded and unused, as
intended, because `use-profiles` matches on bundle id. `Set up code signing`
then made six assignments — two targets across three configurations — and
`Build signed IPA` completed in **4m 10s**, `Publishing` in **1m 27s**.

**Build number 37 is now spent.** The IPA was produced and accepted by App
Store Connect, so the rule recorded above is live from this point: if Apple
rejects it in processing, the next attempt needs a bumped build number, not a
retry.

**Build numbering, as it stood through #36–#40.** None of those produced an
artifact, let alone uploaded one, so 37 remained unspent until #41 — which is
why #41 could reuse it rather than needing 38.

| Gate | State |
|---|---|
| IOS_ARCHIVE_BUILT | PASS — build #41, `Build signed IPA` 4m 10s |
| IOS_DISTRIBUTABLE_ARTIFACT | PASS — signed IPA produced |
| IOS_UPLOADED | PASS — `Publishing` 1m 27s, accepted by App Store Connect |
| IOS_PROCESSED | PASS — Apple processing completed |
| IOS_TESTFLIGHT_AVAILABLE | PASS — 1.4.2 (37), status **Complete**, 2026-09-06 06:50 |
| IOS_PHYSICAL_CERTIFICATION | NOT_EXECUTED — needs a physical iPhone; browser and simulator are not a proxy |

Read back from App Store Connect rather than inferred from the build going
green: the TestFlight iOS build list shows **Version 1.4.2, Build (37),
Complete**, above 1.4.1 (36) and 1.4.0. So **37 was spent but not burned** —
processing accepted it, and the bump-the-number rule was never triggered.

**What is done and what is not.** 1.4.2 exists as a signed, uploaded, processed
iOS build carrying the Share Extension, and it is installable through
TestFlight. It has not been exercised on an iPhone, so the calling, live,
meetings, notification and interaction surfaces remain UNVERIFIED on iOS for
this version — a distinction this document has kept for every other platform
and keeps here. Submission to App Store review is the founder's action, not
mine.

---

## 5b. Operator console and institution workspace — certified on live web

Both had been NOT_EXECUTED on every platform because no identity available to
this session held the standing to reach them. The founder opened a signed-in
Chrome session, which supplied a legitimate operator identity. Navigation only;
no administrative mutation was performed.

### Operator console — PASS

Reached the way an operator reaches it, through the account menu (the door is
drawn by `/v1/admin/entry`, not by a cached flag). Live at `/admin`:

* Context bar reads **Now · Aura operator**, with **Owner · 25** capabilities.
* Areas in the rail: Now, Work, Subjects, Integrity, Platform, Record,
  Discovery — capability-filtered, not a fixed list.
* Content is real: *1 waiting across 1 queue — Product feedback, oldest 6
  days*; *Platform — All services healthy*; a *What changed* audit stream.

**The realm work is confirmed in production.** The platform bar in the console
carries **only the attention bell and the account button**. No search, no Live
pill, no "Add your institution", and no Aura Admin door. On Home, moments
earlier and in the same session, the same bar carried search, bell, Live and
account. One shell, composed by where it stands, which is what the founder
asked for instead of a second shell.

### Institution workspace — PASS, including its refusal

`/institution/dashboard` redirected to `/institution/standing?reason=denied`
and rendered:

> **You do not have access to that** — That part of the institution needs
> authority you have not been granted. Only the institution can change that.
> You still have full access to everything your standing does include.

with a **Go to your institution** action. That is a refusal rather than a
failure: it says what is missing, who can change it, and where to go instead.

**And it is a governance result, not just a screen.** The identity holding it
is an Aura **Owner with all 25 operator capabilities**, and Aura still refused
it the institution dashboard, because platform operator standing is not
institution authority. `AREA_ACCESS_USED_AS_ACTION_PERMISSION = 0`, proven live
across realms — the same principle that was corrected in the announcement
owner controls this cycle, holding independently in the institution shell.

Following the action reached the workspace at
`/institution/<id>/explore`: Public / Member / Internal scope tabs, Topic and
Resources filters, Compose, and an institution post rendering with the OFFICIAL
badge, the Verified Institution mark, *Source: Verified institution*, and
secondary attribution *Posted by Founder · M S Bajwa*. Typography, cards,
chips, accent and spacing are Aura's. That is INSTITUTION_VISUAL_SYSTEM
observed on a real institution surface rather than inferred from the source.

The institution realm's platform bar also carries only bell and account, so the
realm judgement holds in both non-member realms.

---

## 6. Web

The public web was deployed and verified live earlier today at **`7a10dc90`**,
confirmed by content marker rather than by an HTTP 200: every new string was
present in the served bundle and every retired one absent, and all six retired
institution palette literals were gone, which pins the SHA rather than the
version string.

**The deployed web is therefore one commit behind this release baseline.** It
does not carry the section-alignment fix in `f24d3a1e`. That is the single
outstanding action for web parity and it is a founder-triggered deploy.

WEB_RELEASE_BASELINE = RECORDED (deployed `7a10dc90`, release baseline
`f24d3a1e`, one commit of difference, named above).

---

## 7. Shared regression pass

`flutter test` on the release source: **four failures, all pre-existing and
unchanged** across every run in this cycle —
`modal_and_flow_exit_test`, `ios_outgoing_callkit_test`, and two in
`message_interaction_model_test`. No new failures.

Backend `npx jest`: 341 suites, 4328 tests, all passing. No schema change and
no migration in the release backend.

Production API verified after the backend deploy: `/feed/public`,
`/feed/member` and `/feed/institutions/:id/explore` all return matching
provenance (`LIKELY_AI`, credentials true, trace available) where before the
member path returned nothing.

| Area | Result |
|---|---|
| Authentication / session | PASS (Windows sign-in; production `/auth/me`, `/auth/refresh`) |
| Public entry | PASS (Windows signed-out; live web) |
| Home | PASS |
| Discover | PASS |
| Messages | PASS |
| Institution shell | PASS — workspace and refusal both exercised on live web |
| TR / provenance | PASS (production API and rendered on Windows and web) |
| Calling / ringing | OS integration PASS on device; two-party certified at 1.4.1 |
| Audio / video | NOT RE-EXERCISED |
| Deep links | PASS — domains verified by Android, functional open on device |
| Return navigation | PASS (route census regenerated, gates green) |
| Version metadata | PASS (five agreeing sources) |

---

## 8. Freeze

**FROZEN 2026-09-06.** All four platforms have a certified artifact.

```
AURA_1_4_2_RELEASE_SOURCE_SHA = e8a9a43f   (tag v1.4.2)
AURA_1_4_2_BASELINE_TAG       = v1.4.2-baseline   (pins this freeze commit)
AURA_1_4_2_BACKEND_SHA        = 7d15faa    (in production)
MARKETING_VERSION             = 1.4.2
WINDOWS_PACKAGE_VERSION       = 1.4.2.0
ANDROID_VERSION_CODE          = 37
IOS_BUILD_NUMBER              = 37 (spent, processed, on TestFlight)
```

**One release source, verified rather than assumed.** The `v1.4.2` tag was
re-pointed from `f24d3a1e` to `e8a9a43f` earlier in this release, because
`f24d3a1e` could not produce an iOS build at all — it fails the analyze gate —
and a tag that cannot build one platform is not the release source. The
shipped-code delta between those two commits is a single unused import
(`package:flutter/foundation.dart` in `lib/core/media/audio_output_controller.dart`).

iOS was ultimately built at `cbdaab24`, six builds later. That is not a second
baseline: `e8a9a43f..cbdaab24` contains **no change to shipped application
code**. Confirmed by diffing `lib`, `pubspec.yaml`, `pubspec.lock`, `android`,
`windows` and `web` across the range and getting an empty result. Everything in
that span is the Xcode project repair, the Codemagic signing step, tests, and
this document. The four artifacts carry the same product.

| Platform | Artifact | State |
|---|---|---|
| Windows | MSIX 1.4.2.0, `AuraPlatformLLC.AURAPLATFORM` | BUILT, exercised, unsigned by design |
| Android | `app-release.aab`, versionCode 37 | BUILT, certified on a physical Pixel 9a |
| iOS | 1.4.2 (37) | BUILT → UPLOADED → PROCESSED → **TestFlight Complete** |
| Web | `e8a9a43f` | BUILT, certified on live web |

### Still owed, and none of it a product defect

1. **iOS physical certification** — 1.4.2 has never run on an iPhone. Calling,
   live, meetings, notifications and interactions are UNVERIFIED on iOS for
   this version. Installable is not exercised, and neither a simulator nor a
   browser substitutes for the device.
2. **Store submissions** — Partner Center (Windows), Play Closed testing /
   Alpha, App Store review. Founder-actioned by standing arrangement; the role
   here ends at a certified artifact plus instructions.
3. **Web redeploy** at the release source. Live was `7a10dc90` and lacks the
   section-alignment fix of section 2.
4. **Institution dashboard** — still unseen. The identity available holds
   institution MEMBER standing, which Aura correctly refuses the dashboard to.
   Reaching it needs institution admin authority; manufacturing that standing
   in production to look at a screen is not something this session will do.
5. **`store_assets/` is untracked** — roughly 34MB from a separate
   store-listing metadata pass run the same day, including iPhone screenshots.
   Deliberately left out of this baseline: it is not this workstream's work,
   and whether 34MB of binaries belongs in a release commit is a founder call
   rather than an assumption to make quietly.

No Aura Meetings external API code entered this baseline, and none may. That
work begins from the next development state.

---

## 9. Backend advancement after the freeze — 2026-09-06

The freeze is on the CLIENT ARTIFACT. It was never a freeze on the service the
client talks to, and this section records the first advancement past it so the
distinction is written down rather than inferred later from two dates.

```
1.4.2 CLIENT_ARTIFACT_FREEZE   = PRESERVED
PRODUCTION_BACKEND_SHA         = 9716e2d  (was 7d15faa at the freeze)
                                 16991bc -> 267a70f -> 9716e2d, same day
POST_1.4.2_BACKEND_ADVANCEMENT = YES
```

**What PRESERVED means here, checked rather than asserted:** the tags `v1.4.2`
and `v1.4.2-baseline` are unmoved and remain ancestors of `main`. `main` has
commits after them; the tagged commits themselves are byte-for-byte what was
built and submitted. No client artifact was rebuilt, re-signed or re-submitted.

**What advanced:** the Aura Meetings external API (`/v1/external`), plus its
operator provisioning surface. Deployed through a seven-point compatibility
gate against the code actually serving the released clients — recorded in
`aura-backend/docs/2026-09-06-external-api-release-compatibility-gate.md` —
which found the change additive in every dimension a released client can
observe: no route removed or altered, no serialized field removed, no
destructive migration, no permission withdrawn, no route shadowed.

**Verified from production after deploying, not assumed:** health reports the
expected commit; `/v1/meetings`, `/v1/conversations` and `/v1/notifications`
still answer in Aura's internal envelope with `requestId`, `timestamp` and
`path` intact, which is the shape released clients parse.

**One defect found by that verification, and fixed the same hour.** Aura's two
global response shapers were also rewriting every `/v1/external` response, so
the published contract and the running service disagreed on every call — the
OpenAPI document was being served wrapped as `{"ok":true,"data":"openapi:
3.1.0\n..."}`. It is corrected in `16991bc` and re-verified from production.
It never touched a released-client path, and the fix is guarded on both sides
by tests that assert internal routes keep Aura's envelope exactly.

**A second defect, found the same way and larger.** Before provisioning an
external consumer, the operator console was checked for reachability rather
than assumed. A read-only census found ONE active admin grant -- role OWNER --
storing 25 of the catalogue's 29 permissions, because a grant's stored array is
a snapshot of the catalogue at write time and the resolver preferred it to the
role. `SUPPORT_READ` and `SUPPORT_WRITE` had therefore belonged to NOBODY since
whenever they were added, long before this workstream. Founder-approved fix
deployed as `267a70f`, with every other reader of that array corrected in
`9716e2d`. Frozen doctrine: OWNER means the complete CURRENT catalogue.

Worth keeping: a green suite of 4,431 tests did not see it. Asking production
what it actually returns did, in under a minute.
