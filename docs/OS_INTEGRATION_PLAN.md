# OS Integration Plan — call register and share destination

**Date:** 2026-09-04 · **Status: IN EXECUTION.** Founder-approved, decisions resolved.
Track A, the token hardening, and all of Track B (B1–B4) are implemented. Track C is not started.

> **BEFORE THE NEXT iOS BUILD.** Track B3 adds a Share Extension target and an App Group. The
> archive **fails at codesign** until the Apple Developer portal has: App Groups enabled on
> `org.auraplatform.app` with `group.org.auraplatform.app` created; the App ID
> `org.auraplatform.app.ShareExtension` registered with the same group; and both profiles
> re-fetched. Codemagic cannot do any of that from the API key. **If an iOS build is needed
> first, revert the B3 commit** — it is self-contained and the project then signs exactly as it
> did before.

## Execution status

| Item | Code | Proof |
|---|---|---|
| **Track A** — iOS outgoing CallKit | Implemented (`5ffed711`) | 7 invariant gates pass · **device UNVERIFIED** |
| **Security** — secure token storage | Implemented (`22dddae6`, `4a71c817`) | **Windows CERTIFIED** on the real Credential Manager · iOS/Android IMPLEMENTED / UNVERIFIED |
| **Track B1** — governed share intake | Implemented | 22 invariant gates pass · full suite 2415 pass / 6 pre-existing golden diffs |
| **Track B2** — Android share target | Implemented | 15 gates pass · Kotlin **COMPILES** (`:app:compileDebugKotlin`) · merged manifest carries both filters · **device UNVERIFIED** |
| **Track B3** — iOS Share Extension | Implemented | 26 gates pass · project graph diffed object-by-object against the pre-edit file · **no macOS here: build and device UNVERIFIED** |
| **Track B4** — Windows share target | Implemented | 20 gates pass · **runner COMPILES** · **share target verified inside the packed `aura.msix`** · install-and-share UNVERIFIED |
| **Track C** — Android Telecom | Not started | — |

### Track B1 as built

`/share/incoming` — a **separate route from `/share`**, which is the in-app content-first
intention whose audience is fixed by design and explicitly "not a control". Content handed over by
an operating system arrives with no destination and no identity, so both are questions there and
neither may be defaulted; threading a mode flag through one screen to serve both would have been
the page-specific pipeline this track exists to prevent. The two entrances share everything below
the surface — the same `ContentIntake` door, the same `Attachment`, the same composition strip.

| Invariant | How it holds |
|---|---|
| `OS_SHARE_DIRECT_PUBLISH = 0` | The feature contains **no code that can publish** — no HTTP write, no `uploadAuraMedia`, no draft call. A confirmed share is STAGED and the destination's ordinary composer sends it, so there is one publishing implementation rather than two |
| `LAST_USED_DESTINATION_INFERENCE = 0` | Destinations are resolved from the Conversation ledger at the moment of the share. There is no recents list, and the gate fails on the words that would introduce one |
| `LAST_USED_IDENTITY_INFERENCE = 0` | The destination names a `ConsequentialAct`; **C1's `ActingContextAuthority` answers it**. A private acting-identity type was written first and deleted — a second answer to "who am I acting as" is the defect C1 exists to remove |
| `CONTENTINTAKE_BYPASS = 0` | The feature never constructs an `Attachment`. A payload declared `application/pdf` whose bytes are a PNG resolves as `image/png`, and that is asserted |
| `PAGE_SPECIFIC_SHARE_PIPELINES = 0` | No platform branch anywhere in the feature; exactly one route renders the surface; every adapter delivers into one `deliver()` |

**A real hazard found and handled.** A person holds exactly one post draft (`PUT /posts/draft`
upserts it), and the composer's draft load *clears and replaces* both text and attachments. Seeding
a share into it would either be silently wiped by the draft response or silently overwrite
unpublished writing. The public-post destination is therefore offered as **unavailable, with the
reason stated**, while a post is in progress — and the composer skips its draft load when a share
is staged, so the two can never race.

