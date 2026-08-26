# Aura Live — comparator capability bench

**Date:** 2026-08-26. **Chapter:** Live Broadcast reconstruction, §5 and §21.
**Primary comparator:** TikTok LIVE. **Secondary:** Instagram Live, YouTube
Live, Twitch, LinkedIn Live, Zoom Webinars.

Capabilities and user expectations only. No branding, visual assets,
proprietary implementation or mechanically-copied interaction patterns.

---

## 1. The finding that governs everything else

**A broadcast product cannot be built on the topology Aura is using.**

Industry evidence is unambiguous: WebRTC gives sub-500 ms latency but was not
built to scale past small peer-to-peer groups — broadcasting beyond roughly 50
viewers requires additional infrastructure. Aura is currently below even that:
it is full **mesh**, where every stage participant opens a direct peer to every
viewer, so the host's upload cost multiplies by audience size.

The mature 2026 pattern separates two different problems:

| Layer | Protocol | Latency | Why |
|---|---|---|---|
| **Stage** (host, co-host, guests) | WebRTC via **SFU** | < 500 ms | Conversation has to stay conversational |
| **Audience** (watchers) | **LL-HLS** | 2–5 s | CDN economics; scales to unlimited viewers |

The documented shape is WebRTC-fast for presenters, LL-HLS for the audience —
the SFU re-publishes the stage mix to an HLS egress, and watchers join over HTTP
without ever touching WebRTC. Above roughly 10K concurrent, WebRTC becomes
purely the talent layer.

**This is the answer to §12, and it is an infrastructure decision, not a
refactor.** Aura runs no SFU and no HLS egress. Options and the authorization
boundary are in §6.

## 2. TikTok LIVE capability bench

Researched Aug 2026. "Aura before" is what the §4 audit found.

### Creation / producer

| Capability | TikTok LIVE | Aura before |
|---|---|---|
| Start a broadcast directly | Yes | **No — escalation from a call only** |
| Title / topic | Yes | Session title exists, not producer-set for broadcast |
| Preview before going live | Yes | No |
| Camera/mic preparation | Yes | Call preflight exists (A/V chapter) |
| Visibility / audience settings | Yes | No — PUBLIC_STAGE only |
| Scheduled live (LIVE Events) | Yes, with advance viewer notification | No |
| Moderation configured before start | Yes — moderators appointed pre-live | No |
| Layouts (grid / panel / fixed) | Yes | No |
| Effects, camera switching | Yes | Camera toggle only |

### Stage / multi-person

| Capability | TikTok LIVE | Aura before |
|---|---|---|
| Multi-guest | Up to 5 guests | **No** |
| Co-host with another creator | Yes — co-host sessions can each carry their own guests | No |
| Viewer request-to-join | Yes | No |
| Invite to stage | Yes, moderators may invite | No |
| Remove from stage | Yes | No |
| Guests return to origin room on disconnect | Yes | N/A |

### Viewer

| Capability | TikTok LIVE | Aura before |
|---|---|---|
| Discovery feed | Yes | Yes — a 241-line list |
| Viewer count | Yes | Yes — header pill |
| Comments | Yes | **No** |
| Reactions / likes | Yes | **No** |
| Share | Yes | No |
| Follow host | Yes | No |
| Host profile exploration | Yes | No |
| Report / block | Yes | No |
| Purpose-built viewer surface | Yes | **No — the call room with controls hidden** |

### Engagement

| Capability | TikTok LIVE | Aura before |
|---|---|---|
| Q&A — select, showcase, answer | Yes, a dedicated suite | No |
| Polls | Yes | No |
| Pinned comment | Yes | No |
| Mentions | Yes | No |
| AI co-host / pacing assistance | Yes | No |

### Moderation / safety

| Capability | TikTok LIVE | Aura before |
|---|---|---|
| Delegated moderators | Yes | No |
| Keyword filtering | Yes | No |
| Mute / block user | Yes | No |
| Comment controls | Yes | No |
| Age-restricted broadcasts | Yes, where available | No |
| Report | Yes | No |

### Post-live

| Capability | TikTok LIVE | Aura before |
|---|---|---|
| Replay | Yes | **No** |
| Highlight extraction | Yes | No |
| Analytics | Yes, via TikTok Studio | No |
| Recording | Yes, short duration | Session recording model exists, unused for Live |

## 3. Where the comparators disagree, and which Aura should follow

TikTok is the consumer-experience bar. It is **not** the right bar for
everything Aura does.

* **LinkedIn Live and Zoom Webinars** are the better comparator for
  institutional broadcast: registration, verified professional identity attached
  to attendance, scheduled events, structured Q&A, and an explicit posture that
  attendees cannot interrupt. LinkedIn attendees register with their profile,
  which attaches verified identity to attendance — much closer to Aura's
  institutional authority doctrine than TikTok's anonymous-audience model.
* **Twitch and YouTube** are the bar for scale and moderation depth, and both
  use RTMP ingest with HLS/DASH distribution — reinforcing §1.

Aura's differentiation is not "TikTok plus governance". It is that a broadcast
carries **trusted identity, institutional authority where relevant, and durable
continuity** — none of which the consumer comparators attempt.

