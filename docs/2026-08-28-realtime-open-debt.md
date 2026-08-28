# Realtime — open debt after the 2026-08-28 session

---

## FROZEN — MEETINGS SURFACE, 2026-08-28

**Founder ruling:** *"everything good so far in meetings, freeze/lock this state
after inspection of data. We should not touch meetings again until I found
something wrong."*

**Do not modify the meetings surface.** Not to improve it, not to make it
consistent with the conversation surface, not to apply a fix that "obviously"
belongs there too. It is working, it was verified, and it stays as it is until
the founder finds a fault.

### The state being frozen, inspected not assumed

Session `cmtde8u2m…`, three participants, ~14 minutes, ended 00:31:56.

```
transports  3 created, 0 left open      no orphaned provider sessions
tracks      12, ALL ENDED, 0 ACTIVE     nothing left subscribable
departures  00:33:27 / 00:33:48 / 00:34:07, each explicit
```

Staggered explicit departures with NO 60-second heartbeat decay — this call
ended properly rather than dying, which is what distinguishes it from the three
that failed earlier the same evening.

Verified working in this state: three-party meeting; invite link to a guest,
login gate, join; screen share start AND stop with camera restore; clean
teardown.

### The honest edge on this freeze

The freeze is on the SURFACE. Several open items live in code the meetings
surface SHARES with conversation calls — the media service, the stage
transport, `stage-media-authority.service.ts`. Two open items in particular
cannot be fixed anywhere without reaching meetings:

* `PHANTOM_TRACK_ROWS_FROM_SOCKET_STATE` — present in the frozen session itself
  (12 track rows, only 5 carrying a provider name).
* `STAGE_NO_ICE_RECOVERY`, and transport recovery generally.

So "do not touch meetings" cannot mean "never change shared code", or the
platform stops moving. It means: **meetings is not a place to make changes FOR,
and any shared change that could reach it must be declared as such and
re-verified on meetings before it is called done.** Silently altering meetings
through a shared path would violate the freeze exactly as much as editing its
screen.

---

Recorded so none of it depends on anyone remembering. Ordered by what a
person actually feels, not by how interesting it is to fix.

---

## 0. STATE AT END OF 2026-08-28

Closed today, founder-certified or measured: private conversation disclosure
boundary, SFU media (two- and three-party), **global SFU cutover**
(`REALTIME_SFU_CLIENT_PATH=enabled` — note the value is the literal string
`enabled`, not a boolean), provider track-name uniqueness, late-answer call
invites, session auto-end under recovering participants, messages-list N+1,
the 429 rate-limit split, and the native screen-share owner-tag trap.

Everything below is what remains.

---

## 1. `JOINED_LOST_MID_CALL` — the one under several symptoms

The controller stops considering itself joined while the call is still running.
Two separate reports are almost certainly this same cause:

* the PiP renders its **passive** variant (`_resolve()` only sets
  `isOwner: true` while `isJoined && session.isActive`), which is why the
  return button had no handler at all;
* **after 7–10 minutes a long call drops to "connecting" and re-hydrates.**

Not explained. Candidates not yet ruled out: the 15-minute access token, a
socket reconnect, the stale-presence sweep (15s cadence, 30s stale window).
None of them obviously produces 7–10 minutes, which is exactly why it needs
evidence rather than another guess.

### What was established 2026-08-28, with both sides observed at once

```
SERVER   bajwawrites  ACTIVE, heartbeat ~6s old
         zakria       ACTIVE
         mrshah       DISCONNECTED
CLIENT   Chrome       "Connecting… Setting up your session" at 06:39 in
                      0 HTTP calls in 120s · navigator.onLine = true
```

Heartbeats travel over the SOCKET, not HTTP, so zero HTTP calls is consistent
with a live socket — and the server had just received one.

```
FIRST_BROKEN_ARROW = server participant ACTIVE (heartbeats arriving)
                     -> client renders "Connecting…" / not joined
```

The transport is NOT implicated: all three Cloudflare stage transports were
open and carrying media throughout. It is the client's own
`joinState`/`connectionStatus` drifting out of agreement with a session it is
demonstrably still connected to.

