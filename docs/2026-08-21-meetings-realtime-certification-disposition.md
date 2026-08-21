# Meetings realtime — certification disposition

**Date:** 2026-08-21
**Status:** investigation CLOSED at founder ruling. Not a repair. No deployment.
**Production:** remains reverted at `4420602`.
**Certification branch:** `realtime-negotiation-certification`

This record exists so the next session does not re-derive any of it. Nothing
below authorises a deployment or a repair design.

---

## 1. Founder ruling

The Meetings realtime investigation stops here. Explicitly **not** to be
pursued: repeated rejoin-cycle experimentation, 3+ participant mesh, TURN/relay
reproduction, further harness expansion, native rollback investigation, another
repair design, another production deployment.

Further realtime fixes may be founder-validated directly on the live product
when a bounded fix is ready, or local certification may resume later if product
evidence requires it.

---

## 2. Production disposition

| | |
|---|---|
| Safe build | `4420602` |
| One-way media | can still occur |
| Workaround | leave / rejoin — still works |
| `9815742` regression | no longer live |

**`9815742`** — FAILED founder production certification. It is retained as
historical evidence, **not** as an accepted repair.

---

## 3. What is established

### Original defect — REPRODUCED

An answerer may negotiate while its local media is unavailable and finish with
**missing senders**. Mechanism, in product code:

`session:offer` arrives → `_ensureMediaReady` hits its own
`if (state.isMediaBusy) return;` early-return → `handleRemoteOffer` runs with a
null local stream → `_attachLocalTracks` logs `attach: NO local stream` → the
answer is recvonly. The far side settles at `SendOnly`, permanently, and
`setCameraEnabled` cannot help because it only flips `enabled` on tracks that
already exist.

Product workaround: leave/rejoin.

### Attempted repair

A local silent-peer repair **can** restore duplex. The heartbeat-triggered
production design was unsafe. The founder-observed **bilateral fatal overlay
causal chain remains INCOMPLETELY REPRODUCED.**

---

## 4. Evidence from the enhanced rig

All from two real `RealtimeController`s over real peer connections, real
`getUserMedia`, real SDP. Run reports in
`lib/rtc_harness/certification/evidence/`.

1. **Repair can execute inside the join/rejoin lifecycle.** `_startHeartbeat()`
   calls `_sendHeartbeat(isFirst: true)` synchronously, so the sweep lands
   between `join-seq 5` and `join-seq 8`.
2. **Repair can introduce an additional offer while join negotiation is
   active.**
3. **A real `InvalidStateError` was reproduced** (§6).
4. **Canonical offer authority is fragmented across multiple initiators** (§5).
5. **Watchdog competition exists** — and the watchdog carries no offer identity.
6. **Symmetric glare is survivable in two-party web** — the earlier causal
   story is disproven (§7).
7. **The explicit web rollback implementation is defective** (§8).
8. **The fatal join overlay is NOT locally reproduced.**

No stronger conclusion than the above is supported.

---

## 5. Offer-authority map (production tree, `4420602`)

Six independent initiators. Only three route through the canonical queue.

| # | Initiator | Route | Queue? |
|---|---|---|---|
| 1 | `_reconcileRtcPeers(reason)` | `_queueOfferTarget` → `_flushPendingOffers` → `_sendOfferToSocket` | ✅ canonical |
| 2 | `_onPeerTransportDead` | `_queueOfferTarget` → `_flushPendingOffers` | ✅ |
| 3 | `retryMedia()` (user "Retry") | `_ensureMediaReady` + `_reconcileRtcPeers('track-change')` | ✅ via #1 |
| 4 | `_armAnswerWatchdog` (8s) | **direct** `_sendOfferToSocket` | ❌ bypasses |
| 5 | `_renegotiateExistingPeers` (screen share) | **direct** `_sendOfferToSocket` per peer | ❌ bypasses |
| 6 | `_performIceRestart` | **direct** `emitAck('session:offer')` | ❌ bypasses queue *and* `_sendOfferToSocket` |
| 7 | *(9815742 only)* `_repairSilentPeersIfAny` | **direct** `_sendOfferToSocket` | ❌ bypasses |

`_reconcileRtcPeers` re-offers to an existing peer only for the renegotiation
reasons `camera-toggle`, `mic-toggle`, `screen-toggle`, `track-change`.
`_pendingOfferTargets` is a map keyed by peerKey, so the canonical queue is
already single-slot per peer; every bypass forfeits that.

**Watchdog has no offer identity.** It is armed by every `_sendOfferToSocket`
and fires 8s later against whatever is in flight *then*. Captured: one side
emitted two offers to the same peer 436ms apart — a heartbeat repair, then a
watchdog re-offer armed eight seconds earlier **by the join offer**.

---

## 6. Join-path timeline (case L1, known-bad tree)

