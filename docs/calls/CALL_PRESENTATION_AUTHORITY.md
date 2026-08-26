# Call Presentation Authority

**Chapter opened:** 2026-08-25, founder ruling *A/V FINAL CLOSEOUT + CALL
PRESENTATION AUTHORITY HANDOFF* (Option 2).
**Boundary:** the certified A/V engine is an **input dependency**, not in scope.
Meetings is closed. Live Broadcast is closed.

---

## 1. The question this authority answers

> **How does Aura present a live human media session?**

Independently of whether the enclosing product is a thread call, a Meeting, an
institution-owned room, or a future Live surface.

It is **not** transport authority. It never owns WebRTC, signaling, ICE,
TURN/STUN, tracks, capture, routing or reconnect mechanics.

## 2. Measured duplication (before)

| | thread room | meeting live room |
|---|---|---|
| file | `realtime/presentation/realtime_room_screen.dart` | `meetings/presentation/meeting_live_room_screen.dart` |
| lines | **3,783** | **3,685** |
| widget classes | 23 | 20 |
| shared call-presentation imports | 1 | **0** |

Files touching call participants: **22**. Sites independently resolving a
person's identity: **15**.

### The same semantic question, answered twice

| Semantic question | thread room | meeting live room | class |
|---|---|---|---|
| how do tiles lay out? | `_VideoGrid` | `_MeetingVideoGrid` | DUPLICATE |
| how is one participant drawn? | `_VideoTile`, `_AvatarTile`, `_AvatarStage` | `_ParticipantTile`, `_ParticipantRow` | DUPLICATE |
| what do controls mean? | `_CallControlDock`, `_MeetingControlDock`, `_DockButton`, `_LeaveButton` | own dock | DUPLICATE |
| what does failure look like? | `_ConnectionBanner`, `_MediaWarningView`, `_MediaLoadingView` | `_ConnectingOverlay`, `_CameraUnavailableBanner` | DIVERGENT |
| who is in the room? | participant list widget | `_MeetingParticipantPanel` | DUPLICATE |
| how long have we been here? | inline in top bar | `_ElapsedTimer` | DUPLICATE |
| what happened at the end? | — | `_MeetingEndedOverlay` | PRODUCT-SPECIFIC |
| reactions / raised hands | — | `_FlyingReaction`, `_RaisedHandsStrip`, `_ReactionsOverlay` | PRODUCT-SPECIFIC (today) |
| notes / files | `_ArtifactBlock` | `_MeetingNotesDrawer`, `_MeetingFilesDrawer` | PRODUCT-SPECIFIC |

**The thread room already contains a `_MeetingControlDock`.** A previous attempt
at convergence was made by copying, which is precisely the failure mode this
chapter exists to end.

## 3. Why this is the generator of the A/V defects

Every defect found during A/V two-party certification was one product surface
disagreeing with the other about a question neither owned:

| Defect | The disagreement |
|---|---|
| frame mismatch (portrait vs landscape) | Meetings chose `Cover`, thread room chose `Contain` |
| no preflight on thread calls | Meetings had a device check; thread calls had none |
| "Someone" on the ring card | two transport encodings reconciled nowhere |
| duplicate third participant | roster assembled ad hoc per event shape |
| control labels | each surface wrote its own words |

Each had to be fixed twice, and each fix could land in only one room. With
institution rooms and Live, that becomes four.

## 4. Ownership boundaries (frozen for this chapter)

**A/V engine owns** — WebRTC/media transport, signaling, ICE, TURN/STUN, media
tracks, connection/reconnect mechanics, device capture, audio routing,
low-level media lifecycle.

**Call Presentation Authority owns** — participant presentation model,
canonical identity projection, roster convergence, tile/media composition,
aspect/fill policy, local vs remote, mute/camera visual state, control grammar,
accessibility semantics, call-status presentation, failure/recovery
presentation, layout policy, PiP integration, and the adapter contract from
engine state into product-facing state.

**Meetings owns** — meeting lifecycle, purpose/context, attendance semantics,
the meeting record, Conversation continuity, consequential leave/end rules.

**Thread Conversation owns** — thread context, call initiation affordance,
durable continuity, call-event history.

**Live Broadcast owns** — publication/broadcast semantics, audience model,
visibility/distribution, broadcast lifecycle, creator authority. **CLOSED.**

## 5. Target shape

```
A/V ENGINE STATE
  → CALL PRESENTATION AUTHORITY
    → PRODUCT ADAPTER
      → thread room / meeting room / institution room / future Live surface
```

Product adapters supply context header, purpose/title, Conversation link,
meeting lifecycle actions, institution context. They do **not** reimplement
participant, media, control or accessibility semantics.

There must not be a thread room engine, a meeting room engine, an institution
room engine and a Live room engine.

## 6. Added to the scope, 2026-08-25: the call BEFORE it is answered

Two founder findings landed after this chapter opened, and both are the same
category of fault as the ones in §3 — a question about how a call is presented,
answered by whichever mechanism happened to be nearby.

### 6.1 Incoming-call presentation (AV-13)

An incoming call had no presentation surface on Android. It was an FCM
notification whose channel sound happened to be a ringtone, so the RING was a
property of the NOTIFICATION. Founder: *"notification naturally a short tenure
so if miss tap call burried immediately."*

The frozen rule this adds:

> **A call is presented as a call. Its ring belongs to the call's ring window,
> and ends only when the call reaches an outcome — answered, declined,
> cancelled, superseded by another device, or expired.**
>
> Never: notification swiped, notification tapped, notification aged out.

This belongs here rather than to any product because a thread call, a Meeting
and a future Live invitation must all ring the same way. Full record and
measurement: `docs/av/AV_CERTIFICATION.md`, AV-13.

### 6.2 A capability offered where it cannot work (AV-14)

Go Live was offered inside an AUDIO call. Escalating produced a public broadcast
with nothing for an audience to receive, and the watcher got an error. Founder:
*"it should be deterministic for video."*

The frozen rule:

> **A presentation surface must not offer a capability the current media
> session cannot satisfy, and the test must be derived from published media
> state — identical on every client — never from local guesswork.**

The origination gate now asks whether any stage participant is actually
publishing video. Ending a Live is deliberately not gated: closing a public door
must never depend on the camera that opened it.

### What these two add to §4

**Call Presentation Authority also owns** — incoming-call presentation
(ring surface, ring lifetime, accept/decline affordances, and the native
platform surfaces that carry them), and capability gating of in-call controls
against the session's actual media.