Hypothesis tested and DISCARDED: the 5-minute `WebReleaseWatch` inserting
`_ReleaseAvailableBanner` and remounting the subtree. No banner was present
while the fault was on screen.

**Next step, and it is instrumentation rather than a fix:** record the
`JOINED true -> false` transition with its trigger, alongside socket
connect/disconnect and app-lifecycle state (founder ruling §D). Client change,
so it does not ship until it has been through a real call.

A consequence of this defect was ending calls outright until today's auto-end
repair — see §7. That repair stops the ENDING; it does not stop the flicker.

---

## 2. `SUBSCRIBER_TRANSCEIVERS_NEVER_RETIRED`

Measured live: `transceivers` climbing 6 → 8 → 10 → 12 → 14 with
`receiving=12 bound=2`. Every subscribe that renegotiates adds `recvonly`
m-lines and **nothing ever removes them**.

The server-side half is fixed — a republish now ends the track rows it
supersedes, so `listSubscribableTracks` stops offering dead tracks. That
prevents *new* subscriptions to them. It cannot retract an m-line that already
exists on the peer connection, which is what the growth is.

**The remaining fix is client-side** and is the same work as folding open +
initial publish into one negotiation (lever 1): close superseded receivers, or
reuse a transceiver for a replacement track instead of negotiating a new one.

---

## 3. `PIP_NEEDS_REBUILDING` — founder judgement, 2026-08-28

> *"pip itself is useless in current state and needs rebuilding but its not a
> right time to do it with already accumulating debt"*

Deliberately NOT started. The floating call widget has accreted: two resolution
paths (owner / passive presence), owner-gated controls that silently disabled
the only way back into a call, and a card that suppresses itself during a
post-end race. The return handler is wired now, so it is no longer a dead
button — that is a repair, not the rebuild.

**Do not treat this as authorised work.** It waits for a deliberate decision
about what the minimised-call surface is *for*, alongside the in-call
presentation reconstruction it belongs with.

---

## 4. `POST_ACCEPT_CONNECT_LATENCY`

~5s from accept to seeing someone; previously 7–12s. The parallelisation
attempt was **reverted** — it moved the `!isMediaReady` check ahead of the
config fetch and let a redundant capture-and-republish run mid-call, which is
what triggered the participant mixing in front of a guest.

Real remaining costs, measured: `openTransport` round trip through our API to
Cloudflare, the ICE-connect wait before publishing, and a second negotiation
for publish. Lever 1 addresses the last of these and overlaps with debt 2.

---

## 5. In-call presentation reconstruction

Reverted with the chrome restructure and still owed: media-first canvas,
controls on demand, identity on hover/tap, Share Screen + Go Live +
participant management under `More`, no redundant primary Participants
control. The tile layer already complies; the header and dock do not.

---

## 6. Smaller, recorded, unfixed

* `CAMERA_STATE_NOT_PROPAGATED_TO_REMOTE_ROSTER` — remote `vOn` stayed true
  through a camera-off. Nothing depends on it today because tiles key on the
  live track, but an avatar-on-camera-off presentation could not rely on it.
* Duplicate ROSTER entries — the grid seats one person once, but the
  duplication itself is unfixed and merely no longer visible.
* One disclosure-remediation residual: a message its author can no longer
  open. Moving it would manufacture false history.

---

## 8. From the whole-system pass — `docs/2026-08-28-calling-system-transition-gaps.md`

Walking every call-lifecycle transition instead of waiting for reports found
ONE structural defect under several symptoms: **on the stage path local media
was published exactly once, at attach, and never again.** `publishLocal()` had
a single call site. Everything that changed local media afterwards iterated
`_peers` — empty under the stage — and so reached nobody, silently, while the
person doing it saw every sign of success.

* **`STAGE_OUTBOUND_NEVER_REPUBLISHED`** — REPAIRED, unverified in a call.
  Screen share start/stop, camera and mic device selection, and camera
  re-acquisition now route through one transport-aware method. Screen share was
  reaching nobody for every user from the moment the global SFU cutover landed.
