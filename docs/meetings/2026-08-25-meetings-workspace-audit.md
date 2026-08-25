# Meetings Workspace — reconstruction audit and implementation plan

Founder ruling 2026-08-25 (48 sections). **This document is measurement,
analysis and planning only.** No Meetings, A/V or Live code was modified. The
ruling's instruction is quoted here because it governs everything below:

> This task does NOT yet authorize substantive Meetings implementation. Do not
> begin fixing/reconstructing Meetings merely because a defect is obvious. We
> want one authoritative measured baseline before implementation begins.

Nothing in §23 has been executed. The chapter stops at §26 and waits.

---

## 1. Method, and what would make this baseline wrong

Everything below is counted from the working tree, not recalled. Route facts
come from `lib/router.dart` parsed for `path:`/`builder:` pairs and cross-checked
by hand where the parser was ambiguous; dependency facts from import edges;
state facts from `ref.watch`/`ref.read`/`setState` counts; test facts from the
files themselves.

One number reported earlier in this chapter's working notes is **corrected
here**: "19 protected Meetings/Live surfaces without a return affordance" was an
attribution artefact. Re-measured: **22 presentation files**, of which 10 draw
their own affordance and 12 draw none — and of those 12, five are not
destinations at all (a presenter, a status chip, a router entry, an overlay, a
lifecycle host), and three more are call surfaces where no Back is correct.
**Four real destinations** offer no way back. See §14.

Where a claim is inference rather than measurement it is labelled
**(inference)**.

---

## 2. Size of the thing

| | client | backend |
|---|---|---|
| files | 43 meetings-related `.dart` | 13 `.ts` (excl. specs) |
| lines | **20,281** | **8,278** |
| largest unit | `meeting_live_room_screen.dart` **3,934** | `meeting.service.ts` **2,666** |
| controllers / screens | 22 presentation files | 2 controllers, **47 endpoints** |
| tests | 23 meeting-related files | 8 spec suites |

Client top five: live room 3,934 · institution availability 1,380 · create
meeting 1,274 · meetings home 1,125 · meeting detail 1,095.

---

## 3. Boundary matrix

The ruling requires the four systems be kept apart. They are **not** four
systems in the code today.

| owner | what it actually owns now | evidence |
|---|---|---|
| **MEETINGS WORKSPACE** | scheduling, availability, booking (public + institution), invitation and admission, participant graph, RSVP, the meeting record, outcomes, assets, meeting-scoped guest identity | `lib/features/meetings/`, `src/meetings/` |
| **SHARED SYSTEM** | routing, shell chrome, auth/session, media custody, notifications, institution authority, identity resolution | `core/`, `features/institutions/`, `src/auth`, `src/media` |
| **A/V CALL SYSTEM** | transport, signalling, media capture and negotiation, call lifecycle, room UI for non-meeting surfaces | `lib/features/realtime/`, `src/realtime/` |
| **LIVE BROADCAST** | — **does not exist** — | no `lib/features/live/`, no `src/live/` |
| **UNCLEAR / REQUIRES RULING** | the live room itself; guest-auth ownership; camera/mic capture; the meeting record's conversation | §§11, 12, 13, 21 |

### The Live finding

There is **no Live Broadcast system**. `lib/features/live/` does not exist and
neither does `src/live/`. The word "live" currently names three unrelated
things:

1. `/meetings/:id/live` and its institution mirror — the **A/V room of a
   meeting**;
2. `/institution/:id/live-rooms` → `InstitutionLiveRoomsScreen`, which lives in
   `features/institutions/live_rooms/` (with an invite widget in
   `features/institutions/live/`) — an institution-scoped room list;
3. a "LIVE NOW" banner on the explore surface, reusing the same provider.

So the instruction "do not collapse Meetings / A-V / Live chapters together" is
right as *product doctrine* and currently un-implementable as *code
separation*, because two of the three chapters share one directory and the
third has no directory at all. **This requires a founder ruling before any
implementation** — R-1.

---

## 4. Route census

**32 Meetings-related registered routes.**

### Public booking — 8 (4 canonical + 4 institution-scoped mirrors)

`/meet/:slug` · `/meet/:slug/book` · `/meet/cancel/:token` ·
`/meet/reschedule/:token` · `/i/:institutionSlug/meet/:bookingSlug` ·
`/i/:institutionSlug/meet/:bookingSlug/book` ·
`/i/:institutionSlug/meet/cancel/:token` ·
`/i/:institutionSlug/meet/reschedule/:token`

