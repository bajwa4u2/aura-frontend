# Aura 1.4.2 — release certification

**Date:** 2026-09-06
**Release source:** `f24d3a1e` on `main` (pushed)
**Backend at release:** `7d15faa` (deployed to production, healthy)
**Marketing version:** 1.4.2
**Status:** Windows artifact built and exercised; Android artifacts built,
device exercise blocked; iOS not executable from this environment.

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

**ANDROID_RELEASE_DEVICE_EXERCISED = BLOCKED.** No device is attached: `adb
devices` is empty after a daemon restart, and Windows reports no Pixel or ADB
USB device present. This needs the founder to connect the Pixel (or enable
wireless debugging); it is not a product defect and not something to work
around. The installable artifact is built and waiting.

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

| Gate | State |
|---|---|
| IOS_ARCHIVE_BUILT | NOT_EXECUTED — no macOS |
| IOS_DISTRIBUTABLE_ARTIFACT | NOT_EXECUTED |
| IOS_TESTFLIGHT | NOT_EXECUTED |
| IOS_PHYSICAL_CERTIFICATION | NOT_EXECUTED |

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
| Institution shell | NOT_EXECUTED — no institution identity |
| TR / provenance | PASS (production API and rendered on Windows and web) |
| Calling / ringing | NOT RE-EXERCISED — certified at 1.4.1 on physical hardware |
| Audio / video | NOT RE-EXERCISED |
| Deep links | Configuration verified; runtime NOT_EXECUTED |
| Return navigation | PASS (route census regenerated, gates green) |
| Version metadata | PASS (five agreeing sources) |

---

## 8. Freeze

```
AURA_1_4_2_RELEASE_SOURCE_SHA = f24d3a1e
AURA_1_4_2_BACKEND_SHA        = 7d15faa
MARKETING_VERSION             = 1.4.2
WINDOWS_PACKAGE_VERSION       = 1.4.2.0
ANDROID_VERSION_CODE          = 37
IOS_BUILD_NUMBER              = 37 (unused, reserved)
```

No Aura Meetings external API code may enter this baseline. That work begins
from the next development state.
