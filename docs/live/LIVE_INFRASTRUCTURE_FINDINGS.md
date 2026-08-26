# Cloudflare Realtime migration — measured account and contract findings

**Date:** 2026-08-26. **Task:** Cloudflare Realtime + Live distribution migration,
§4 and §5. **Status:** measurement complete; one architectural fork requires a
founder decision before implementation.

Everything below was measured against the authenticated account or read from
current official Cloudflare documentation. Nothing is inferred from marketing.

---

## 1. Account state, measured

| Product | State in this account |
|---|---|
| **Realtime (SFU + TURN)** | Available, **not yet enabled** — dashboard shows the subscribe/onboarding page |
| **Stream** | **Not enabled** — dashboard shows the plans/purchase page |
| **R2** | Already in use by Aura (existing media path) |
| **Workers** | 6 present |

Neither Realtime nor Stream is active yet, so nothing has been provisioned.

## 2. Pricing, measured

**Cloudflare Realtime (SFU and TURN together):**

* **$0.05 per GB of egress**
* **1,000 GB/month free**, shared across SFU *and* TURN — not two allowances
* Only Cloudflare→client egress is billed. **Traffic pushed to Cloudflare is
  free.**
* Traffic between Realtime TURN and Realtime SFU or Cloudflare Stream
  (WHIP/WHEP) is **not double charged**
* Billed as a single line item

**Cloudflare Stream:**

* Entry option at **$0/month base**, usage-based
* **$5 per 1,000 minutes stored**
* **$1 per 1,000 minutes delivered**
* Bundles exist ($5/mo Starter, $50/mo Creator) but are not required

Both are usage-proportional with no fixed commitment. This satisfies the cost
discipline in §28: the architecture scales, and the bill scales with adoption.

## 3. THE FORK — the assumed pipeline does not exist

§13 authorised this target:

```
STAGE SFU → controlled broadcast egress → Cloudflare Stream live input → LL-HLS
```

**Cloudflare provides no egress from its Realtime SFU into Stream.** Measured
from the official Realtime SFU changelog:

* the only egress mechanism is the **Media Transport Adapter**, which is
  **WebSocket only**;
* audio egress is PCM over WebSocket;
* **video egress is JPEG frames at approximately 1 FPS** — intended for
  thumbnails, snapshots and computer-vision pipelines;
* there is **no RTMP or SRT egress**, and no mention anywhere of publishing SFU
  output into a Stream Live Input.

And from the Stream side, a Live Input accepts **RTMPS and SRT** — neither of
which a browser can produce, and neither of which the SFU emits.

So the middle arrow in the authorised diagram has no supported implementation.

### The second constraint, which closes the obvious workaround

Cloudflare Stream *does* support **WHIP** (WebRTC ingest, browser-native) and
**WHEP** (WebRTC playback). That would let a browser publish to Stream with no
media server at all. But the documentation is explicit:

> WHIP and WHEP must be used together — we do not yet support streaming using
> RTMP/SRT and playing using WHEP, or **streaming using WHIP and playing using
> HLS or DASH**.

**A WHIP-ingested broadcast cannot be delivered as HLS or LL-HLS.** The two
paths are mutually exclusive.

WHIP/WHEP is additionally **beta**, and during beta:

* **recording is not supported** ("coming soon")
* simulcast is not supported
* **live viewer counts are unavailable**
* **analytics are unavailable**

## 4. The three real options

| | **A. WHIP → WHEP** | **B. Bridge → LL-HLS** | **C. SFU fanout** |
|---|---|---|---|
| Stage | Realtime SFU | Realtime SFU | Realtime SFU |
| Audience transport | WebRTC (WHEP) | LL-HLS over CDN | WebRTC via SFU |
| Host upload | constant | constant | **constant** |
| Latency | sub-second | 2–5 s | sub-second |
| Concurrent viewers | "no limits" (Cloudflare) | effectively unlimited | SFU fanout |
| **Recording / replay** | **No** (beta gap) | **Yes** | No |
| Viewer counts / analytics | **No** (beta gap) | Yes | Via Aura's own presence |
| Extra service required | **None** | **Yes — SFU subscriber + encoder + RTMPS publisher** | **None** |
| Maturity | beta | GA | GA |
| Audience cost @1 Mbps, 1 000 viewer-hours | ~450 GB → **~$22.50** | 60 000 min → **~$60** | ~450 GB → **~$22.50** |

**Option B is the only one that delivers LL-HLS and recording — and it is the
only one that needs a service Cloudflare does not provide.** That bridge would
have to join the SFU as a server-side WebRTC subscriber, composite the stage,
encode, and push RTMPS to Stream. That is always-on transcoding compute
(ffmpeg/GStreamer class), with per-broadcast CPU cost on Railway.

This is precisely the §31 return condition: *the SFU→LL-HLS bridge requires a
major unplanned service*.

### A fourth shape worth naming

The host's client already receives every stage track through the SFU. A browser
can composite that stage to a canvas (`captureStream` + WebAudio mixing) and
publish the composite by WHIP — producing a true mixed broadcast with **no
server bridge**. Cost is host CPU and one extra constant upstream, never a
per-viewer cost. It does not unlock HLS or recording (§3's constraint still
applies), and it makes the host's device the mixer, which has thermal
consequences on mobile.

## 5. What is NOT blocked by this fork

The fork concerns the **audience** path only. These proceed regardless, because
all three options use the same stage transport:

* Cloudflare Realtime **SFU for interactive A/V** — thread calls, meetings,
  Live stage (§8, §12)
* Cloudflare **TURN, including TLS 443** — retires
  `TURNS_TLS_443 = BLOCKED_EXTERNAL` (§11)
* Retiring the **four-participant mesh limit** (§9)
* The provider-independent Aura contracts (§6), which exist precisely so the
  audience implementation can be swapped without touching Live product logic

## 6. Recommendation

**Stage and relay: proceed now.** Enable Realtime, implement the adapters,
migrate A/V to the SFU, prove TURN/TLS 443, retire the mesh ceiling. All
measured, all within the authorised economics, no unplanned service.

**Audience: option A (WHIP → WHEP) first, with option B added later behind the
same Aura contract.** Rationale:

* it satisfies the actual product invariant in §14 — the host uploads once and
  audience cost never scales host upload;
* it needs no unplanned service and no new operational surface;
* it is cheaper per viewer-hour than the LL-HLS path at comparable bitrate;
* recording, replay and analytics are the real losses — and they are **deferred,
  not abandoned**, because `AudienceDistributionProvider` and
  `RecordingProvider` keep option B implementable later without touching Live
  product code.

The honest cost of that recommendation: **no replay and no Cloudflare-side
analytics until either the WHIP beta closes those gaps or the bridge service is
authorised.** Aura can still count its own audience through its own presence
model, so viewer count is not lost — only Cloudflare's version of it.

---

## Sources

- Cloudflare Realtime pricing — https://developers.cloudflare.com/realtime/pricing/
- Cloudflare Realtime SFU changelog — https://developers.cloudflare.com/realtime/sfu/changelog/
- Cloudflare Stream WebRTC (WHIP/WHEP) beta — https://developers.cloudflare.com/stream/webrtc-beta/
- Cloudflare Stream Live — start a live stream — https://developers.cloudflare.com/stream/stream-live/start-stream-live/
- Cloudflare blog, *WebRTC live streaming to unlimited viewers* — https://blog.cloudflare.com/webrtc-whip-whep-cloudflare-stream/
- Cloudflare blog, *Low-Latency HLS support for Cloudflare Stream* — https://blog.cloudflare.com/low-latency-hls-support-for-cloudflare-stream/