### Meetings workspace — 18

| route | renders |
|---|---|
| `/meetings/:id` | MeetingDetailScreen |
| `/meetings/:meetingId/prep` | MeetingDetailScreen |
| `/meetings/:meetingId/room` | **MeetingDetailScreen** |
| `/meetings/:meetingId/summary` | MeetingDetailScreen |
| `/meetings/:meetingId/post-meeting` | MeetingDetailScreen |
| `/meetings/:meetingId/waiting` | GuestWaitingRoomScreen |
| `/meetings/join` | MeetingJoinFallbackScreen |
| `/meetings/join/:code` | PreJoinScreen |
| `/meetings/join-error` | MeetingJoinErrorScreen |
| `/meetings/keep` | KeepMeetingScreen |
| `/institution/:id/meetings` | MeetingsHomeScreen |
| `/institution/:id/meetings/new` | CreateMeetingScreen |
| `/institution/:id/meetings/:meetingId` | MeetingDetailScreen |
| `/institution/:id/meetings/:meetingId/prep` | MeetingDetailScreen |
| `/institution/:id/meetings/:meetingId/room` | MeetingDetailScreen |
| `/institution/:id/meetings/:meetingId/summary` | MeetingDetailScreen |
| `/institution/:id/meetings/:meetingId/waiting` | GuestWaitingRoomScreen |
| `/institution/:id/availability` | InstitutionAvailabilityScreen |

### A/V — 5

`/meetings/:meetingId/live` and `/institution/:id/meetings/:meetingId/live`
(both MeetingLiveRoomScreen) · `/realtime` (lobby) · `/realtime/:sessionId`
(redirect-guarded → RealtimeRoomScreen) · `/meetings/join-error` shares the A/V
failure path.

### "Live" — 1

`/institution/:id/live-rooms`

### The alias collapse

**Nine routes render `MeetingDetailScreen`.** Its own doc comment states this
was deliberate:

> It absorbs the former detail, /prep, summary, and post-meeting workspace
> surfaces: those routes all land here now.

Absorbing four surfaces into one workspace is a defensible product decision and
is **not** counted as a defect. What *is* a defect: `/meetings/:meetingId/room`
renders the **record**, not the room. A person following a link that says
"room" arrives at a page that is not the room, while the actual room is at
`/live`. That is wrong product semantics, not a redundant alias (M04).

---

## 5. Lifecycle

The backend has **one canonical enum**, not boolean soup:

`MeetingState` = DRAFT · SCHEDULED · ACTIVE · ENDED · CANCELLED

with `MeetingAudience`, `MeetingParticipantRole`, `MeetingRsvpStatus` and
`MeetingAdmissionState` alongside. This is materially better than most of the
surfaces this portfolio has reconstructed, and the audit says so plainly.

Three data-model problems remain:

* **`MeetingAudience` is nullable**, documented as *"Null on legacy rows —
  resolved in code from visibility/organizationId/allowGuests until
  backfilled."* Two authorities for one question (M06).
* **`workspaceId` / `organizationId`** persist as pre-institution vocabulary
  (M07).
* **`rsvpStatus` carries both `PENDING` and `NO_RESPONSE`** — apparently one
  concept with two spellings (M08). Whether they genuinely differ is a ruling,
  not a guess.

---

## 6. Identity

`meeting_identity.dart` implements the governed model correctly
(AURA_USER / CONTACT / GUEST, per F053/F116), and the backend continuity service
states the doctrine explicitly:

> `MeetingParticipant` IS the participant. Guest is a temporary access state,
> never a first-class identity. Identity state is DERIVED … Identity resolution
> UPGRADES a participant in place — it never duplicates.

That is the right doctrine and it is enforced where it is used. But
`meeting.dart` bypasses it twice:

* `:78` — `String get displayName => user?.name ?? guestName ?? guestEmail ?? 'Guest';`
* `:162` — `bookerName: j['bookerName'] as String? ?? 'Guest'`

A participant whose name is unknown is rendered as the literal word *Guest*,
which is a **role**, not a name — the exact conflation the doctrine forbids
(M09).

---

## 7. Authority

* `canGovern` mirrors the backend `MANAGE_MEETINGS` capability; **7 capability
  checks** in `meeting.service.ts`.
