# Aura Meetings — market benchmark

Founder ruling 2026-08-25 §II, §XXXV–§XXXVII, §XLVII. Assessed 2026-08-25
against the reconstructed workspace.

## How this was done, and its limits

Zoom, Google Meet and Calendly are used as **outcome benchmarks**, not design
specifications. The comparison is against their well-established, publicly
documented core capabilities — the expectations a person brings with them. It
does **not** attempt to enumerate their current feature lists, and where a
capability's present state is not something this assessment can verify, it says
so rather than guessing.

§XXXVII governs the whole exercise: *"better than Zoom/Meet/Calendly" does not
mean Zoom features + Meet features + Calendly features + more.* No capability
was added to fill a row in this table.

---

## Outcome matrix

| Aura Meeting outcome | Zoom | Google Meet | Calendly | Aura final state | Classification |
|---|---|---|---|---|---|
| **Understandable availability** | — | — | core capability | Institution availability windows, timezone-aware, consumed from the canonical availability architecture rather than a meeting-local truth | `PARITY` |
| **Public booking without an account** | — | — | core capability | `/meet/:slug`, `/i/:slug/meet/:booking`, slot picker, confirmation | `PARITY` |
| **Reschedule / cancel from the invitation** | supported | supported | core capability | Token-addressed `/meet/reschedule/:token`, `/meet/cancel/:token` — not id-addressed, so a booking link cannot be walked | `AURA_BETTER` (see §1) |
| **Reminders** | supported | supported | core capability | 24h/1h reminder timestamps, canonical notification delivery | `PARITY` |
| **Booking → meeting continuity** | separate products | separate products | hands off to a third party | The booking, the meeting record, the room and the aftermath are **one object with one address** | `AURA_BETTER` (see §2) |
| **Obvious join state** | supported | supported | — | One lifecycle authority resolves record + room, forward-only; capability comes from the backend, never guessed | `AURA_BETTER` (see §3) |
| **Understandable participant state** | supported | supported | — | Invitation and presence modelled separately; seven presence states incl. `disconnected` distinct from `departed` | `AURA_BETTER` (see §4) |
| **Waiting room / admission** | core capability | supported | — | Admission service, guest approval, guest-safe join-error diversion | `PARITY` |
| **Host / co-host authority** | core capability | supported | — | Backend `MANAGE_MEETINGS`; host ≠ institution admin ≠ platform admin; `?isHost=` is a first-frame hint only | `PARITY` |
| **Participant management (mute, remove)** | core capability | supported | — | Host mute request and remove, both now labelled for assistive technology | `PARITY` |
| **Raise hand / reactions** | supported | supported | — | Both present | `PARITY` |
| **Screen sharing** | core capability | core capability | — | Present; transport owned by the A/V chapter | `PARITY` |
| **Recording** | core capability | supported | — | Present, meeting-owned assets | `PARITY` |
| **In-meeting chat** | supported | supported | — | Deliberately **not** a durable chat — see §5 | `AURA_BETTER` |
| **Meeting notes / outcomes** | limited | limited | — | Typed record stream promoting into `MeetingOutcome`: decision, commitment, action, issue, follow-up | `AURA_BETTER` (see §5) |
| **What survives afterwards** | recording + chat log | recording + chat | — | Record, outcomes, assets, **and one canonical Conversation that outlives the event** | `AURA_BETTER` (see §5) |
| **Identity of participants** | display names | Google account | invitee form fields | Canonical Aura person identity; guests honestly external, never conflated | `AURA_BETTER` (see §6) |
| **Institutional context** | account/org | Workspace domain | — | The convening institution is a first-class actor, and a party to the meeting's conversation in its own right | `AURA_BETTER` |
| **Return / navigation integrity** | n/a | n/a | n/a | One canonical `ReturnPathAuthority`; live calls exempt by behaviour, not by domain | `AURA_BETTER` (see §7) |
| **Deep link / cold entry** | supported | supported | supported | Every durable Meetings address renders cold; surface resolved before render; guest-safe diversions | `PARITY` |
| **Accessibility** | mature | mature | mature | Reconstructed this chapter — see §8 | `PARITY`, newly |
| **Cross-platform** | native everywhere | native + web | web | Web, Android, Windows certified; iOS designed-for, **not certified** | `BELOW_BASELINE`, non-release-critical — see §9 |
| **Breakout rooms** | core capability | supported | — | Not implemented, and not required by Aura's product promise — see §10 | `NOT_APPLICABLE` |
| **Live captions / transcription** | supported | supported | — | Transcript job model exists; not a Meetings-workspace capability this chapter built | `NOT_APPLICABLE` this chapter |
| **Polls / Q&A** | supported | supported | — | Not implemented — see §10 | `NOT_APPLICABLE` |
| **Webinar / broadcast** | core capability | supported | — | `LIVE_BROADCAST_SYSTEM = NOT_CURRENTLY_ESTABLISHED` (R-1) — a later chapter | `NOT_APPLICABLE` by ruling |
| **Calendar integration** | supported | native | core capability | Not assessed this chapter | `NOT_ASSESSED` |

**`RELEASE_CRITICAL_BELOW_BASELINE = 0`.**

