# Aura Meetings — product contract

Authoritative as of 2026-08-25. Supersedes the working assumptions recorded in
`2026-08-25-meetings-workspace-audit.md`, which remains the frozen baseline
this reconstruction was measured against.

This document says what Meetings **is**, who decides **what**, and where the
boundaries with the neighbouring systems fall. It is the document a future
chapter should read before touching anything here.

---

## 1. What a Meeting is

A Meeting is a **purposeful, identified, scheduled gathering that leaves
something behind.**

Each clause is load-bearing:

* **purposeful** — it has a title, a context and an owner. It is not a
  disposable URL.
* **identified** — the people in it are Aura people wherever Aura can resolve
  them, and honestly external where it cannot.
* **scheduled** — it exists before it happens and after it ends. The live call
  is one phase of its life, not its whole life.
* **leaves something behind** — a record, and where people want one, a durable
  conversation.

## 2. The lifecycle — one authority

`lib/features/meetings/domain/meeting_lifecycle.dart`

```
draft → scheduled → ready → active → ended
                                   ↘ cancelled
                                   ↘ missed
```

Two inputs, one answer:

* the **record** (`Meeting.state`) is the spine — what the meeting *is*;
* the **room** (`MeetingRoom.status`) refines it — how far along it *currently*
  is.

The rule is `max(record, room)` by lifecycle rank, **forward only**, with two
absolute record decisions: `CANCELLED` and `DRAFT` cannot be overruled by any
room projection.

Nothing else may answer this question. `Meeting.isActive`, `isScheduled`,
`isDraft` and `isEnded` all delegate here; before this reconstruction each
combined the two inputs differently and they disagreed.

**Capability** (`canJoin` / `canStart` / `canEnd`) is **backend authority**,
carried on `MeetingRoom`. Where no projection is present the client answers
conservatively and marks the answer non-authoritative — it never invents host
authority.

## 3. Participation

`lib/features/meetings/domain/meeting_participation.dart`

Two independent questions, deliberately not collapsed:

| question | type | values |
|---|---|---|
| Did they answer the invitation? | `MeetingInvitation` | awaiting · accepted · declined · notInvited |
| Where are they now? | `MeetingPresence` | away · knocking · admitted · present · disconnected · departed · removed |

**R-2:** `PENDING` is the one canonical name for "invited, has not answered".
The schema's `NO_RESPONSE` converges onto it.

**A no-show is derived, never stored** — expected, did not decline, did not
come, and the meeting is over. It was previously counted by filtering for a
value nothing ever wrote, so the count was structurally always zero.

**Roles:** host · coHost · participant · guest. An unrecognised role is a
participant, never a host — authority never fails open.

## 4. Identity

Person identity is the canonical `AuraPersonIdentity`. The meeting domain adds
participant *type*, and the two are never substituted for each other:

* an Aura person is named by the canonical authority, whose own last resort is
  the one neutral word the product shares;
* a genuinely external participant is named by what they supplied, then by
  **Guest** — which is accurate for them.

`Guest` is a statement about somebody's relationship to Aura. It is never
applied to a member merely because a payload did not expand their person.

## 5. Authority

| decision | owner |
|---|---|
| may this person see the meeting | `MeetingService.assertCanReadMeeting` |
| may they govern it | backend `MANAGE_MEETINGS` capability |
| may they join / start / end | `MeetingRoom` capability flags |
| host / co-host responsibility | `MeetingParticipantRole` |

Host is **not** institution admin and **not** platform admin. `?isHost=` in a
URL is a first-frame hint only, overruled by the meeting itself (RC8).

## 6. Audience — R-2

`MeetingAudience` is **non-nullable**, with an explicit governed value on every
row. The derivation that used to run at every read is now the migration's
backfill:

```
visibility PUBLIC → PUBLIC
allowGuests       → GUEST
organizationId    → INSTITUTION
otherwise         → PRIVATE
```

The code path survives only as a defensive default during a rolling deploy. It
is no longer an authority.

## 7. Conversation continuity — R-3

```
MEETING_CONVERSATION_CONTINUITY = CANONICAL_RELATIONSHIP_REQUIRED
MEETING_LOCAL_DURABLE_CHAT      = PROHIBITED
```

A Meeting **references one canonical Conversation**
(`Meeting.conversationId`), created lazily by
`MeetingConversationAuthority`, mirroring the proven Institution Space
relationship field for field.