* RC8 already corrected the `?isHost=` query parameter to a first-frame hint:

  > HOST STATUS IS NOT SOMETHING A URL CAN CONFER … The query parameter
  > survives only as the first-frame hint it always really was.

  That is correct and needs no further work.
* Guest JWTs are **meeting-scoped** — issued by `/public/meetings/guest-auth`
  and encoding `meetingId`. Admission is re-checked independently at the room
  door (M22, positive).

---

## 8. Participant model

Well-formed: `role` (HOST / CO_HOST / PARTICIPANT / GUEST), `rsvpStatus`,
`admissionState`, plus `attended` / `joinedAt` / `leftAt`. Identity state is
derived rather than stored. Supporting services are real and separated:
participation resolver (789), admission (702), participation evidence (494),
invitation verification (240).

No defect found in the participant graph itself.

---

## 9. Pre-join and join

`PreJoinScreen` (`/meetings/join/:code`), `GuestWaitingRoomScreen`,
`MeetingJoinFallbackScreen`, `MeetingJoinErrorScreen`, and
`meeting_device_check.dart`. The join path is **the best-governed part of
Meetings**: the router hard-blocks a `guestId` on a `/realtime/` link and
diverts to a guest-safe error screen with diagnostics, and separately hard-blocks
signed-out visitors from ever rendering the legacy call screen. Both blocks are
commented with the incident that motivated them.

---

## 10. The active workspace

`MeetingLiveRoomScreen`, 3,934 lines, is where the audit's main structural
finding lives:

| measure | value |
|---|---|
| `ref.watch` / `ref.read` | 33, across **12 distinct providers** |
| top providers | `realtimeController` ×8 · `meetingsRepository` ×6 · `realtimeMediaService` ×4 |
| `setState` calls | **44** |
| socket/realtime references | **113** |
| tests instantiating it | **0** |

One screen simultaneously holds provider state, 44 local ephemeral states, and
a direct line to the socket and the media engine — and nothing tests it (M10,
M25).

---

## 11. Realtime authority map

Where the live room's state comes from:

| source | what it carries |
|---|---|
| **persisted backend** | meeting record, state, participants, RSVP, admission, outcomes, assets |
| **API projection** | entry resolution, join-code resolution, room descriptor |
| **provider / client** | `realtimeController` (call lifecycle), `meetingsRepository`, media service handles |
| **websocket** | participant join/leave, ended, disconnect, consent changes |
| **media engine** | tracks, devices, mute and camera state |
| **local ephemeral** | 44 `setState` sites |

**Duplicate authorities identified:**

1. **Camera/mic capture is opened in two places** —
   `meetings/presentation/widgets/meeting_device_check.dart` holds *its own*
   `getUserMedia` preview, and `realtime/data/realtime_media_service.dart` opens
   the real one. The device check's own comment acknowledges this. Two owners of
   the same hardware across a screen transition (M21).
2. **Audience** — DB column *and* code resolution (M06).
3. **Participant presence** — persisted `joinedAt`/`leftAt` *and* live socket
   events, reconciled inside the screen rather than in a named seam
   **(inference — not traced to a concrete divergence in this pass)**.

**Positive:** there is **no realtime-driven navigation**. The two `go`/`push`
calls near socket handlers (lines 912, 1017) are both user-initiated — ending a
meeting and leaving the room — and the exit handoff is deliberately documented:

> ending a meeting lands the host in the workspace — conversation reference,
> outcome capture, and summary editing at the moment of maximum recall — not on
> a passive summary page.

---

## 12. Boundary edges between Meetings and A/V

**Meetings → realtime: 11 imports**, 7 of them in the live room alone,
including `realtime/data/realtime_media_service.dart` and
`realtime/data/realtime_event_parser.dart` — a presentation file reaching into
another feature's **data** layer (M11).

**realtime → Meetings: 2 imports**, and they are not equivalent:

* `realtime_controller.dart` → `meeting_realtime_semantics.dart`. This is a
  **governed seam**, built by Realtime Architecture Correction Phase 7 precisely
  to stop `if (isMeeting)` product decisions being inlined in generic
  machinery. It is pure, stateless, tested and documented. Not a defect. The
  only question is that the seam physically lives inside `features/meetings/`
  while being consumed by `features/realtime/` — an inverted dependency
  *location*, not an inverted dependency *direction* (M18).
