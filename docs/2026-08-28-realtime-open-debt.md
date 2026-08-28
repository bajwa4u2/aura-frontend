# Realtime — open debt after the 2026-08-28 session

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

**Stop-sharing remains UNVERIFIED.** The call ended before we reached it. The
camera-restore half of the repair has never been exercised in a real call.

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
* **`STAGE_SCREEN_TRACK_ROW_WITHOUT_PUBLICATION`** — OPEN, medium. A SCREEN
  track row is written from the `session:screen.set` socket event with
  `providerTrackName = null`: ACTIVE, direction SEND, and nothing on the wire.
  Observed on the failed share. The server reports a screen share that does not
  exist. Unconsumed authority again, in the other direction.
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