**Not yet reachable by a person.** B1 is the destination; nothing delivers into it until B2/B3/B4
exist. `shareIntakeInboxProvider.deliver()` is the single door every platform adapter will use.

### Track B2 as built

`ACTION_SEND` + `ACTION_SEND_MULTIPLE` on `MainActivity`, **every MIME type enumerated and no
wildcard**. `image/*` would put Aura in the share sheet for SVG, which the backend rejects at five
separate gates; `*/*` would put it there for everything and turn most shares into a refusal nobody
could have predicted. Appearing in the sheet is a promise, so a gate holds the manifest and
`media_mime.dart` to each other in both directions — declared-but-unsupported and
supported-but-undeclared both fail.

**The adapter carries content and decides nothing.** `ShareIntake.kt` classifies nothing, names no
destination, resolves no identity and holds no token; a gate asserts those words are absent from
its code. The class is decided in Dart, from the bytes, by the same `ContentIntake` every other
door uses.

**It copies rather than passing the URI along, and copies rather than reading into memory.** An
Android `content://` grant is scoped to the intent that delivered it — alive now, gone long before
the person has looked at the preview and chosen a conversation. Reading it later is a share that
works in testing and fails as a permission error in someone's hand. And a shared video can be a
hundred megabytes: a file copy is bounded work where a byte array across a method channel is an
ANR. Dart reads the copy when it actually needs the bytes, and the copies are cleared on the way
in as well as released on the way out.

**One channel, and no Dart branch.** `org.auraplatform.app/share_intake`, pulled at cold start and
pushed while warm. A platform that has not implemented it answers `MissingPluginException`, which
is handled as "nothing was shared" rather than guarded against by asking which platform this is —
so B3 and B4 are Swift and C++, not Dart edits.

### Track B3 as built

**The extension is given nothing to be trusted with.** That is what makes capture-only a property
of the build rather than a promise in a comment. Its entitlements file contains one key — the App
Group — and gates assert the absence of `keychain-access-groups`, `associated-domains`,
`aps-environment`, and of `URLSession`, `SecItem`, `accessToken`, `refreshToken` and every
publishing verb in its source. A share extension is a second process, launched by another
application, outside the app the person signed into; a credential there would let Aura publish from
a process the person never opened.

**No compose sheet.** `SLComposeServiceViewController` — the template default — is a text box with
a Post button, and a Post button is a promise to publish. The extension subclasses `UIViewController`,
shows an acknowledgement, and offers no control, because there is nothing here it is allowed to
decide.

**The App Group is transit.** The extension writes content plus a manifest; the app MOVES the files
into its own container and deletes what it found. Two processes can read that container, so
anything left in it stays readable by the one the person did not open. The manifest is written last
and is what makes a share visible, so a share still being written — or one whose extension was
killed mid-capture — is never picked up half-finished. Several shares can be waiting, and they are
drained oldest-first into one envelope rather than overwriting each other.

**It does not reach for a private door to open Aura.** `NSExtensionContext.open` is asked once and
its answer is ignored. The usual way round the restriction is to walk the responder chain until
`UIApplication` appears and call `openURL:` on it — a way past a restriction rather than a use of
the API, on an app already working through an App Store rejection. It is also unnecessary: the Dart
side drains on every resume, so the share is waiting whether Aura opens now or in an hour.

**The Xcode target was added programmatically, not by hand.** The `pbxproj` library round-trips the
file, and the result was verified by diffing the OBJECT GRAPH against the pre-edit copy: **0 objects
removed**, 20 added (exactly the ones created), 6 changed (main group, products group, project
targets and attributes, Runner's sources, Runner's phases and dependencies). The reformat is
therefore lossless. What that does NOT prove is that Xcode agrees — there is no macOS here, so the
first real build is where the target wiring is certified.

### Track B4 as built