* **`STAGE_NO_ICE_RECOVERY`** — OPEN, high. `checkPeersHealth()` iterates
  `_peers` and is a no-op on the stage; the only ICE handler is the one-shot
  completer at open, never re-armed. No failure detection, no restart
  (`restartIce`), no TURN rotation (`updateIceConfiguration`). A transport that
  dies mid-call stays dead until somebody hangs up. **Candidate cause for §1
  `JOINED_LOST_MID_CALL` — measure before assuming otherwise.**
* **`STAGE_NO_ADAPTIVE_QUALITY`** — OPEN, medium. Bitrate cap, degradation
  preference and `collectQualitySample` are all mesh-only, so the adaptive loop
  in `_adaptToSample` runs on empty input and we have no outbound stats from
  the stage path.
* **`STAGE_REPUBLISH_AFTER_NO_CAPTURE`** — OPEN, low. Replacement needs an
  existing sender. A call that published no video at attach (camera denied, or
  audio-only) needs a real publish and renegotiation. Now reported as
  `REPLACE_NO_SENDER` instead of failing silently.

### Live results, 2026-08-28 evening — two calls, sessions cmtdd92hc / cmtdddq3l

**`STAGE_OUTBOUND_NEVER_REPUBLISHED` is VERIFIED CLOSED for the web publisher.**
Trace `op=REPLACE kind=video track=b4d33f88` at 19:59:44, and the receiving
participant confirmed he could see the shared screen. Proven end to end, not
inferred from a green suite.

**Stop-sharing VERIFIED CLOSED, 20:30 in a three-party meeting.** Two REPLACE
traces carrying DIFFERENT track ids -- `dd0cd40f` on start, `ab4bb4f1` on stop
-- and the founder confirmed sharing on and off works. The first attempt that
evening produced two traces carrying ONE id, which is what exposed the
`_adoptLocal` defect; the differing ids are the proof the camera now goes back
on the wire.

**SURFACE BOUNDARY, stated because it matters (founder correction).** That
verification happened on the MEETINGS surface. The two surfaces are separate
screens with separate tile rendering:

| | conversation call | meeting |
|---|---|---|
| share starts, remote sees it | VERIFIED 19:59:44 | VERIFIED |
| stop restores camera for remote | **NOT VERIFIED** | VERIFIED 20:30 |

The outbound MECHANISM is common to both -- one `startScreenShare`, one media
service, one transport, and the `op=REPLACE` traces come from that shared
transport -- so the publish path itself is proven. What remains unproven is
stop-share AS EXPERIENCED on the conversation surface, which draws its own
tiles. A working meeting is not evidence about a call; that is the same rule
already recorded for cross-platform certification, applied to surfaces.

Four further gaps, all found by USE rather than by reading:

* **`ANDROID_SCREEN_SHARE_KILLS_CALL`** — OPEN, high. Sharing from Android does
  not fail, it drops the participant out of the call: transport lost at the
  instant of the tap, **no `SCREEN_STATE_CHANGED` event ever recorded for that
  device**, then a 60s decay to heartbeat_timeout. Cause: the packaged manifest
  declares 7 services, all Firebase/GMS, and NO call foreground service; there
  is no `FOREGROUND_SERVICE_MEDIA_PROJECTION` permission anywhere in any merged
  release manifest. The `FOREGROUND_SERVICE_MICROPHONE`/`_CAMERA` permissions
  are declared and unused, above a comment explaining why a backgrounded call
  needs the service that was never built. Never worked; not a regression.
  Interim remedy proposed: hide the control on Android — a button that reliably
  ends your call is worse than an absent one.
* **`STAGE_TRANSPORT_NOT_RECLAIMED_ON_REFRESH`** — OPEN, high. Refreshing mid
  call yields a new socket while the server still holds the participant's
  previous stage transport, so every attach is refused with
  `stage:transport_exists` and the refreshed tab sits in the call unable to
  publish or subscribe. `attachStage` already carries a comment about this dead
  end, written about a half-attached transport; refresh reaches it by another
  road. Recovers only when the old socket fully drops. Strong candidate for
  "after minimising, return doesn't work".
