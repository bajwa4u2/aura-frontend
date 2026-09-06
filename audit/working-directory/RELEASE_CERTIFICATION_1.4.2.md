# Aura 1.4.2 — release certification

**Date:** 2026-09-06
**Release source:** `f24d3a1e` on `main` (pushed)
**Backend at release:** `7d15faa` (deployed to production, healthy)
**Marketing version:** 1.4.2
**Status:** Windows artifact built and exercised; Android artifacts built and
certified on a physical Pixel 9a; iOS not executable from this environment and
awaiting the founder’s Codemagic run.

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
provisioning profiles and they must be regenerated. That is expected and is
what Codemagic's automatic signing does on the next run.

**CARRY THIS INTO EVERY FUTURE iOS ATTEMPT.** A TestFlight build that fails
PROCESSING consumes its build number permanently. Neither Aura failure reached
upload — one died at analyze, one at codesign, and Codemagic publishes only
after the scripts succeed — so **37 is intact**. But the moment an IPA is
produced and rejected in processing, 37 is spent, and the next attempt is
refused for a reason unrelated to whatever was fixed. Bump the build number
before re-attempting after any failure that reached upload. (Learned from
Orchestrate, which burned 12 exactly this way and shipped on 13.)

| Gate | State |
|---|---|
| IOS_ARCHIVE_BUILT | BLOCKED — codesign, see below |
| IOS_DISTRIBUTABLE_ARTIFACT | NOT_EXECUTED |
| IOS_TESTFLIGHT | NOT_EXECUTED |
| IOS_PHYSICAL_CERTIFICATION | NOT_EXECUTED |

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

```
AURA_1_4_2_RELEASE_SOURCE_SHA = f24d3a1e   (tag v1.4.2)
AURA_1_4_2_BACKEND_SHA        = 7d15faa    (in production)
MARKETING_VERSION             = 1.4.2
WINDOWS_PACKAGE_VERSION       = 1.4.2.0
ANDROID_VERSION_CODE          = 37
IOS_BUILD_NUMBER              = 37 (unused, reserved)
```

### Outstanding, all founder-actioned and none a product defect

1. **iOS** — trigger the Codemagic `ios-testflight` workflow against `v1.4.2`.
   It reads the version from `pubspec.yaml`, so it produces 1.4.2 (37) with no
   configuration change.
2. **Windows Store** — Partner Center submission and Store signing. The MSIX
   cannot be signed or sideloaded from here.
3. **Play** — upload `app-release.aab` to the Closed testing / Alpha track,
   which is where 1.4.0 and 1.4.1 went.
4. **Web** — redeploy at `f24d3a1e`. Live is currently `7a10dc90` and does not
   carry the section-alignment fix.
5. **Institution dashboard** — the one surface still unseen. The identity used
   holds institution MEMBER standing, which Aura correctly refuses the dashboard
   to. Seeing it needs an identity with institution admin authority; it is not
   reachable by anything this session should do.

No Aura Meetings external API code may enter this baseline. That work begins
from the next development state.