## 4. Monetization — classified, NOT built

TikTok's gift and coin economy is core to its LIVE product. Per founder ruling
it is **not** implemented for parity.

| Classification | Items |
|---|---|
| **CORE LIVE CAPABILITY** | comments, reactions, Q&A, polls, stage, moderation, discovery, replay |
| **COMMERCIAL / MONETIZATION** | gifts, coins, tipping, competitive LIVE Match formats, creator revenue share |
| **AURA-APPROPRIATE** | none decided — requires a founder ruling |
| **NOT CURRENTLY APPROPRIATE** | gifts and coins as engagement currency; competitive match formats |
| **FUTURE / REQUIRES FOUNDER RULING** | any economic system whatsoever |

**No economic system is introduced without explicit founder approval.**

## 5. Accessibility bar

Live accessibility is a legal and product requirement, not a nicety.

* **WCAG 2.1 SC 1.2.4, "Captions (Live)", is Level AA** and requires captions
  for all live audio in synchronized media.
* Captions must carry dialogue, **speaker changes**, and meaningful non-speech
  sound, and must be visible, synchronized and readable.
* The player must be fully keyboard navigable and screen-reader compatible.
* Auto-playing media actively harms screen-reader users.

Aura has **no captions on Live** today. Live captioning needs either a human
CART pipeline or monitored ASR — an infrastructure dependency to classify
honestly rather than assume.

## 6. Architecture options for §12, and the authorization boundary

| Option | Stage | Audience | Practical ceiling | Cost to Aura |
|---|---|---|---|---|
| **A. Today (mesh)** | P2P mesh | P2P mesh | ~3–5 viewers | none, but it is not a product |
| **B. SFU only** | SFU | SFU | hundreds | a media server to run |
| **C. SFU + LL-HLS egress** | SFU | LL-HLS via CDN | effectively unlimited | media server + CDN egress |
| **D. Managed** (LiveKit Cloud, Mux, Cloudflare Stream, AWS IVS) | managed | managed | unlimited | vendor + recurring cost |

Self-hosted SFUs in common production use: **LiveKit, mediasoup, Janus, Jitsi**.

**This is an external / infrastructure boundary.** Options B–D all require
infrastructure Aura does not run today, plus recurring cost. Under the standing
provider-independence doctrine a self-hosted tier-0 is the direction, with
managed services as optional tier-1 enrichment — but standing up a media server
is a founder-level infrastructure decision, not something to assume inside this
chapter.

**Recommendation: option C** — self-hosted SFU with LL-HLS egress. It is the
documented 2026 default, it keeps the stage conversational, and it makes
audience cost independent of audience size.

---

## Sources

- Euler Stream, *What Is TikTok LIVE? A Complete Guide (2026)* — https://www.eulerstream.com/what-is-tiktok-live
- TikTok LIVE Studio Help Center, *Go LIVE with other creators* — https://www.tiktok.com/live/studio/help/article/Boost-viewer-engagement/Go-LIVE-with-other-creators
- Hivemind Social, *TikTok LIVE Together: Multi-Guest and Co-Host Guide* — https://hivemindsocial.com/tiktok-live-multi-guest-co-host-guide/
- TikTok Newsroom, *All the ways you can enjoy LIVE with TikTok* — https://newsroom.tiktok.com/tiktok-live-features-2021
- Small Business Trends, *New TikTok Live Features for Creators* — https://smallbiztrends.com/new-tiktok-live-features/
- Dacast, *RTMP vs. HLS vs. WebRTC* — https://www.dacast.com/blog/rtmp-vs-hls-vs-webrtc/
- Dacast, *Best Low-Latency Video Streaming Solutions (2026)* — https://www.dacast.com/blog/best-low-latency-video-streaming-solution/
- DEV Community, *Wiring up a hybrid WebRTC + LL-HLS live stack* — https://dev.to/masonwritescode/wiring-up-a-hybrid-webrtc-ll-hls-live-stack-the-protocol-decision-tree-that-actually-works-1h25
- Fora Soft, *P2P, SFU, MCU, Hybrid: Which WebRTC Architecture Fits Your 2026 Roadmap?* — https://www.forasoft.com/blog/article/webrtc-architecture-guide-for-business-2026
- Trembit, *LiveKit vs Mediasoup vs Janus (2026)* — https://trembit.com/blog/choosing-the-right-sfu-janus-vs-mediasoup-vs-livekit-for-telemedicine-platforms/
- GetWCAG, *Provide Captions for Live Video — WCAG 1.2.4* — https://getwcag.com/en/accessibility-guide/multimedia-live-captions
- BOIA, *Does WCAG Require Live Captions?* — https://www.boia.org/blog/does-wcag-require-live-captions
- W3C WAI, *Captions and Subtitles* — https://www.w3.org/WAI/media/av/captions/
- Sprout Social, *The Ultimate Guide to LinkedIn Live* — https://sproutsocial.com/insights/linkedin-live/
- Zoom, *Zoom Webinars* — https://www.zoom.com/en/lp/zoom-webinars/