* `realtime_room_screen.dart` → `meetings_provider.dart`, used only by
  `_ensureGuestAuth`, which calls `meetingsRepository.exchangeGuestAuth`. **This
  method is unreachable**: the router's redirect hard-blocks any non-empty
  `guestId` on `/realtime/:sessionId` *before* the builder runs, so
  `widget.guestId` is always empty there. It is dead code (M12), it swallows its
  own failure with `catch (_) {}` (M14), and it is the **sole** reason the A/V
  presentation layer depends on Meetings at all (M13).

Deleting one unreachable method removes an entire cross-feature dependency
edge. That is the cheapest structural win in this audit.

---

## 13. Conversation boundary

`MeetingConversationMessage` is a **typed record stream** — chat, decision,
commitment, action, issue, followUp, system — promotable to `MeetingOutcome`,
with a denormalized `senderName` so the record stays readable after the
participant graph changes. That denormalization is correct for a record and
would be wrong for a conversation.

It is therefore genuinely **not** the canonical Conversation, and should not be
collapsed into it. But a Meeting today has **no link to a canonical
Conversation at all** — so "the conversation that surrounds this meeting" has
nowhere to live. That is a product gap requiring a ruling, not a defect to fix
(M20 / R-3).

---

## 14. Navigation obligations

**Meetings is the one domain still outside the canonical return contract, by
founder decision.** `return_path_frame.dart` says so:

> It does not frame Meetings/Live. Founder ruling §13 protects them.

and `return_path_authority.dart` enforces it with an explicit
`_protectedDomain` regex covering `meetings`, `meet`, `realtime` and
`/institution/:id/meetings`.

Consequences, measured:

* Meetings routes are physically **inside** the `ShellRoute` (lines 897–2478) —
  the frame reaches them and deliberately declines. Only `/realtime/:sessionId`
  sits outside the shell entirely.
* Return is therefore self-owned: **10 screens** draw their own affordance
  (mostly `GuestShell.showBackButton`).
* **Four real destinations draw nothing at all**: `booking_cancel_screen`,
  `institution_availability_screen`, `public_booking_screen` and
  `realtime_lobby_screen` (M02).
* Meetings is **`go`-dominant — 28 `go` / 18 `push` / 6 `pop`** — the inverse of
  the ratio the Navigation chapter established everywhere else, because Meetings
  was excluded from that pass (M03).

The live room and the A/V room drawing no Back is **correct** — leaving a call
is a governed exit, not a hierarchical return — and they are not counted among
the four.

---

## 15. Deep link and cold entry

Strong. `/realtime/:sessionId` resolves its surface type before rendering,
caches resolutions per `sessionId`, redirects meeting sessions to
`/meetings/:id/live`, and carries the two hard blocks described in §9. Join
codes resolve through `meeting_entry_resolution.dart`, which is tested.

No cold-entry defect was found in Meetings.

---

## 16. Refresh

`REFRESH_IS_NOT_NAVIGATION` is not violated by Meetings routing: every
workspace surface is addressable and re-resolves from the URL. The live room is
a **different case** — a refresh mid-call necessarily re-negotiates media, and
whether the session survives is an A/V question this audit did not exercise (no
implementation was authorized, and the ruling protects the surface).
**UNVERIFIED**, stated rather than assumed.

---

## 17. Responsive, accessibility, modality

* **Accessibility: 1 `Semantics` wrapper across 20,281 lines** (M15). Compare
  Create, where every outcome is a labelled button with a test asserting it.
  Meetings is effectively unusable with assistive technology, and this is the
  most serious non-structural finding in the audit.
* **Responsive: 12 hard-coded three-digit dimensions** (M16). Modest, and
  unmeasured at phone geometry because the surface is protected.
* **Modality: 3 bottom sheets, 12 dialogs.** By the behaviour test rather than
  size, none obviously needs promotion to a route — but the device check
  arguably does, since it owns hardware **(inference)**.

---

## 18. Security

No defect found. Guest JWTs are meeting-scoped and admission is re-verified at
the door; the router refuses to render member-only rooms for signed-out or
guest callers; cancel and reschedule are token-addressed rather than
id-addressed, so a public booking link cannot be walked.

---

## 19. Tests