| owner | owns |
|---|---|
| **Meeting** | lifecycle, scheduling, participation, authority, the record |
| **Conversation** | durable messages meant to survive the synchronous event |
| **A/V** | realtime media execution |

`MeetingConversationMessage` is **not** replaced. It is the meeting's *record*
stream — decision, commitment, action, issue, follow-up — which promotes into
`MeetingOutcome`. It denormalises the sender's name precisely because a record
must stay legible after the roster changes.

**Guests are not conversation parties.** A party is a person or an institution;
a guest holds no Aura identity, and inventing one would manufacture identity
certainty. Their contribution lives in the record, which is designed to keep it
without requiring them to have an account.

## 8. The A/V boundary — §XXVII

`lib/features/meetings/domain/meeting_av_contract.dart` states what the
workspace is allowed to know, in product words:

`MeetingSessionState` — none · available · joining · joined · reconnecting ·
left · recoverableFailure · terminalFailure

`MeetingSessionFault` — networkUnavailable · serviceUnavailable ·
mediaPermissionDenied · mediaDeviceUnavailable · notAdmitted ·
meetingConcluded · unknown

**Intent and reality are separate.** `MeetingMediaIntent` is what a person
asked for; `MeetingMediaState` is what is actually happening. A control that
showed the request rather than the result would tell somebody their microphone
was on while the room heard nothing.

`lib/features/meetings/application/meeting_session_adapter.dart` is the **one
place** the workspace reads the A/V system. It is pure, so the workspace can be
tested without a socket.

Deferred to the A/V chapter, and deliberately not modelled here: codecs,
transport, SFU/mesh topology, media recovery algorithms, quality adaptation.

## 9. Device readiness — §IX

`lib/core/media/device_permission.dart` — shared, because this is not a
Meetings problem.

`DevicePermissionState` — notRequested · granted · denied · restricted ·
unavailable · inUse.

Each carries a **platform-correct recovery**. `notRequested` is not an error
and offers no recovery; `denied` cannot be retried in-app and must not offer
to.

## 10. Navigation — R-4

`MEETINGS_RETURN_PATH_AUTHORITY = ADMIT`

The Meetings Workspace uses the canonical `ReturnPathAuthority`. The old §13
domain protection is retired.

One exemption survives, restated as **behaviour** rather than domain:
`_liveCallSurface` — `/meetings/:id/live`, its institution mirror, and
`/realtime/:sessionId`. A person inside a synchronous session does not go back;
they leave, and leaving releases the camera, may end the meeting for everybody
and writes a participation record. `/realtime` (the lobby) is **not** a call
and is framed normally.

## 11. Routes

Two routes render the meeting record:

* `/meetings/:meetingId`
* `/institution/:institutionId/meetings/:meetingId`

Eight historical aliases — `/prep`, `/room`, `/summary`, `/post-meeting` and
their institution mirrors — **redirect** to them. `/room` was the actively
misleading one: it promised the live room and rendered the record while the
real room sat at `/live`.

The live room is `/meetings/:meetingId/live` and its institution mirror.

## 12. "Live" — R-1

`LIVE_BROADCAST_SYSTEM = NOT_CURRENTLY_ESTABLISHED`

`lib/core/realtime/live_vocabulary.dart` records the classification. Three
unrelated things currently share the word:

1. **an active meeting** — `/meetings/:id/live`, Meetings + A/V, not Live;
2. **an institution live room** — `/institution/:id/live-rooms`, a legacy
   capability;
3. **a discovery indicator** — the "LIVE NOW" banner, presentation only.

Live Broadcast does not exist, and none of the above becomes it by
inheritance. Nothing was renamed: routes in the world stay addressable.

## 13. Accessibility

`lib/features/meetings/presentation/meeting_semantics.dart` derives labels from
the domain, so they cannot drift from what the screen shows. Every control
announces its **effect and its state**; participants announce as one sentence
rather than a name followed by unlabelled glyphs; times are spoken in words
rather than abbreviations; state changes are polite live regions.

## 14. What Meetings deliberately does not do

* It does not implement durable messaging (R-3).
* It does not implement media transport (§XXVII).
* It does not implement Live Broadcast (R-1).
* It does not maintain its own availability truth (§XV) — it consumes the
  canonical availability architecture.
* It does not render rich content with its own renderers (§XXIX).
* It does not maintain its own notification truth (§XXII) — meeting
  notifications go through `ActorNotificationsService`.
