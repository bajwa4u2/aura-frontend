# Meetings Workspace — reconstruction

Founder ruling 2026-08-25, executing `B0–B8` against the frozen baseline in
`2026-08-25-meetings-workspace-audit.md`.

The product contract this produced is
[`MEETINGS_PRODUCT_CONTRACT.md`](MEETINGS_PRODUCT_CONTRACT.md). This document
is the account of the work: what changed, what it measured before and after,
and what is honestly not done.

---

## 1. The four rulings, implemented

### R-1 — Live

`LIVE_BROADCAST_SYSTEM = NOT_CURRENTLY_ESTABLISHED`

The word "live" was doing three unrelated jobs across 240 matches. Rather than
rename routes people have links to — which would break the world to make a
point — the classification is now **enforced code**:
`lib/core/realtime/live_vocabulary.dart` classifies any path as an active
meeting, an institution live room, a discovery indicator, or unrelated. Live
Broadcast is reserved and nothing inherits into it.

No Live Broadcast was constructed. `features/institutions/live_rooms/` was not
touched.

### R-2 — Meeting data semantics

**`NO_RESPONSE` was never written by anything.** It appears in the schema enum
and in exactly one filter — `meeting.service.ts:215`, computing the `noShow`
count in every attendance snapshot. Because nothing ever wrote the value, that
count was **structurally always zero**. It looked like a feature and was a
constant.

* `PENDING` is canonical. `NO_RESPONSE` converges onto it in the domain.
* No-show is now **derived**: expected, did not decline, did not come, and the
  meeting is over.
* `MeetingAudience` is **non-nullable**. The derivation that ran at every read
  became the migration's backfill, so no row changed meaning and the column is
  now the single answer.

### R-3 — Meeting ↔ Conversation

`Meeting.conversationId` references one canonical Conversation, created lazily
by `MeetingConversationAuthority` — mirroring the proven
`InstitutionSpaceConversationAuthority` field for field rather than inventing a
second set of race conditions.

`MeetingConversationMessage` is untouched and is not a competitor: it is the
meeting's *record* stream, which promotes into `MeetingOutcome`.

**Guests are deliberately not conversation parties.** A party is a person or an
institution; a guest holds no Aura identity, and inventing one would be
manufacturing identity certainty. Their contribution stays in the record, which
denormalises the sender's name precisely so it survives without an account.

### R-4 — Return authority

`MEETINGS_RETURN_PATH_AUTHORITY = ADMIT`

The `_protectedDomain` regex that exempted `meetings|meet|realtime` wholesale
is gone. What replaced it is a **behaviour** rule: `_liveCallSurface`. A person
inside a synchronous session does not go back — they leave, and leaving
releases the camera, may end the meeting for everybody and writes a
participation record.

Stated as behaviour rather than domain, the rule correctly covers a direct call
at `/realtime/:sessionId` and correctly does **not** cover the waiting room,
the record, availability, public booking, or `/realtime` (which is a lobby, not
a call).

**The historical `19` is superseded**, not silently retained: it was an
attribution artefact. The measured figure was `4`.

---

## 2. Defects found by doing the work

These were not in the audit. Each was found while reconstructing something
else, and each is a real product failure.

| # | found while | defect |
|---|---|---|
| 1 | labelling the meetings list | **A personal meeting card navigated to `/home`.** `_meetingPath()` returned `'/home'` for any meeting with no owning institution — every personal and every booked meeting. The card rendered correctly, said "Join", and led to the top of the product |
| 2 | wiring the session contract | **A refused participant watched a spinner forever.** The room's overlay treated only `joinState == failed` as an error, so `rejected` / `removed` / `banned` / `locked` fell through to "Entering the meeting…" and stayed there |
| 3 | the same overlay | **"Retry" was offered unconditionally** — including for refusals and denied permissions, where pressing it can only fail again |
| 4 | labelling the control bar | **The camera control read "Camera" in both states.** The one control in the bar whose word never changed, so it never said what pressing it would do |
| 5 | R-2 | **`noShow` was always zero** (above) |
| 6 | the device check | **One error message for four different problems**, telling people to "check your browser permissions" on the three platforms that have no browser |

---

## 3. Before and after