| | count | state |
|---|---|---|
| client, meeting-related | 23 files | green |
| backend suites | 8 | green |

Coverage is real where it exists — `meeting_realtime_semantics_test`,
`meeting_person_identity_boundary_test`, `rc8_route_reconstruction_test`,
`realtime_subscription_integrity_test`, `booking_contract_test`,
`meeting_entry_resolution_test`; backend continuity, admission, participation
resolver, audience and orchestrator.

**Zero tests instantiate `MeetingLiveRoomScreen`.** `RealtimeRoomScreen` has a
golden test only. The largest, most stateful, most user-visible surface in the
domain has no widget or integration coverage (M25).

---

## 20. Platform thesis

Nothing in the Meetings *workspace* is platform-coupled: it composes
`AuraScaffold`/`GuestShell`, uses no platform channel, and its geometry is
ordinary. The **A/V layer is different** — `getUserMedia` is a web API surfaced
through browser interop, and the audit found **no `permission_handler`
dependency and no native permission request anywhere in the client**. On web the
browser prompts; on Android and iOS a native build must request camera and
microphone permission explicitly.

**The live room's platform story is therefore unproven off the web.** Stated as
a finding (M26), not as a thesis.

**`MEETINGS_IOS_CERTIFICATION = NOT_EXECUTED`.** No iOS environment on this
host, and no implementation was authorized to certify.

---

## 21. Findings taxonomy

| id | class | finding | severity |
|---|---|---|---|
| M01 | NAVIGATION | Meetings excluded from `ReturnPathAuthority` by the §13 protection regex; return self-owned across 10 screens | P1 (ruling) |
| M02 | NAVIGATION | 4 real destinations offer no way back at all | P1 |
| M03 | NAVIGATION | `go`-dominant (28/18) against the product norm | P2 |
| M04 | PRODUCT_SEMANTICS | `/meetings/:id/room` renders the record, not the room | P1 |
| M05 | ARCHITECTURE | 9 routes collapse onto `MeetingDetailScreen` (deliberate; aliases undocumented in the registry) | P3 |
| M06 | DATA_MODEL | `MeetingAudience` nullable → two authorities for audience | P1 |
| M07 | DATA_MODEL | `workspaceId`/`organizationId` pre-institution vocabulary | P2 |
| M08 | DATA_MODEL | `rsvpStatus` has both PENDING and NO_RESPONSE | P2 |
| M09 | IDENTITY | `meeting.dart:78`/`:162` fall through to the literal `'Guest'` | P1 |
| M10 | ARCHITECTURE | live room: 3,934 lines, 12 providers, 44 `setState`, 113 socket refs | P1 |
| M11 | BOUNDARY | live room imports `realtime/data/` directly | P2 |
| M12 | DEAD_CODE | `realtime_room_screen._ensureGuestAuth` unreachable | P2 |
| M13 | BOUNDARY | that dead method is the sole A/V→Meetings presentation dependency | P2 |
| M14 | ERROR_HANDLING | `catch (_) {}` swallows guest-auth failure | P3 |
| M15 | ACCESSIBILITY | 1 `Semantics` wrapper in 20,281 lines | **P0** |
| M16 | RESPONSIVE | 12 hard-coded 3-digit dimensions | P3 |
| M17 | BOUNDARY | no Live Broadcast system exists; "live" names three things | P1 (ruling) |
| M18 | BOUNDARY | governed seam lives inside `features/meetings/`, consumed by `features/realtime/` | P3 |
| M19 | ARCHITECTURE | `meeting.service.ts` 2,666 lines; 47 endpoints, 2 controllers | P2 |
| M20 | REQUIRES_RULING | Meeting has no canonical Conversation link | P1 (ruling) |
| M21 | BOUNDARY | camera/mic opened in two places across a screen transition | P1 |
| M22 | SECURITY | guest JWT meeting-scoped; both router hard blocks | **positive** |
| M23 | NAVIGATION | no realtime-driven navigation | **positive** |
| M24 | CONTINUITY | participant identity doctrine explicit, upgrade-in-place | **positive** |
| M25 | TEST_COVERAGE | zero tests instantiate the live room | **P0** |
| M26 | PLATFORM | no native camera/mic permission handling in the client | **P0** off-web |

