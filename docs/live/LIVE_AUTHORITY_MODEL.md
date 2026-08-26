# Aura Live — authority model

**Date:** 2026-08-26. **Chapter:** Live Broadcast reconstruction, §6 and §9.
**Status:** design, frozen for implementation. Server authority is canonical;
the client reflects authority and never creates it.

---

## 1. The governing separations

Three distinctions the current system collapses, and the reconstruction must
not:

```
ADMISSION TO WATCH   is not   PERMISSION TO PUBLISH
AUDIENCE PRESENCE    is not   STAGE PRESENCE
A VIEWER             is not   A CALL PARTICIPANT
```

Each is a defect Aura has actually shipped. The first was exploitable in
production until 2026-08-26 and is now server-enforced; it becomes a permanent
invariant rather than a fix.

## 2. What Live must CONSUME, not reinvent

The audit found existing canonical authority that Live has to adopt. Building
parallel systems here would be the error §16 warns against.

| Concern | Canonical authority | Live's obligation |
|---|---|---|
| Reports and moderator actions | `ModerationReport` / `ModerationAction`, polymorphic `targetType`/`targetId` | **Extend the taxonomy** with `LIVE_BROADCAST` and `LIVE_COMMENT`. Do not create a Live report table. |
| In-session exclusion | `RealtimeSessionBan` — `@@unique([sessionId, targetUserId])`, already consulted by the publish gate | Reuse for removing a viewer or stage guest |
| Institution acting authority | `InstitutionCapability.START_LIVE` / `END_LIVE` | **Consume them** — see §3, they are currently bypassed |
| Person identity | `AuraPersonIdentity`, canonical actor model | Broadcaster and stage identity resolve through it |
| Notifications | canonical Notification / Attention infrastructure | No Live-specific notification table |

### 3. A governance gap found during this audit

`START_LIVE` and `END_LIVE` exist and **are enforced** — but only on
`institutions.controller.ts`, which serves the *legacy institution live-room*
system (population 2 of the vocabulary).

The actual Live Broadcast escalation, `ConversationLiveController.goLive`,
checks only:

* session status is ACTIVE,
* `liveState` is NORMAL,
* the actor is an ACTIVE participant,
* the actor is not an OBSERVER.

**It never consults institution capability.** So an institution's governance
over going live is enforced for the legacy room feature and bypassed by the real
broadcast system. Institution Live (§14) cannot be claimed until this is closed.

## 4. Live roles

Deliberately distinct from `RealtimeParticipantRole`, which describes a **call**.
A Live role describes a person's relationship to a **broadcast**.

| Role | Meaning | Source of authority |
|---|---|---|
| **HOST / PRODUCER** | Opened the broadcast; owns its lifecycle | Person who escalated, or institution actor holding `START_LIVE` |
| **CO_HOST** | Shares producer authority except ending | Invited by host |
| **STAGE_GUEST** | Publishes into the broadcast | Invited, or requested and approved |
| **MODERATOR** | Governs interaction and audience, does not publish | Delegated by host, or institution actor with moderation capability |
| **VIEWER** | Watches | Admission to a PUBLIC_STAGE broadcast |
| **INSTITUTION_ACTOR** | A person acting for an institution | `InstitutionCapability`; overlays a role, never replaces the person |

`INSTITUTION_ACTOR` is an overlay on purpose. Presentation must show **the
person AND the authority** — never substitute one for the other, per the Call
Presentation Authority ruling.

## 5. Capability matrix — server-canonical

| Capability | HOST | CO_HOST | STAGE_GUEST | MODERATOR | VIEWER |
|---|---|---|---|---|---|
| VIEW | ✓ | ✓ | ✓ | ✓ | ✓ |
| PUBLISH AUDIO | ✓ | ✓ | ✓ | ✗ | **✗** |
| PUBLISH VIDEO | ✓ | ✓ | ✓ | ✗ | **✗** |
| SCREEN / PRESENT | ✓ | ✓ | ✓ | ✗ | ✗ |
| COMMENT | ✓ | ✓ | ✓ | ✓ | ✓¹ |
| REACT | ✓ | ✓ | ✓ | ✓ | ✓ |
| REQUEST STAGE | — | — | — | — | ✓ |
| INVITE TO STAGE | ✓ | ✓ | ✗ | ✓² | ✗ |
| REMOVE FROM STAGE | ✓ | ✓ | ✗ | ✓ | ✗ |
| MODERATE (mute, remove, filter) | ✓ | ✓ | ✗ | ✓ | ✗ |
| PIN | ✓ | ✓ | ✗ | ✓ | ✗ |
| END BROADCAST | ✓ | **✗** | ✗ | ✗ | ✗ |
| MANAGE AUDIENCE | ✓ | ✓ | ✗ | ✓ | ✗ |
| MANAGE VISIBILITY | ✓ | ✗ | ✗ | ✗ | ✗ |

¹ Subject to moderation state — slow mode, keyword filter, mute, block.
² Where the host has delegated invitation authority.

**END BROADCAST is host-only by design.** A co-host shares production, not
termination. Ending is the act that closes a public boundary and it stays with
the person who opened it — or an institution actor holding `END_LIVE`.

## 6. The fail-closed rule

> **Unknown authority must not fail open.**

The current client does the opposite. `_amObserver` returns `false` when it
cannot find the local user in the roster, and `false` means *show the publish
controls*. A viewer whose roster has not hydrated is therefore offered controls
they must not have.

The reconstruction inverts this:

* the server sends the viewer an **explicit Live role** with the broadcast;
* the client renders publish affordances only on a **positive** grant;
* absent, stale or unhydrated authority renders the **viewer** surface.

A control that would be refused by the server must never be drawn. Presentation
that lies about capability is the defect, not a cosmetic issue.

## 7. Stage transition

Audience and stage are separate domains with an intentional, auditable path
between them:

```
VIEWER
  → REQUEST (viewer-initiated)  or  INVITATION (host/moderator-initiated)
  → APPROVED
  → PREFLIGHT            (device readiness — reuses the A/V preflight)
  → STAGE                (publication authority granted)
  → PUBLISH

STAGE
  → LEAVE (self)  or  REMOVE (host/co-host/moderator)
  → VIEWER
```

Two invariants:

1. **Approval grants authority; the preflight only establishes readiness.** A
   person who cannot open a microphone is still authorised; they simply are not
   ready. These must not be conflated — the A/V chapter established the ordering
   `CALL INTENT → PREFLIGHT → READINESS → USER PROCEEDS → SESSION`.
2. **Leaving the stage returns a person to the audience, not out of the
   broadcast.** Demotion is not ejection.

## 8. Where this differs from the call model

| Question | Call (A/V + CPA) | Live |
|---|---|---|
| Who may publish? | every participant | only the stage |
| Who may end it? | host, or last participant leaving | host only |
| What is presence? | one roster | **two** — audience and stage |
| What does joining mean? | you are in the call | you are watching |
| Where does leaving return you? | the conversation | **not** the conversation — a viewer is never a party to it |

The last row is the viewer-exit defect, stated as a rule.

## 9. Preserved from earlier chapters

* `AUDIO_VIDEO_BOUNDARY = PRESERVED` — Live owns no capture, tracks, ICE/TURN,
  signaling or device engine.
* `CALL_PRESENTATION_AUTHORITY = CONSUMED` — Live uses the canonical participant
  and roster model for its stage; it does not fork one.
* `OBSERVER_PUBLISH_AUTHORITY = server-enforced` — permanent invariant.
* Terminal sessions cannot remain live — permanent invariant.