Windows delivers a share by ACTIVATING the app with a `ShareOperation`, which is a property of
**package identity** — a loose `aura.exe` is not a share target and never will be. The runner
already records exactly that truth for the WNS push channel, and this follows the same pattern:
WinRT is already linked, and an unpackaged run answers "nothing was shared", which is true, rather
than crashing.

**The manifest declaration is not expressible in `msix_config`, and that is a tool limit rather than
an oversight.** The `msix` package builds its AppxManifest from a fixed template with keys for a
protocol, a file association, an execution alias, App URI handlers, a startup task and a toast
activator — and none for a share target, and no escape hatch. So the declaration is injected between
the two supported commands:

```
dart run msix:build
dart run tool/windows/declare_share_target.dart
dart run msix:pack
```

`msix:pack` packs whatever manifest is present, so this is a supported flow rather than a patch of a
finished package: nothing is unpacked and nothing is re-signed. The step is idempotent, and it is
recorded in `pubspec.yaml` beside the config it compensates for, because a step that lives only in
someone's memory gets skipped — and skipping it ships a package that is silently not a share target.
`dart run msix:create` alone regenerates the manifest and drops the declaration.

**The file types are derived, not listed.** Windows matches a share target on FILE EXTENSION where
Android matches on MIME, so a hand-written list would have been a fourth place the accepted set is
recorded and the first to go stale. The tool reads the extensions straight out of
`inferMimeFromFileName`, and refuses to declare a share target at all if that parse comes back
empty — a target with no supported types would put Aura in the share sheet and then decline
everything.

**Proved as far as this machine allows.** The runner compiles; `msix:build` → inject → `msix:pack`
was run end to end; and the packed `aura.msix` was opened and its manifest read: `windows.shareTarget`
present with 29 file types and Text / WebLink / StorageItems, alongside the pre-existing
`windows.protocol` and `uap3:windows.appUriHandler` — neither displaced. What is NOT proved is
installing that package and sharing into it, which needs the signed Store build.

### Found while doing B2 — the deep-link flag, and what it actually cost

`flutter_deeplinking_enabled` was declared inside the `<receiver>` element, where neither reader
looks: `FlutterActivity.shouldHandleDeeplinking()` reads the ACTIVITY's metadata, and Gradle's
`DeepLinkJsonFromManifestTaskHelper` walks `<activity>` children only.

**Runtime was not broken, and the comment beside it overstated the case.** Disassembling
`FlutterActivityLaunchConfigs.deepLinkEnabled` shows it returns **true when the key is absent**, so
deep linking has been on. What the misplacement did cost is quieter: `outputAppLinkSettings`
reported `deeplinkingFlagEnabled=false`, so the build tooling and the deep-link validator described
this app's configuration wrongly — and a declaration nothing reads would have failed to disable
anything the day someone needed it to. Now declared once, inside the activity; the merged manifest
confirms it.

### What this environment can and cannot prove

Buildable and runnable here: **Windows desktop** and **web**. Not available: **no macOS**
(iOS cannot be built), **no Android device**, no `adb`, no AVD images. iOS and Android work is
therefore reported as IMPLEMENTED / UNVERIFIED and never as PASS, per the governing instruction.

### Release prerequisite discovered

`flutter_secure_storage` was the obvious choice for the token hardening and **failed the Windows
build**: its Windows plugin compiles against `<atlstr.h>` and this machine's Visual Studio 2022
Build Tools has no ATL component — `error C1083`. Adopting it would have added a Visual Studio
component to the Windows release prerequisites in order to compile a file the package no longer
uses at runtime. Rejected; the Credential Manager is reached directly through `win32` FFI instead,
with no native build step. **No new toolchain requirement was added to the release path.**

Two observations, audited rather than assumed: Aura calls do not appear in the phone's call
register, and no other app offers Aura as a share destination. Neither is a defect in something
that exists. Both are integrations that were never built, and one of them cannot work in the
build currently on the App Store.

