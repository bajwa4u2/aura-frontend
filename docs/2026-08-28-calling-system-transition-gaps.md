# The calling system as a whole — what the Cloudflare transition lost

**Date:** 2026-08-28
**Frame:** founder — *"rather than firefighting see the calling system as a
whole, find out the gaps and eradicate. All was proved working end to end; all
that happened is transition to Cloudflare."*

That reading is correct. Walking the transitions instead of waiting for bug
reports found a single structural defect underneath most of what remains.

---

## THE FINDING

> **On the stage path, local media is published EXACTLY ONCE — at attach — and
> never again. Every later change to local media is written only to the mesh
> map, which is empty.**

`publishLocal()` has one call site in the entire client: inside `attachStage()`
(`realtime_media_service.dart:1222`). `attachStage` runs once per call;
`detachStage` is reached only on attach failure and on leaving. After that
first publish, the outbound side of the call is frozen.

Meanwhile every method that mutates local media still iterates `_peers` — the
per-remote-peer connection map that mesh maintained and the stage never
populates. Those loops run over an empty map, succeed, update the local
preview, and reach nobody.

And the transport already has the answer: `replaceVideoSource` is declared on
`RealtimeTransport` (`realtime_transport.dart:53`) and correctly implemented by
`SfuRealtimeTransport` (`sfu_realtime_transport.dart:427`) — using
`replaceTrack`, so no renegotiation and no re-subscribe.

**It has zero callers.** Unconsumed authority, the same anti-pattern as the
presence event that carried a participant id nobody read.

---

## Why this shape, and why it is silent

Under mesh, one `RTCPeerConnection` existed per remote person and remote media
arrived through `onTrack`. Any change — new track, replaced track, dropped peer
— re-drove offer/answer automatically. Nothing had to *remember* to republish,
because publication was a property of the connection, not an event.

Under the stage there is ONE peer connection and a server-side registry
(`RealtimeSessionTrack`) that must be kept in agreement with reality. Every
transition mesh handled implicitly now needs an explicit rule, and **a missing
rule throws nothing and logs nothing** — it produces a call that looks correct
to the person causing it.

That is why these went unreported: in each case the *sharer* sees success.

Every defect found in the last two days is an instance of the same thing:

| Defect | The rule mesh got for free |
|---|---|
| grid iterated device-keyed renderers | mesh keyed by device because it *had* devices |
| `copyWith` dropped the renderer map | mesh state was rebuilt per peer |
| native `ownerTag` taken from a label | mesh used `onTrack`'s own stream |
| presence event erased participant id | mesh keyed on socket, not participant |
| late publication never reconciled | offer/answer re-drove discovery |
| audio-only participant had no tile | mesh made a renderer per peer regardless |
| track-name collision | mesh had no shared name space |
| stale receive transceivers | mesh closed the whole peer connection |

---

## The inventory — every `_peers` consumer, checked

Mechanically enumerated from `realtime_media_service.dart`, not sampled.

### Outbound media never reaches the stage · **severity: high**

| Method | What the user does | What happened on the stage |
|---|---|---|
| `startScreenShare` | Share Screen | captured, previewed, **published to nobody** |
| `stopScreenShare` | stop sharing | camera restored locally only; remote kept the retired screen track |
| `switchVideoInput` | pick another camera | remote kept the old camera |
| `switchAudioInput` | pick another mic | remote kept the old mic |
| `_reacquireCamera` | camera on after capture was denied or stopped | new track never published |

**Not on this list, checked and genuinely fine:** `switchCamera` — the
front/back flip. It calls `Helper.switchCamera`, which swaps the source
*underneath the same track object*. The stage published that object and keeps
sending it, so the flip propagates with nothing to republish. Listed as broken
in the first draft of this document and corrected on inspection.

### REPAIRED — 2026-08-28

Every outbound change now routes through a single method,
`RealtimeMediaService._replaceOutboundVideo` / `._replaceOutboundAudio`, which
picks the live transport instead of assuming mesh. `replaceVideoSource` gained
a null case (clearing a sender, which stopping a screen share in an audio-only
call requires) and a `replaceAudioSource` sibling.

Two traps handled in the repair, both of which would have produced a *new*
silent defect:

* the transport's `setCameraEnabled` / `setMicrophoneEnabled` toggle `enabled`
  on tracks held in its own `_local` stream. Replacing a sender's track without
  updating `_local` would leave mute pointing at the RETIRED track — the
  control reporting success while the live track kept sending. `_adoptLocal`
  keeps the stream in agreement with the wire.
* replacement finds no sender when the call published no track of that kind at
  attach — camera denied, or an audio-only join now sharing a screen. That case
  needs a publish, which replacement cannot do. It is now REPORTED as
  `REPLACE_NO_SENDER` rather than returning silently, and tracked below as
  `STAGE_REPUBLISH_AFTER_NO_CAPTURE`. **It is not closed.**

**Unverified in a real call at time of writing.** Per the rule adopted after
two reverts on 2026-08-28, a change on the live call path is not done until a
call proves it.

### No ICE recovery on the stage · **severity: high**

`checkPeersHealth()` (944) iterates `_peers` and is therefore a **no-op**. The
stage transport's only ICE handler is the one-shot completer in `_waitForIce`
(519), never re-armed. So after a call is established: no ICE failure
detection, `_escalateIceFailure` never reached, no ICE restart, no recovery.
`restartIce` (896) and `updateIceConfiguration` (930, TURN credential rotation)
are likewise mesh-only.

Mesh had all of it. On the stage a transport that dies mid-call stays dead
until somebody hangs up. This is a live candidate for symptoms currently filed
under `JOINED_LOST_MID_CALL` and should be measured before that is assumed.

### No adaptive quality or telemetry on the stage · **severity: medium**

`_applyVideoBitrateCap` (1574), `_applyDegradationPreference` (1597),
`applyParticipantScaling` (1566) and `collectQualitySample` (1620) all iterate
`_peers`. On the stage there is no bitrate cap, no degradation preference, and
`collectQualitySample` returns a sample gathered from nothing — so the adaptive
loop in `_adaptToSample` is running on empty input. Quality does not degrade
gracefully under load, and we have no outbound stats from the stage path.

---

## Transitions checked and found genuinely COVERED

Recorded so the next pass does not redo them.

| Transition | Status |
|---|---|
| join → attach → publish | covered |
| someone joins late | covered — publication event |
| a peer publishes later | covered — publication event |
| mic / camera mute-unmute | covered — toggles `enabled` on the published track, no republish needed |
| a peer republishes | covered — supersession, receiver retirement, renderer follows track |
| participant leaves | covered — `closeTransport` ends their tracks; subscribers retire receivers |
| explicit leave / session end | covered — transports closed, tracks ENDED |
| late answer to a ringing call | covered — 2026-08-28 |
| participant disconnected but recovering | covered — auto-end counts DISCONNECTED |

Note the honest distinction in row four: mute works because it never needed a
republish. It is not evidence that the publish path is healthy.

---

## The rule going forward

Any capability mesh implemented against `_peers` is a candidate for having no
stage equivalent, and the failure mode is silent by construction. The cheap
systematic check is: **grep `_peers`, and for each use ask what the stage does
instead.** Everything above came out of that in one pass.

The deeper rule, which is what actually went wrong: **an interface method with
no caller is not a feature.** `replaceVideoSource` was written, implemented
correctly, reviewed, and shipped — and the outbound path stayed frozen because
nothing called it. Adding a capability to the transport is half the work; the
mesh-era call site has to be taught to use it in the same change.
