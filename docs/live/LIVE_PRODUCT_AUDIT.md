# Aura Live — audit of the released product

**Date:** 2026-08-26. **Chapter:** Live Broadcast full product reconstruction.
**Status:** §4 audit. Nothing reconstructed yet; this is what exists.

Everything below was read from the shipped source or measured against
production. Where an earlier record is contradicted, the contradiction is
stated rather than quietly corrected.

---

## 1. Live Broadcast EXISTS, and the frozen vocabulary says it does not

`lib/core/realtime/live_vocabulary.dart` (frozen 2026-08-25) classifies four
meanings of the word and declares:

> **4. Live Broadcast.** Does not exist. When it is built it will be its own
> chapter, and none of the above becomes it by inheritance.

**That is no longer true, and was already untrue when written.** A Live
Broadcast capability shipped under the FD-5 charter of **2026-08-17** — eight
days earlier — and it works in production: on 2026-08-26 a broadcast was
escalated from a call, discovered by a third identity, watched, and ended, all
observed live.

The classifier has the same gap:

```dart
LiveMeaning classifyLivePath(String path) {
  // /meetings/:id/live            → activeMeeting
  // *live-rooms*                  → institutionLiveRoom
  return LiveMeaning.unrelated;   // ← everything else
}
```

`/realtime` and `/realtime/:sessionId` — the actual Live Broadcast directory and
the surface a viewer watches from — classify as `unrelated`. The one file whose
job is to stop a later chapter guessing cannot name the system that chapter is
about.

**Audit action:** the vocabulary must be corrected to describe five populations,
with Live Broadcast as a real one owning `/realtime` and `/realtime/:sessionId`.
Routes are not renamed (the frozen rule holds); ownership is stated.

## 2. What the released Live product actually is

| Concern | Reality today |
|---|---|
| Creation | **Escalation only.** `goLive` promotes an ACTIVE conversation call. There is no "start a broadcast" anywhere. |
| Lifecycle | `liveState`: NORMAL → LIVE_PREPARING → LIVE → ENDING → NORMAL, on `RealtimeSession` |
| Access | `accessMode: PUBLIC_STAGE` |
| Audience admission | Any authenticated user joining a LIVE session is upserted as role `OBSERVER` |
| Discovery | `GET /realtime/live/broadcasts` — ACTIVE + LIVE, newest 25 |
| Viewer surface | `RealtimeLobbyScreen`, **241 lines** — a list. Entering it puts the viewer in `RealtimeRoomScreen`, the same screen a call participant uses |
| Producer surface | One dock button: `Go Live` / `End Live` |
| Anonymous viewing | Not supported — lobby and join both require auth |

### What does not exist at all

Comments · reactions · watcher list · stage requests · invitations to stage ·
co-host · moderator role · live-specific moderation · scheduled live · replay ·
recording of a broadcast · analytics · broadcast title distinct from session
title · viewer-appropriate exit · captions.

The audience surface is the call room with controls hidden. That is precisely
what §3 of the founder ruling forbids going forward.

## 3. Media topology, measured

Observed on the Pixel during a real broadcast, 2026-08-26:

```
peerKey=2WU9v91XSpKWs9azAAAN   stage peer   (bidirectional, onTrack audio+video)
peerKey=bDdBbKUvaNSOWTjcAAAT   viewer peer  (no onTrack — send-only)
```

Each stage participant negotiates a **direct WebRTC peer connection with each
viewer**. The observer contract is correct — receive-only, no inbound tracks
expected — but the topology is mesh.

**Publisher upload cost therefore grows linearly with audience size.** With two
stage participants and one watcher that is three connections. It does not
survive an audience. This is §12's central question and it is not answerable by
tuning: it is an architecture decision.

## 4. A claim of mine that was wrong

I wrote, in commit `b267d11` and in `AV_CERTIFICATION.md`, that stale
`liveState=LIVE` rows on ENDED sessions "left the Live surface pointing at
calls that were already over".

**That is incorrect.** Discovery requires both:

```ts
where: { status: RealtimeSessionStatus.ACTIVE, liveState: RealtimeLiveState.LIVE }
```

An ENDED session is excluded by the status condition regardless of its
`liveState`. The four stale rows were a genuine data-integrity defect and the
fix stands, but they did **not** surface dead broadcasts in discovery, and I
should not have said they did.

The viewer's error page has a different and separately-established cause — §5.

## 5. Viewer exit is wrong by construction

An observer leaving a broadcast is navigated to the originating conversation:

```
/messages/c/<conversationId>  →  "Not available right now"
```

The backend's own rule is that a Live viewer is admitted as *session-scoped
viewer presence only* and is **"never a Conversation party"**. So the exit
destination is one the viewer is guaranteed to lack access to. This is not a
broken route; it is the wrong destination, chosen because Live inherited a
call's idea of where a person came from.

## 6. Authority state after tonight's fixes

| Invariant | State |
|---|---|
| A viewer cannot publish audio/video/screen | **Server-enforced** (`[publish:observer]`, negative-controlled) |
| A terminal session cannot remain live | **Enforced** — `liveState → NORMAL` on end |
| Production stale-live rows | **Repaired** — 4 corrected, 0 remaining |

These are preserved as permanent invariants of the reconstruction, per the
founder ruling.

### Still open, carried in as inputs (§22)

* viewer publish controls appearing in the client — unmeasured
* `_amObserver` **fails open**: returns false when the local user is absent from
  the roster, which SHOWS publish controls. Unknown authority must fail closed.
* watcher chat absent · watcher list absent
* PiP maximise unresponsive for a viewer
* mesh-per-viewer scaling (§3 above)

## 7. Vocabulary collision — semantic ownership proposed

| Population | Owns | Route evidence |
|---|---|---|
| **Active meeting** | Meetings + A/V | `/meetings/:id/live`, institution mirror |
| **Institution live room** | Legacy institution capability | `/institution/:id/live-rooms` |
| **Discovery indicator** | Presentation over the above | "LIVE NOW" banner, rail |
| **Live Broadcast** | **This chapter** | `/realtime`, `/realtime/:sessionId` |
| **The English word** | Nothing | `liveRegion`, `liveNotes` |

Public routes are not renamed. Ownership is declared so the next reader inherits
a classification rather than 240 string matches.