The one `BELOW_BASELINE` row is iOS certification, which is an execution gap
(no iOS environment on this host), not a product gap — the implementation is
platform-neutral and the thesis is recorded in §9 below and in the platform
matrix.

---

## Why the `AURA_BETTER` claims are claims and not marketing

§XXXV requires each to be proven by product behaviour, not asserted.

### 1. Reschedule and cancel

Aura addresses these by **opaque token**, not by booking id. A person who
receives one cannot enumerate other people's bookings by changing a number in
the URL. The equivalent flows elsewhere are typically id- or account-addressed.
This is a security property that happens to also be a usability one: the link
in the email is the whole credential, so it works without an account.

### 2. Booking → meeting continuity

In the common industry arrangement, scheduling happens in one product, the call
in another, and whatever anybody says afterwards in a third. A person
reconstructs the meeting by remembering which tool holds which piece.

In Aura the booking, the meeting record, the room, the outcomes and the durable
conversation are **one object with one address**. `/meetings/:id` is the same
page before, during and after — and the eight historical aliases that used to
suggest otherwise now redirect to it.

*Proof:* `integration_test/meetings_certification_test.dart` — `/prep`,
`/room`, `/summary`, `/post-meeting` all resolve to one record, certified on
Windows and Android.

### 3. Obvious join state

Mature products show join state reliably. Aura's claim is narrower and real:
**one authority answers it.** Before this chapter, three things did, and they
disagreed — a meeting could be neither scheduled nor active nor ended in the
same frame.

*Proof:* `test/meetings/meeting_lifecycle_test.dart` exhaustively asserts that
for every combination of record state and room status, exactly one of
draft/upcoming/ready/active/concluded is true. 5 × 13 combinations.

### 4. Participant state

Elsewhere, "in the meeting" and "accepted the invitation" tend to collapse into
one list. Aura models them separately, because somebody can accept and not turn
up, and somebody can never reply and be standing in the room.

The distinction that matters most: **`disconnected` is not `departed`.** A
person whose connection dropped keeps their place rather than appearing to have
left.

*Proof:* `test/meetings/meeting_participation_test.dart`,
`test/meetings/meeting_session_boundary_test.dart`.

### 5. What survives

This is the strongest claim and the most specific.

* **In-meeting chat is deliberately not a durable messaging system** (R-3).
  What is said in passing during a call is not the same as a conversation that
  should outlive it, and Aura refuses to pretend otherwise.
* **Typed outcomes.** A meeting's record distinguishes a decision from a
  commitment from an action from an issue from a follow-up, and each promotes
  into a tracked `MeetingOutcome`. A chat log does not do this and was never
  meant to.
* **One canonical Conversation.** The meeting references a real Aura
  Conversation — the same one the rest of the product uses, with the same
  governance — created when somebody actually wants it.

*Proof:* `MeetingConversationAuthority`, 11 backend tests including race
adoption and re-admission; `POST /meetings/:id/conversation`.

### 6. Identity

A participant in Aura is an Aura person wherever Aura can resolve one, and
honestly external where it cannot. The reconstruction removed the two places
where a **member** could be rendered as *Guest* because a payload had not
expanded their person — naming somebody by an external participant type they do
not hold.

*Proof:* `test/meetings/meeting_participation_test.dart` §XI group.

### 7. Return and navigation

No competitor has this problem in the same form, because none of them is a
single product spanning scheduling, meeting, conversation and institution.
Aura's advantage is that leaving a meeting has a *correct* destination at all.

The specific improvement: a meeting record entered from an email used to fall
back to `/home`. It now returns to the meetings it belongs to.

*Proof:* `test/meetings/r4_return_resolution_test.dart`,
certified on Windows and Android.

### 8. Accessibility — `PARITY`, deliberately not `AURA_BETTER`

Meetings had **one** `Semantics` wrapper across 20,281 lines. It now has 12,
plus 27 tooltips, zero unlabelled icon buttons, domain-derived labels, and
tests that assert controls announce their state.

That reaches the baseline mature products have had for years. Claiming
superiority here would be exactly the vague marketing §XXXV forbids.

### 9. iOS

`MEETINGS_IOS_CERTIFICATION = NOT_EXECUTED`. No iOS environment on this host.

The implementation thesis: Meetings introduces no platform-coupled behaviour of
its own. It composes `AuraScaffold` / `GuestShell`, uses no platform channel,
and its geometry is ordinary. The three things that genuinely differ on iOS are
all addressed by shared architecture:

* **camera and microphone** — `NSCameraUsageDescription` and
  `NSMicrophoneUsageDescription` are present in `Info.plist`;
  `DeviceReadiness._deniedRecovery` returns the iOS-correct instruction
  ("Settings › Aura"), and that branch was exercised on Windows returning the
  Windows-correct one, so the platform switch is live rather than theoretical;
* **safe areas and gestures** — owned by the shell, unchanged by this work;
* **audio session and interruptions** — A/V chapter, recorded as debt.

### 10. What Aura deliberately does not have

**Breakout rooms** and **polls** are real capabilities in mature meeting
products and are absent here. That is a decision, not an oversight: Aura's
promise is purposeful, accountable communication with continuity, and neither
capability serves it at this stage. §XXXVII forbids adding them for parity, and
they were not added.

If Aura's product intent changes, they belong in a chapter of their own with
their own justification — not in a table like this one.
