# Realtime — open debt after the 2026-08-28 session

Recorded so none of it depends on anyone remembering. Ordered by what a
person actually feels, not by how interesting it is to fix.

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

**Next step:** capture a long call's chronology at the moment of the drop.

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

## What is NOT debt

Closed and founder-certified this session: SFU media (two- and three-party),
private conversation disclosure boundary, the messages-list N+1, the rate-limit
split that was returning 429s on Messages, the native screen-share owner-tag
trap, and provider track-name uniqueness.
