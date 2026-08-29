# Aura 1.4.0 — Store Release Notes (public-facing)

Version `1.4.0+27`, client commit `b73e8a1` for everything under `lib/`.

The build number moved twice, and neither move changed the app:

* **25 → 26** — version code 25 declared three foreground-service
  permissions Aura never uses, and Google Play will not accept a release
  carrying them without a declaration describing a task the app does not
  perform. 26 removes them.
* **26 → 27** — iOS build 26 delivered successfully and App Store Connect
  returned ITMS-90683, asking for
  `NSLocationAlwaysAndWhenInUseUsageDescription` alongside the WhenInUse key
  already present. The key was added; App Store Connect will not accept the
  same build number twice, so the number moved and both stores get 27.

Every line below still describes 27 exactly as it described 25.

Written to the same shape as `RELEASE_NOTES_1.3.0_STORE.md`: what a person
gets, in the words they would use for it. No internal names, no defect
numbers, and no explanation of how any of it works.

---

## Google Play — Release Notes (500 characters max)

**381 characters. Paste the block between the fences exactly as it is.**

```
What's new in this release:

- Share photos and videos with the people who follow you, in one step.
- Post up to 10 photos or videos, with a cleaner multi-photo layout.
- Edit or delete your own posts without leaving Home.
- Announcements can now be unpublished or removed.
- Reliability fixes to Home, to calls, and to choosing photos from your gallery.

Thank you for using Aura.
```

The 500-character ceiling is per language, and Google counts the blank lines
and the closing line, which is why the measured figure above is the whole
block rather than the bullets alone.

---

## Why each line is here

Kept deliberately short. Every line answers "what can somebody now do, or
what stopped getting in their way" — nothing is listed because it was
difficult to build.

| Line | What shipped |
|---|---|
| Share in one step | Share posts straight to followers; no topic is asked for, because a post to your followers is not a public record |
| Up to 10 | The limit rose from five and now matches what the app will accept, so nothing is uploaded that cannot be posted |
| Cleaner multi-photo layout | Multi-image posts fill their grid instead of sitting as small tiles in empty space |
| Edit or delete from Home | Owner actions on the feed card, so a post can be managed where it is met |
| Announcements | Unpublish and remove reached the app for the first time; both existed on the server and neither could be used |
| Reliability | The Home freeze, the call controls, and photo selection opening a file browser instead of the gallery |

## Deliberately NOT mentioned

- **Anything about calls beyond "reliability".** Realtime is certified on
  Android and on the web, and is NOT certified for desktop receive or for
  iOS. A release note is not the place to imply coverage that does not
  exist.
- **The attachment-limit history.** "Up to 10" is the useful fact. That it
  used to refuse a sixth item after uploading it is our problem, not the
  reader's.
- **Anything about topics.** Compose still asks for one on a public post,
  and saying "no topic needed" without that qualifier would be wrong.

---

## Apple App Store Connect

NOT WRITTEN YET, and deliberately so. iOS certification currently returns
`VERDICT=INCOMPLETE` (zero failures, one suite with no coverage) and the
last run predates this release entirely. Store copy for a build that has
not been certified would be asserting something we have not established.

---

## Release artifacts — what to upload, and how to know it is the right file

Recorded here because both remaining uploads are manual, and "the right file"
is a question a hash answers and a filename does not.

### Windows — Microsoft Store

```
path    build/windows/x64/runner/Release/aura.msix
size    32,798,941 bytes
sha256  9185bbacb15d07de1eb66a91cbd8de430d9a62c6d236480dde657b23169714ca
sha1    e7728371501202719b4bdb256766d1ddc7f611af
```

Package identity, read from the AppxManifest inside it:

```
Name                   AuraPlatformLLC.AURAPLATFORM
Version                1.4.0.0
ProcessorArchitecture  x64
Publisher              CN=3E4027A7-4D4D-4492-B8DE-BBE425E307E5
PublisherDisplayName   Aura Platform LLC
```

`1.4.0.0` is the point: the submission that was refused carried `1.3.0.0`, the
same full name as the package already in the Store with different contents.
Submission 11 currently still holds that 1.3.0.0 package, so it must be
replaced, not merely submitted.

### Android — Google Play

```
path         build/app/outputs/bundle/release/Aura-1.4.0+27-release.aab
size         79,924,075 bytes
sha256       2c52c13b6ff01eb3ab80906267db6e18d3ac3918754a3273d8e1695e88b34686
versionCode  27
versionName  1.4.0
```

Permissions in its merged manifest — read out of the shipped artifact, not
the source file, because the merger is what Play actually reads:

```
ACCESS_NETWORK_STATE  BLUETOOTH  BLUETOOTH_CONNECT  CAMERA  INTERNET
MODIFY_AUDIO_SETTINGS  POST_NOTIFICATIONS  RECORD_AUDIO
USE_FULL_SCREEN_INTENT  WAKE_LOCK
```

No `FOREGROUND_SERVICE*` and no `android:foregroundServiceType` — checked in
the merged manifest, where the only remaining occurrences of those words are
inside the comment explaining their removal.

No `FOREGROUND_SERVICE*`. `USE_FULL_SCREEN_INTENT` stays, because it is really
used — one call site, `IncomingCallPresenter.setFullScreenIntent` on a
`CallStyle.forIncomingCall` notification — and its Play declaration is answered:
core functionality *Making and receiving calls*, pre-grant opt-in *No*, since
the client already degrades to a heads-up notification where the permission is
not granted and opting in would add a second Google review to this release.