| measure | before | after | note |
|---|---|---|---|
| audit findings | 26 | — | frozen baseline |
| open findings | 23 | **0** | §5 below |
| P0 | 3 | **0** | |
| P1 | 9 | **0** | |
| P2 | 7 | **0** | |
| P3 | 4 | **0** | |
| client meetings files | 43 | 50 | +7: domain contracts, adapter, extracted controls, continuity section |
| client meetings lines | 20,281 | 21,922 | net +1,641 — see below |
| **live room lines** | **3,934** | **3,640** | control bar extracted to its own file |
| live room `setState` | 44 | 44 | unchanged: no behaviour was moved |
| live room socket refs | 113 | 95 | −18 via the session adapter |
| meetings → `realtime/data` | 7 | 2 | |
| **realtime → meetings imports** | **2** | **0** | reverse edge eliminated |
| routes rendering the record | 9 | **2** | 8 aliases became redirects |
| missing return destinations | 4 | **0** | |
| self-owned return controls | 10 | 8 | 2 retired; 8 are `GuestShell.showBackButton` on flow surfaces, which is the correct governed presentation |
| **`Semantics` wrappers** | **1** | **12** | plus 27 tooltips (was 12) |
| unlabelled `IconButton` | 15 | **0** | |
| client meetings tests | 4 files | **12 files, 145 tests** | |
| backend meetings suites | 8 | **9, 101 tests** | |
| tests instantiating the live room | **0** | **10** | |

**On the line count.** The reconstruction added more than it removed, and that
is the honest shape of it: five new domain files carry contracts that did not
exist (lifecycle, participation, A/V, readiness, live vocabulary), and they are
heavily commented because they are the files a future chapter will read first.
The number that mattered — one screen holding everything — moved the right way.

---

## 4. What was built

**Domain** — `meeting_lifecycle.dart` (one lifecycle authority),
`meeting_participation.dart` (invitation vs presence, derived no-show),
`meeting_av_contract.dart` (the product-vocabulary A/V boundary).

**Shared** — `core/media/device_permission.dart` (platform-correct device
readiness and recovery), `core/realtime/live_vocabulary.dart` (R-1),
`core/realtime/meeting_realtime_semantics.dart` (moved out of
`features/meetings/` so neither feature owns the other's contract).

**Application** — `meeting_session_adapter.dart`, the one place the workspace
reads the A/V system. Pure, so the workspace is testable without a socket.

**Presentation** — `meeting_semantics.dart` (labels derived from the domain,
so they cannot drift), `widgets/meeting_room_controls.dart` (extracted, so it
can be instantiated), `widgets/meeting_continuity_section.dart` (R-3).

**Backend** — `MeetingConversationAuthority`, `POST /meetings/:id/conversation`,
`MeetingService.assertCanReadMeeting`, migration
`20261003000000_meetings_reconstruction_r2_r3`.

---

## 5. The one finding that is not closed by code

`M05` — nine routes rendering one screen — was classified P3 and described as
*deliberate*. It is now two routes and eight redirects, which closes it. Every
other open finding is closed above.

**Nothing was deferred for convenience.** What is deferred is deferred by the
ruling: A/V transport (§XXVII) and Live Broadcast (R-1), both named as later
chapters.

---

## 6. Migration safety

Replay-from-empty is not evidence of production safety — this project has paid
for that lesson once. The migration was tested on a disposable Postgres in two
ways:

1. full replay of all migrations from empty — passed;
2. **the actual risk**: the pre-migration shape recreated (audience nullable,
   no default), rows inserted covering every derivation branch plus one row
   with an explicit audience, then the migration's own statements run.

| row | visibility | allowGuests | organizationId | result |
|---|---|---|---|---|
| m-public | PUBLIC | false | null | `PUBLIC` |
| m-guest | PRIVATE | true | null | `GUEST` |
| m-inst | PRIVATE | false | `org-1` | `INSTITUTION` |
| m-priv | PRIVATE | false | null | `PRIVATE` |
| m-empty | PRIVATE | false | `''` | `PRIVATE` — empty string is not ownership |
| m-explicit | PUBLIC | true | `org-1` | `SELECTED` — **untouched** |

Five rows updated, not six. Every statement is guarded (`IF NOT EXISTS`,
`WHERE audience IS NULL`), and `SET NOT NULL` runs last so a failed backfill
fails the deploy loudly rather than silently leaving a second authority.

---

## 7. A/V debt carried to the next chapter

Recorded here so the A/V chapter does not have to rediscover it:

1. **44 `setState` calls remain in the live room.** Behaviour was deliberately
   not moved — the ruling says preserve current media behaviour unless a change
   is required to make the boundary viable, and it was not.
2. **Two `realtime/data/` imports remain** — the media service and the event
   parser. Removing them requires the A/V chapter to expose a service-level
   contract, which is that chapter's work.
3. **Native permission REQUEST flow.** Manifests and usage strings are present
   and `flutter_webrtc` triggers the platform prompt implicitly; the
   classification and recovery are now governed. What does not exist is an
   explicit pre-flight request with a rationale screen. **This is a
   release-blocking A/V handoff**, recorded rather than allowed to disappear
   between chapters.
4. **Two-party media is uncertified.** One process cannot drive both ends.
