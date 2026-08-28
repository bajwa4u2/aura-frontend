# SFU remote media — the first broken arrow

**Date:** 2026-08-28
**Session used as evidence:** `cmtcfy6ai000jo50cwgjcbu1e` — `routingMode = SFU`
**Status:** ROOT CAUSE ESTABLISHED, repaired, awaiting the retest call.

---

## 1. What the founder ruling asked for

> *Do not return a root cause until the new evidence identifies the first
> broken arrow. Do not implement the current timing hypothesis merely because
> it is plausible.*

The timing hypothesis — first arrival subscribes to an empty stage and never
retries — was **eliminated by evidence**, not argued away. Reconciliation
happened, and both subscribes succeeded.

---

## 2. The chain, measured

`RealtimeStageSubscribeDiagnostic`, plus the client-side bind audit added by
`dd58b6c`:

```
08:18:02.369  bajwawrites  JOIN
08:18:05.760  bajwawrites  STAGE_CREATED               d2826a6b6804
08:18:08.530  bajwawrites  PUBLISHED                   AUDIO aura-audio-0
08:18:08.530  bajwawrites  PUBLISHED                   VIDEO aura-video-1
08:18:13.582  zakria       JOIN
08:18:16.508  zakria       STAGE_CREATED               3b3d032048d1
08:18:20.497  zakria       REMOTE_TRACKS_DISCOVERED
08:18:20.715  zakria       SUBSCRIBE_REQUESTED         names=[audio-0, video-1]
08:18:21.285  zakria       SUBSCRIBE_SUCCEEDED         bindings=2 mids=2 missing=[] 570ms
08:18:23.301  zakria       PUBLISHED                   AUDIO aura-audio-0
08:18:23.301  zakria       PUBLISHED                   VIDEO aura-video-1
08:18:32.253  bajwawrites  REMOTE_TRACKS_DISCOVERED    ← reconciliation, unprompted
08:18:32.524  bajwawrites  SUBSCRIBE_REQUESTED         names=[audio-0, video-1]
08:18:32.851  bajwawrites  SUBSCRIBE_SUCCEEDED         bindings=2 mids=2 missing=[] 329ms
08:18:33.723  bajwawrites  CLIENT_BIND_COMPLETE        server=2 transceivers=4 receiving=2
                                                       bound=2 noMid=0 noLine=0
                                                       dirUnreadable=0 noTrack=0
```

Not one of the nine outcomes the ruling asked to be distinguishable came back
negative. In particular **none of the three bind drop conditions fired**:
every server binding named an m-line, every m-line was found, every direction
was readable, every receiver had a track.

The roster panel, at the same moment, read
`Muhammad Zakria — Participant — Joined — Media on`.

The stage drew **one tile**.

## 3. FIRST_BROKEN_ARROW

```
FIRST_BROKEN_ARROW = participant-keyed renderers → the conversation call stage
```

Two maps carry remote renderers, and they answer to different keys:

| Map | Key | Written by |
|---|---|---|
| `remoteRenderersByParticipant` | Aura participant id | the STAGE transport |
| `remoteRenderers` | `runtimeDeviceId` | MESH per-peer `onTrack` / `onAddStream` |

`realtime_media_service.dart:582` and `:617` are the only writers of the
device-keyed map, and both sit inside a per-peer mesh connection. The stage
transport has **one** peer connection and nothing device-shaped to key on, so
under SFU that map is empty for the entire call.

`meeting_live_room_screen.dart` had been migrated to ask identity first.
`realtime_room_screen.dart` — the conversation / thread call surface — had not:
`_CallStage` tested `state.remoteRenderers.isNotEmpty` and `_VideoGrid`
**iterated** `remoteRenderers.entries`. Iterating devices makes a surface
structurally blind to a transport that has no devices.

So the defect was never in Cloudflare, in the subscribe boundary, in the bind
rule, or in timing. It was an **unmigrated consumer** — the recurring
unconsumed-authority shape: the canonical answer was produced correctly and
nobody read it.

### Why "audio one way only" is the same fact

Chrome → Pixel audio worked; Pixel → Chrome did not. A remote track received on
a peer connection plays only when it is attached to a sink. Native Android
routes remote audio to the device output on its own; on web the track reaches
an `RTCVideoRenderer` that the grid never mounted. One tile drawn, one
direction heard.

This is a *consistent* explanation, not yet a proven one — it is confirmed or
refuted by the retest, not by this document.

---

## 4. The repair

Smallest correct change, and an architectural one rather than a patch: the rule
now exists **once**.

* `remote_media_presentation.dart` — new `rendererForParticipant()`. Identity is
  asked first; the device key is used only to *locate* mesh media for a person
  the roster has already named.
* `realtime_room_screen.dart` — `_VideoGrid` builds tiles from the **roster**,
  not from a renderer map. Unclaimed device renderers are still shown, behind
  the existing `shouldShowUnattributedMedia` guard, so the 2026-08-26
  duplicate-tile regression cannot reappear here. `_CallStage` and the two
  defensive meeting stages now ask both maps whether media exists.
* `meeting_live_room_screen.dart` — converged onto the same helper. It behaved
  correctly already; it had its own copy of the rule, and one copy applied and
  one copy ignored is exactly how the two surfaces drifted.
* `test/features/realtime/renderer_for_participant_test.dart` — pins the
  ordering, including the SFU case where the device map is empty and always
  will be.

Nothing in the SFU transport, the subscribe boundary or the bind rule was
touched. The ruling's *"do not modify SFU behavior"* holds: the transport was
correct and the evidence says so.

---

## 5. Still open, deliberately

`SFU_AUDIO_ONLY_WEB_SINK` — `_syncParticipantRenderers` creates a renderer only
when a participant has **video**. A remote participant who is audio-only over
SFU (camera off, or an audio call, where the stage is `_AvatarStage` and mounts
no `RTCVideoView` at all) has their audio track attached to nothing on web.
Native clients are unaffected.

Not repaired here, because the correct fix depends on whether the retest shows
audio-only web playback actually failing — and guessing at it is what this
whole chapter has been avoiding. It is recorded, not deferred silently.

---

## 6. What the retest must show

Both clients need the new build: the Pixel APK in the founder's hands is
`d3fa923`, which predates even the bind audit.

```
SFU_AUDIO_CHROME_TO_PIXEL
SFU_AUDIO_PIXEL_TO_CHROME
SFU_VIDEO_CHROME_TO_PIXEL
SFU_VIDEO_PIXEL_TO_CHROME
CAMERA_OFF_ON_OVER_SFU
LATE_PUBLICATION_RECONCILIATION
LEAVE_REJOIN
GHOST_PARTICIPANT
CLEANUP
```