This plans the durable version of each. It deliberately does not propose the quick version of
any of them, and section 5 says what the quick versions would have been and why they are refused.

---

## 1. What the audit found

| | iOS | Android | Windows |
|---|---|---|---|
| **Incoming call reaches the OS call register** | Yes, from 1.4.0 — **not in the live 1.3.0 build** | No — impossible by architecture | n/a |
| **Outgoing call reaches the OS call register** | **No** — `CXStartCallAction` is never requested | No | n/a |
| **Offered as a share destination** | **No** — no Share Extension target exists | **No** — no `ACTION_SEND` intent-filter | **No** — no `ShareTarget` |
| **Can be opened by a link** | Yes — App Links + `aura://` | Yes — App Links + `aura://` | Yes — `protocol_activation: aura` |

**The live iOS build has no CallKit at all.** `v1.3.0`'s `AppDelegate.swift` contains zero
occurrences of `reportNewIncomingCall`; CallKit arrived 2026-08-29/30 in 1.4.0 (*"iOS gets Apple's
incoming-call architecture instead of a banner"*). Incoming calls will start appearing in Recents
when 1.4.x ships. Outgoing calls will not, because nothing reports them.

**Android rings with a notification, not a call.** `IncomingCallPresenter.kt` uses
`setFullScreenIntent` under `USE_FULL_SCREEN_INTENT`. That is a notification. The dialer's log is
populated by the Telecom stack — `ConnectionService`, `PhoneAccount`, `MANAGE_OWN_CALLS` — none of
which Aura declares.

**Nothing anywhere accepts inbound shared content.** There is no `initialAttachments` seam, no
receive-sharing package, and no composer that can be opened with a payload already in hand. The
platform hooks are the thin part of this problem; the destination is the thick part.

---

## 2. Track A — outgoing calls in the iOS call register

**The smallest of the three, and it completes work that is otherwise done.**

CallKit already knows Aura's calls in one direction. `AppDelegate` holds a `CXCallController` and
a `uuidBySession` map, reports incoming calls, and requests `CXAnswerCallAction` when someone
accepts inside the app. The outgoing half is simply absent: iOS logs a call when the app requests
`CXStartCallAction`, and Aura never does.

**Where it attaches.** `conversation_screen.dart::_startCall` already has the right shape — a
preflight sheet, then `startLive(conversationId, kind:)` returning a `sessionId`, then navigation
into the room. The session id is exactly the key the native side already maps to a call UUID.

**What gets built**
1. A `startOutgoingCall` method on the existing call channel, taking session id, the callee's
   governed display name, and whether it is video.
2. Native: mint a UUID, register it in `uuidBySession`, request
   `CXStartCallAction` with a `.generic` `CXHandle` — matching the incoming side, which already
   refuses `.phoneNumber` because *"mislabelling it puts a fake phone number in the system call
   log."*
3. Report `startedConnecting` when the room reports signalling, and `reportOutgoingCall(with:
   connectedAt:)` when media is established, so Recents shows a real duration rather than a
   zero-length entry.
4. End the call through the existing `endCall` path, which already maps Aura's terminal reasons.

**Constraints that must hold**
- **The jurisdiction gate applies unchanged.** In a prohibited storefront there is no CallKit
  stack, so the outgoing path must place the call exactly as it does today and skip the report.
  `CallCapabilityPolicy` already answers this; the new code asks it the same way the answer path
  does.
- **`answeringLocally` has an outgoing twin.** The existing set exists so a locally-driven action
  is not mistaken for a user tapping the system UI. Outgoing needs the same discipline or the
  provider delegate will act on its own request.

**Cost:** small. One channel method, one native path, no new targets, no new decisions.
**Buys:** parity in the place people look for a call they made — and it closes a gap that will
otherwise be visible the day 1.4.x is approved.

---

## 3. Track B — share into Aura

**The platform hooks are small. The destination is the work, and it is built once.**

A share is content arriving with no context: no conversation, no space, no acting identity, no
statement of what it is. Aura cannot accept that as-is, because three of its frozen rules all bear
on exactly this moment.

### B1 — the governed destination (shared, built first)

A single Dart entry that takes a payload and answers three questions before anything is composed:

- **Where is this going?** A Space, a Thread, a Conversation, a public Post. The person chooses;
  nothing is inferred from a "last used" heuristic.
- **As whom?** C1 is explicit that acting identity is per-act and never route-derived. Someone who
  holds an institution role is not automatically sharing as the institution. If a genuine choice
  exists, the destination asks — the same way the Create hub asks before an announcement.
- **What is it, truthfully?** Every byte goes through `ContentIntake.resolveAndPrepareBytes`, which
  sniffs the real MIME and refuses at the door. This is the same authority that caught voice notes
  declaring `audio/webm` for CAF bytes; a share must not get a private path around it.

This is a new surface with new copy, and its vocabulary is constrained: Person, Space, Thread,
Conversation, Post — never "user", never "upload", never "send to".

### B2 — Android adapter

Smaller than iOS, because the scaffolding exists. `MainActivity` already holds a `MethodChannel`
and overrides `onNewIntent`.

1. `ACTION_SEND` and `ACTION_SEND_MULTIPLE` intent-filters with an explicit MIME allow-list that
   **mirrors `media_mime.dart`** rather than declaring `*/*`. Advertising types Aura will refuse is
   a promise broken in the share sheet.
2. Read the payload immediately. A content URI's read grant is scoped to the intent; deferring the
   read until the person has finished choosing a destination is how a share becomes a permission
   error minutes later.
3. Hand bytes plus the declared type to B1 over a second channel.

### B3 — iOS adapter, and the credential decision it forces

iOS needs a **Share Extension**, which is a second process with its own container. Aura's session
lives in `SharedPreferences` — on iOS, the app's own `NSUserDefaults` — which an extension cannot
read.

There are two ways to resolve that, and they are not equivalent:

| | Approach | Consequence |
|---|---|---|
| ✗ | Put the session in a shared App Group or Keychain access group so the extension can publish directly | A second process holds a credential and can publish on the person's behalf. It also means the extension needs the acting-identity choice, duplicating B1 in a constrained UI |
| ✓ | The extension **captures only** — writes the payload into the App Group container and opens the host app | No credential leaves the app. The extension cannot publish, cannot choose an identity, and cannot be the place a mistake happens |

**The second is the recommendation, and it is a governance choice rather than a convenience one.**
An extension that cannot publish cannot publish wrongly. The cost is one extra tap: the share sheet
hands off, the app opens on the governed destination with the payload already held.

**Related finding, raised not fixed:** the access and refresh tokens are stored in
`SharedPreferences`, not the Keychain. That is out of scope here and does not block anything, but
an App Group is the moment it becomes worth revisiting, because a shared container is a wider
surface than a private one.

### B4 — Windows

MSIX supports `ShareTarget`, and Aura's package already declares `protocol_activation`. Same
destination, same intake, one manifest declaration and an activation handler. Lowest value of the
three and last in order; listed so the plan is complete rather than because it should be built now.

**Cost:** medium, concentrated in B1. B2 and B4 are thin once B1 exists; B3 adds an Xcode target
and an App Group entitlement.
**Buys:** a genuinely different way in. A photo shared straight into a Space is a materially
different acquisition path from "open Aura and upload", and it is the first entry point Aura would
have that begins in another app.

---

## 4. Track C — Android calls in the dialer's call log

**The largest, and the only one that replaces an architecture rather than extending it.**

Appearing in the Android call log means adopting the **self-managed Telecom API**: register a
`PhoneAccount` with `CAPABILITY_SELF_MANAGED`, declare `MANAGE_OWN_CALLS`, implement a
`ConnectionService`, and hand each call to Telecom as a `Connection`. The system then owns the
call's lifecycle, audio routing, and its entry in the log.

**What it displaces.** `IncomingCallPresenter.kt` and its full-screen-intent notification stop
being the ring. That code is not extended by this work; it is replaced by it, and the replacement
must preserve everything the current path learned the hard way — the Android 14 full-screen-intent
grant handling, the terminal-reason mapping, and the presentation-ack behaviour certified on
physical hardware on 2026-09-01.

**What it buys beyond the log.** This is the part that makes Track C worth more than its
line-item: a self-managed connection gets proper audio focus and routing, Bluetooth and car
integration, and interaction with real cellular calls — a native call arriving during an Aura call
currently has no defined relationship to it. A notification cannot participate in any of that.

**What must be checked before committing.** Apple's CallKit restriction in China mainland is
storefront-bound and Aura already models it in `CallCapabilityPolicy`. **Whether an equivalent
constraint applies to Android's self-managed Telecom API in any distribution territory is an open
legal question this plan does not answer.** It should be answered before implementation, not
during, and if the answer is yes then Track C needs a jurisdiction gate with the same shape as the
iOS one — which is an argument for building it after Track A, when that pattern is fresh.

**Cost:** large. New native architecture, a certification pass on physical hardware, and an
unresolved legal question in front of it.
**Buys:** the call log, plus the system-level call behaviour Aura currently has no access to.

---

## 5. What is deliberately refused

- **A `*/*` share filter.** It would make Aura appear for every file type and refuse most of them
  after the person had already chosen it.
- **Publishing from inside the iOS Share Extension.** Faster, and it puts a credential and an
  identity decision in a process built to do neither.
- **Writing to the Android call log directly** via the `CallLog` provider instead of adopting
  Telecom. It would produce entries without producing calls: no audio focus, no routing, no
  relationship to a real incoming cellular call. A row in a table that looks like an integration.
- **Inferring the share destination** from the most recent conversation. It is the behaviour that
  makes a mis-share possible, and Aura's whole position is that a publication knows where it went
  and who sent it.
- **Estimating any of this in hours.** Relative size and dependency are stated; invented durations
  are not.

---

## 6. Sequence, and why this order

1. **Track A — iOS outgoing calls.** Smallest, completes existing work, no new decisions, and it
   establishes the outgoing-call channel shape that Track C will mirror on Android.
2. **Track B1 — the governed destination.** The largest single piece of Track B, entirely in Dart,
   and independent of every native decision below it.
3. **Track B2 — Android share.** Thin once B1 exists, and it validates B1 against a real payload
   before the iOS target is created.
4. **Track B3 — iOS Share Extension.** Needs the App Group decision made in section 3, and is
   worth doing after B2 has proven the destination.
5. **Track C — Android Telecom.** Last, because it is the largest, because it replaces certified
   working code, and because it has an open legal question in front of it.
6. **Track B4 — Windows share target.** Whenever convenient; nothing depends on it.

**None of this blocks the 1.4.2 App Store fix**, and 1.4.2 does not block any of it. Track A is the
only one that touches the release binary, and it can ship in 1.4.2 or later without changing the
plan.

---

## 7. Decisions required before anything starts

1. **iOS Share Extension: capture-only, or credential-bearing?** Section 3 recommends capture-only.
   This is the one architectural decision in the plan that is genuinely a governance judgement.
2. **Does the share destination allow public Posts, or private surfaces only** — Spaces, Threads,
   Conversations? Allowing a share to become a public post makes the acting-identity question
   sharper and the mis-share consequence larger.
3. **Is Track C wanted at all, or is the Android call log an acceptable absence?** The notification
   ring works and is certified. Track C buys the log plus system call behaviour, at the cost of
   replacing that certified path.
4. **Who answers the Android Telecom jurisdiction question**, and before which step.
5. **Order confirmation.** The sequence above is a recommendation, not a constraint. Track B can be
   moved ahead of Track A if a share entry point matters more than call-log parity.
