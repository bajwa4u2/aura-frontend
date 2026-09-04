# OS Integration Plan — call register and share destination

**Date:** 2026-09-04 · **Status: FOR FOUNDER REVIEW. Nothing here is started.**

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