* **`PHANTOM_TRACK_ROWS_FROM_SOCKET_STATE`** — OPEN, medium-high. First seen as
  a SCREEN row with `providerTrackName = null` and assumed screen-specific. It
  is not. Measured on a three-party call 2026-08-28, EVERY participant carried
  **two ACTIVE rows per track type**: one written by the stage publish, with a
  transport id and a real provider name, and one written from the
  `AUDIO_STATE_CHANGED` / `VIDEO_STATE_CHANGED` socket event with neither.
  The second represents nothing on the wire.

  Two authorities for one question — the socket state event and the actual
  publication both claim to say which tracks exist, and only one of them has
  ever touched Cloudflare. Prime suspect for the subscribable count swinging
  2 -> 4 -> 1 across consecutive binds in one call, and for `receiving`
  outrunning `bound`. Predates the 2026-08-28 work.

  The fix is a decision, not a patch: publication is the authority on what
  exists, and socket state events describe INTENT (`the camera is on`), never
  inventory.
* **`STAGE_RETIRE_RETIRES_NOTHING`** — OPEN, medium. Observed
  `op=RETIRE stale=2 retired=0 subscribed=0`: the client correctly identified
  two stale receivers and the server retired zero of them. The client half of
  the retirement work is doing its job; the server half is not.

* **`LOCAL_CAPTURE_NOT_RELEASED_ON_REMOTE_SESSION_END`** — OPEN, HIGH, and the
  most sensitive item in this file. Observed 2026-08-28: the session was ended
  (`SESSION_ENDED` 00:01:43) and the web client **kept the camera engaged**. It
  released only on a manual page refresh. A call that ends must release capture
  immediately, whoever ended it and however it ended — a camera that stays live
  after the call is a privacy failure, not a tidiness one. `resetSessionMedia()`
  is evidently not reached on a session ended remotely; the client tears down
  local media when the PERSON leaves, not when the SESSION does. Same shape as
  every other gap here: a transition nobody wrote a rule for.

* **`REMOTE_TRACK_MUTE_READ_ONCE`** — the cause of "I can see everyone but they
  cannot see me", found 2026-08-28 in a three-party meeting. Both call surfaces
  decide whether to draw video with

      return tracks.first.muted != true;

  read ONCE at build time. `muted` is a live property: a remote track arrives
  `muted = true` and flips to `false` only when frames actually start flowing.
  **Nothing anywhere listens for that transition** — `onMute` / `onUnMute` /
  `onEnded` exist on `MediaStreamTrack` and have no subscribers in the codebase.
  A tile built inside that window renders "camera off" and STAYS there until
  some unrelated rebuild happens to occur.

  It is per-viewer by construction, which is why it looks like a different bug
  to every participant in the same call, and why it has resisted diagnosis: the
  server sees a healthy published track, the client reports `bind_complete` and
  a live attached renderer, and the person still sees an avatar. Every arrow in
  the chain is green.

  Observed exactly: `receiving=3 bound=1 noTrack=0` with `render_none
  participants=2 withVideo=1 held=1` — media arriving, renderer held, tile
  blank. Aggravated when several browser contexts on ONE machine contend for a
  single camera, which lengthens the muted window and makes losing the race
  likely rather than rare.

  Fix: treat `muted` as a stream, not a snapshot — rebuild on unmute.

### TRANSPORT RECOVERY — status at end of 2026-08-28

**What is PROVEN, in real calls:**

* **Transport reclaim** (`4105df4`). A mid-call refresh now recovers instead of
  leaving the tab stageless with every attach refused by
  `stage:transport_exists`. Founder-exercised twice, including the sequence
  "first pixel then after refresh web all normal". This is the fix that has
  actually been saving calls tonight.
* **Rejoin re-establishes media.** A participant who drops now rejoins and
  rebuilds the stage (`op=SUBSCRIBE trig=JOIN` → `PUBLISH` → both sides
  `renderVideo=true`), rather than sitting frozen until `heartbeat_timeout`.
  This only works BECAUSE of reclaim; the rejoin's `openTransport` would
  previously have been refused.

**What is BUILT and has NEVER FIRED: automatic loss detection.** Three signal
choices, each disproved by an induced failure rather than by reasoning:

| signal | why it failed |
|---|---|
| ICE connection state | TOO SLOW — consent freshness is ~30s on BOTH Chrome and Android, so a 15s outage never changed state. I had recorded this as a Chrome-only risk and assumed Android's network callback covered it; the Pixel behaved identically. |
| selected candidate-pair bytes | TOO PERMISSIVE — keeps counting STUN consent traffic while NO media flows, so the probe watched a number rise through an entire outage and reported health. |
| inbound-rtp bytes (current) | measures what the person actually loses; arms only AFTER media has been seen to flow, so a legitimately silent call cannot be torn down. UNVERIFIED. |

The recurring error in my own reasoning, worth more than the fix: **twice I
chose a signal for its theoretical robustness rather than for whether it tracks
what the user loses.** Candidate-pair bytes were strictly more robust as a
connectivity measure and completely useless as a liveness measure. Avoiding a
false positive that way bought a guaranteed false negative — the worse trade,
since a false positive interrupts a working call while a false negative means
the feature does not exist.

Two supporting repairs, both also caused by induced failures:

* **Recovery drives its own retries** (`48af6fc`). The first version made ONE
  attempt and relied on `onLost` calling it again — but `onLost` fires once per
  transport, and by then the transport was destroyed. The three-attempt budget
  was unreachable, and a first attempt made while the network was still down
  ended recovery permanently. *Recovery must not depend on being re-triggered
  by the component that failed.*
* **Diagnostics survive the outage they describe** (`48af6fc`). Reports about a
  network failure were posted over the failed network, so every ICE transition
  and recovery attempt vanished and the trace came back empty. Failed reports
  are now held (newest 40) and replayed marked `queued=1`. *Observability must
  not depend on the resource whose failure it reports.* The first marker was
  `held=1`, which collided with the render diagnostic's own `held=N` counter
  and made the queue unsearchable — fixed to `queued=1`.
* The probe now reports its own reading every ~30s, because twice the trace was
  empty and there was no way to tell a probe that saw health from one that was
  not running.

**Next verification owed:** a 40-second outage, long enough to clear both the
18-second stall threshold and ICE's ~30s consent timeout.

---

**No transport recovery, reconfirmed twice in one evening.** Both calls died
the same way: `PARTICIPANT_TRANSPORT_LOST reason=disconnect`, then exactly 60
seconds of nothing, then `heartbeat_timeout`. No reconnect attempt, no ICE
restart, no recovery of any kind — see `STAGE_NO_ICE_RECOVERY` above. This is
now the single highest-value open item: it is what turns any transient network
or lifecycle event into a lost call.

Also observed, cosmetic: a `media-ready` attach fires during teardown and logs
`stage:participation_revoked`. Harmless, noisy.

The governing lesson, worth more than any single fix: **an interface method
with no caller is not a feature.** `replaceVideoSource` was written,
implemented correctly against the provider, reviewed and shipped — and the
outbound path stayed frozen because nothing called it. Same shape as the
presence event that carried a participant id nobody read.

---

## What is NOT debt

Closed and founder-certified this session: SFU media (two- and three-party),
private conversation disclosure boundary, the messages-list N+1, the rate-limit
split that was returning 429s on Messages, the native screen-share owner-tag
trap, and provider track-name uniqueness.

---

## 7. Closed today, recorded because the reasoning matters

* **`CALL_INVITE_EXPIRES_BEFORE_ANSWER`** — `RING_TTL_SECONDS = 90` was being
  used as admission authority. The accept path itself stamped EXPIRED at 94s
  and 115s while the caller was still on the call, then marked the answerer
  LEFT. Every "his call doesn't work" for one participant tonight was this,
  not transport. The TTL now governs ringing only; DECLINED/REJECTED/REVOKED
  still refuse, because those are decisions and expiry is only the absence of
  one. Proven live: answered at **196s**, admitted.

* **`SESSION_AUTO_END_UNDER_RECOVERING_PARTICIPANTS`** — both auto-end paths
  counted only ACTIVE/JOINING and passed the result as
  `hasActiveOrRecoverableParticipant`. DISCONNECTED is precisely the
  recoverable state. A call could end under people still sitting in it. The
  orchestrator's own comment had disclosed the discrepancy as "not fixed"; it
  stopped being theoretical, so it is closed at both call sites.