**Counts — 26 findings: 3 positive, 23 open.**
By severity: **P0 × 3** · P1 × 9 · P2 × 7 · P3 × 4.
By class: BOUNDARY 5 · NAVIGATION 4 · DATA_MODEL 3 · ARCHITECTURE 3 ·
IDENTITY 1 · SECURITY 1 · CONTINUITY 1 · ACCESSIBILITY 1 · RESPONSIVE 1 ·
TEST_COVERAGE 1 · PLATFORM 1 · DEAD_CODE 1 · ERROR_HANDLING 1 ·
PRODUCT_SEMANTICS 1 · REQUIRES_RULING 1.

**Requiring a founder ruling before implementation: R-1 (§3, Live), R-2
(M06/M08, data model), R-3 (M20, Conversation), R-4 (M01, admit Meetings to the
return contract).**

---

## 22. Current vs intended

| dimension | today | intended |
|---|---|---|
| return path | self-owned, excluded by regex | one contract, Meetings admitted, call surfaces exempted by *semantic* rule rather than by domain |
| `/room` | the record | the room, or the alias retires |
| audience | column plus code fallback | column, backfilled, single authority |
| identity fallback | `'Guest'` | governed `meeting_identity` everywhere |
| live room | one 3,934-line screen owning transport, media, state and UI | workspace surface plus A/V surface behind a named contract |
| camera/mic | two owners | one owner, one handoff |
| accessibility | 1 label | every action labelled |
| live-room tests | none | widget and integration on real clients |
| Live | three meanings | one, or the word retires |

---

## 23. Proposed batches — NOT AUTHORIZED, NOT EXECUTED

Ordered so nothing later depends on a ruling not yet given.

* **B0 — rulings.** R-1…R-4 answered. No code.
* **B1 — accessibility (P0).** Label every action across the 22 presentation
  surfaces; gate with a semantics test per screen. Touches no lifecycle.
* **B2 — live-room characterization tests (P0).** Cover the surface *before*
  changing it. Windows and Android; web for media.
* **B3 — platform permission (P0).** Native camera and microphone request.
  Blocks any non-web release of Meetings.
* **B4 — identity and data model** (M09, M06, M08). Backfill audience; retire
  the `'Guest'` fallthrough.
* **B5 — dead code and boundary** (M12, M13, M14, M11, M18). Cheapest
  structural win; removes a cross-feature edge.
* **B6 — navigation** (M01–M04). Only after R-4. Admit Meetings to the
  contract; fix `/room`; the four missing returns.
* **B7 — live-room decomposition** (M10). Largest and riskiest. Requires B2
  green first.
* **B8 — Live disambiguation** (M17). Only after R-1.

Backend service decomposition (M19) is deliberately unscheduled: it is real,
but it is not blocking anything, and this portfolio has learned not to open a
2,666-line service without a reason.

### A/V handoff contract (proposed, for B7)

The workspace should hand the A/V system a **room descriptor** — session id,
surface type, participant identity, capability set — and receive back a
**lifecycle stream** and a **media surface widget**. It should not import
`realtime/data/`, and it should not open a camera. Camera ownership moves
wholly to the media service; the device check asks the service for a preview
rather than opening its own.

---

## 24. Certification plan

Per the cross-platform doctrine, browser verification is **not** a proxy for
Calls/Live/Meetings. Every batch reports per platform, and anything unexercised
is reported UNVERIFIED rather than assumed:

| platform | how | today |
|---|---|---|
| Web (production) | live session, real meeting | the only platform where A/V is proven |
| Windows native | `integration_test`, headless harness | workspace only; A/V unexercised |
| Android (physical Pixel 9a) | `integration_test` on device | workspace only; A/V unexercised, and blocked by B3 |
| iOS | none available on this host | **NOT_EXECUTED** |

---

## 25. Portfolio accounting

These 26 findings are **Meetings-chapter findings** and are recorded here. They
are deliberately **not** merged into the F001–F143 reconstruction register,
whose contiguity and self-contamination invariant are frozen. If they should be
issued as F-numbers, that is a ruling; this document does not assume it.

---

## 26. What was not done

No Meetings, A/V or Live file was modified. No test was added. No commit was
made. Several of the twenty-six findings could each have been fixed in under ten
minutes — including the unreachable method and the two `'Guest'` fallthroughs —
and were left alone, because the ruling asked for one measured baseline before
implementation, and a baseline that quietly repairs itself while being measured
is not a baseline.

**Awaiting founder authorization.**