```
 9391  socket DROP zz-second                  grace arms; joinState stays `joined`
10087  [rtc-repair] skip peer=zz-second verdict=healthy
11402  RECONNECT zz-second -> zz-second-rc    NEW socket id
11413  [join-seq] 1 socket connected socketId=zz-second-rc
11413  [join-seq] 2 session join emitted
11413  [join-seq] 3 session join ack received
11413  [join-seq] 4 state.isJoined=true
11413  [join-seq] 6 first heartbeat sent      6 PRINTS BEFORE 5 —
11413  [join-seq] 5 heartbeat started         the first beat is synchronous
11414  [rtc-repair] added audio peer=aa-first   REPAIR, INSIDE THE JOIN
11415  [rtc-repair] added video peer=aa-first
11415  [rtc-repair] repaired 1 peer(s); re-offering
11415  [join-seq] 8 media+negotiation complete
11419  session:offer   zz-second-rc -> aa-first
11486  [rtc] glare: polite ROLLS BACK then accepts peer=zz-second-rc
11496  session:answer  aa-first -> zz-second-rc
       aa-first.errorMessage = InvalidStateError: setLocalDescription —
                               Called in wrong state: have-remote-offer
```

**Minimal causal sequence**, all on the far side (`aa-first`, polite):

1. `participant.joined` for the rejoiner's new id → `_flushPendingOffers` →
   `_sendOfferToSocket` → `_makingOffer = true` → **`await createOffer()`**.
2. During that await the in-join repair's offer arrives → `handleRemoteOffer`
   sees `_makingOffer` → collision → polite branch → rollback (throws, §8) →
   `setRemoteDescription` → `have-remote-offer` → answers.
3. The original `createOffer` continuation resumes and calls
   `setLocalDescription(offer)` on a connection that has moved on →
   **`InvalidStateError`**.

`_flushPendingOffers` **catches** it and writes `state.errorMessage`, so
`joinState` never leaves `joined`. `meeting_live_room_screen.dart:3634` gates
its fatal overlay on `joinState == failed && errorMessage != null`, so the
meeting overlay does not appear. `realtime_room_screen.dart:1233` renders on
`errorMessage` alone, so on thread/DM/conversation call surfaces this **is**
user-visible.

**Attribution** — same drop and rejoin, baseline tree: no error, no second
offer, and no recovery either (`SendOnly` / `RecvOnly` forever). The colliding
offer is supplied by the 9815742 repair.

---

## 7. Disproven: the symmetric-glare causal story

The earlier explanation — *symmetric repair → glare → fatal join failure* — is
**rejected for two-party web**.

Deterministic collision control (the gateway parks genuine
controller-generated offers and releases them together) produced real glare:
two `impolite IGNORES` and one `polite ROLLS BACK`. The system recovered to
`SendRecv` on both sides, `joinState` never left `joined`, no error surfaced.
The no-collision control with the identical injury produced **zero** glare, so
the collision was injected rather than lucky.

---

## 8. Explicit web rollback defect — SEPARATE, OPEN, NOT FIXED

`handleRemoteOffer` builds `RTCSessionDescription(null, 'rollback')`.
`dart_webrtc-1.8.1/lib/src/rtc_peerconnection_impl.dart:274` dereferences
`description.sdp!`. On Flutter Web the polite side's explicit rollback
therefore **always** throws `Null check operator used on a null value`, and the
product swallows it.

Strongly supported that Chrome's *implicit* rollback inside
`setRemoteDescription` masks this (rollback failed, yet the exchange completed
and returned to `Stable`); not formally isolated. Not causal in any reproduced
failure. **Not fixed. Not used to explain the web incident.**

---

## 9. Polite-side observability — established

The healthy side holds **authoritative negotiated evidence** about a silent peer:

- `transceiverDirections = {audio: SendOnly, video: SendOnly}` — SDP truth,
  agreed by both ends.
- Receiver counting is a **false lead**: receivers exist either way.
- **Roster/signaling metadata actively lies** — it reported the silent peer as
  `audioOn: true, videoOn: true`.

**Intentional disablement stays distinguishable.** Camera off and mic off:
senders remain `["audio","video"]`, negotiated direction remains `SendRecv`,
zero offers generated. Direction cannot confuse a disabled track with a missing
sender.

Recorded as a finding only. **No repair is designed around it.**

---

## 10. The harness

`lib/rtc_harness/` — separate entrypoint, own `main()`, not reachable from
`lib/main.dart`, not in `router.dart`, verified absent from every release
bundle. See `lib/rtc_harness/README.md`.

The one product-side addition is
`RealtimeMediaService.debugPeer()` — `@visibleForTesting`, read-only, called by
no product code.

**Rig defect found and corrected** (recorded because it briefly produced a false
product failure): `Party` held a frozen socket id, so after a reconnect every
probe queried the pre-reconnect key and reported healthy peers as missing.
Identity now follows the live socket and traffic is counted across the id
history. The first join-path read was wrong for this reason; the corrected run
is what §6 reports.

---

## 11. Meetings status going forward

| # | Item | Status |
|---|---|---|
| 1 | One-way realtime media | **OPEN / ROOT-CAUSED / REPAIR NOT YET CERTIFIED** |
| 2 | Camera-off / black-frame presentation | **OPEN / SEPARATE PRODUCT FINDING** |
| 3 | Refresh continuity | **OPEN** |
| 4 | Explicit web rollback defect | **OPEN / SEPARATE REALTIME DEFECT** |
| 5 | TURN / multi-peer / rejoin-stress | **NOT CERTIFIED** |
| 6 | Meetings visible-product certification | **PARTIAL / continues as product validation** |

None of these block unrelated reconstruction work.
