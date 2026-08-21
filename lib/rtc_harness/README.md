# Realtime negotiation certification harness

**Not product.** A separate entrypoint with its own `main()`. It is not reachable
from `lib/main.dart`, is not registered in `router.dart`, and is therefore not in
any release bundle. It exists to falsify negotiation designs before one is
proposed for production — nothing here may ever be shipped.

Production remains reverted on `4420602`. This directory authorises no
deployment.

## What is under test, and what is substituted

The rig runs **two real `RealtimeController` instances** on one page, over real
`RTCPeerConnection`s, real `getUserMedia`, real SDP and real ICE. Under test,
unmodified: the join sequence and `RealtimeJoinState` machine, the offer queue
(`_queueOfferTarget` / `_flushPendingOffers`), the 8s answer watchdog, the 10s
heartbeat, the perfect-negotiation politeness rule, and error propagation.

Only two edges are substituted, each preserving the invariant it touches:

| Edge | Substitute | Why the invariant survives |
|---|---|---|
| `RealtimeSocketService` | `SignalHub` + `HarnessSocketService` | Relays by `targetSocketId`, stamps `fromSocketId`/`userId`, broadcasts `session:participant.joined` — the gateway's actual contract. It also **assigns socket ids**, which is what lets a case place the injured participant on the polite or impolite side deliberately. |
| `RealtimeRepository` | `HarnessRepository` | Serves a `kind: MIXED` meeting bundle whose REST roster carries **no live socket ids**, because production's does not. That absence is the entire reason "the existing peer offers, the newcomer only answers" holds. |

## The two injuries

Both drive the product through its own code until it injures itself. Neither
strips a sender by hand.

- **Answerer silence** (`MediaInjury.stallAcquisition`) — acquisition stalls, so
  the inbound offer lands while `_ensureMediaReady` is busy. The controller's own
  `if (state.isMediaBusy) return;` early-return then lets `handleRemoteOffer` run
  with a null local stream and answer recvonly. This is 381c452's defect.
- **Offerer silence** (`MediaInjury.denyAcquisition`) — devices are unavailable,
  so `_flushPendingOffers` proceeds without media (deliberately: a recvonly
  connection still lets the user see and hear) and offers with zero senders.

## Deterministic collision control

A collision cannot be produced by hoping two free-running 10s timers land inside
a ~150ms window, and it does not need to be. The gateway owns **delivery**, and
simultaneity is a delivery property. So `SignalHub` can park genuine,
controller-generated offers and answers at the wire and release them together.

The harness **may**: hold, delay, drop and re-release frames; expose what is in
flight. The harness **may not**: fabricate SDP, call repair, offer on a
controller's behalf, bypass politeness or the offer queue, or fake a join state.
It controls *when* real signalling arrives, never *what* the controllers do.

Holding is itself a production condition — the offer relay is fire-and-forget.

## Running

```bash
python lib/rtc_harness/certification/design.py {baseline|legacy}
flutter build web --release -t lib/rtc_harness/main.dart \
    --dart-define=DESIGN=legacy --dart-define=CASES=D,D2,E,E2 \
    --output=build/harness_legacy
bash lib/rtc_harness/certification/run.sh "$PWD/build/harness_legacy" legacy
```

`run.sh` serves the build and captures the JSON report the page posts back to
`/report`, rewritten after every case so a run that dies late still leaves its
completed cases on disk. Chrome is launched with a throwaway profile and fake
media devices; no account, no backend and no signed-in browser are involved.

`design.py` switches the product tree between designs by rebuilding it from the
snapshot in `certification/pristine/`, never by layering one patch on another —
a certification run must be attributable to exactly one tree.

`DESIGN=` only labels the report. The harness is design-blind: it joins two
controllers, injures them, controls delivery, and watches.

## The one product-side addition

`RealtimeMediaService.debugPeer()` — a `@visibleForTesting`, read-only accessor
returning the live `RTCPeerConnection` so the harness can read signalling state,
senders, receivers and transceiver directions **independently of the code that
implements them**. It mutates nothing and no product code calls it.
