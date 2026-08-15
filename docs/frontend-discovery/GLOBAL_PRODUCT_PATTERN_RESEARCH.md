# Global Product Pattern Research

Patterns and implications. **No imitation recommendations** — the purpose is to challenge Aura's current complexity, not to build an Aura version of another product.

## Realtime: the market distinguishes four things, not one

| Pattern | Example | Mental model |
|---|---|---|
| **Impromptu live attached to context** | Slack Huddles | "we're talking *here*, in this channel/DM" — no scheduling, no invitation, low ceremony |
| **Always-on drop-in room** | Discord voice channels | "the room is open; join whenever" — presence-based, no invitation |
| **Speaker / audience separation** | Discord Stage | "few speak, many listen" — explicit role split |
| **Scheduled meeting** | Meet / Teams / Zoom | ceremony, invitation, admission, record |

**Implication for Aura.** Aura currently has one peer-call model plus a certified Meetings model, and generalises everything else into "a call". The market's four-way split maps almost exactly onto the founder's own framing (DM/Thread/Space/Institution Room/Meeting/Live) — which suggests those distinctions are real product distinctions, not Aura-specific complexity to be simplified away.

**The key inversion.** Aura's realtime complexity is *not* that it has too many contexts. It is that it has too many **implementations** of too few **defined semantics**. Reduce implementations; keep — and finally state — the semantics.

## Session continuity

Every mature product keeps an active session visible and rejoinable while the user navigates elsewhere (persistent call bar/pill). **Aura already does this** (`floating_call_widget`). This is a strength to preserve, not a gap.

## Inbox vs notification centre

The research is directly on point:

- **Slack** organises notifications around channels and threads rather than a single unified feed — a global feed mixes dozens of channels into an unreadable stream, so channel-level scoping keeps notifications contextual.
- **GitHub** uses a full-page inbox aggregating activity across all repositories, so users can triage everything without switching context.

Both are correct — for different jobs. **Continuity** favours contextual scoping; **triage** favours aggregation.

**Implication for Aura.** Aura has both jobs: conversations need continuity, institutional/governance obligations need triage. That argues for exactly two attention surfaces — and against both the current six and a single mega-inbox.

## Badge semantics

Direct findings from the research:

- *Define one badge semantic and document it.* If a badge sometimes means unread messages and sometimes "new offers", users stop forming a mental model.
- *Single-purpose badges are clearer and easier to trust; aggregated badges are powerful but easier to confuse.*
- *Report unread in a badge only when items can actually be marked read and arrivals are relatively infrequent.*
- *Decide the truncation threshold early (99+ / 999+).*

**Implication for Aura.** Aura aggregates without defining. A missed call, an unread DM and a pending institutional approval currently compete in one counter while being materially different obligations.

## Notification centre vs push

Push demands attention whether wanted or not; the in-app inbox is the persistent record — and that persistence is what makes it valuable once notification fatigue sets in. Real-time updating (badge ticks without refresh) is what separates a notification centre from an email folder.

**Implication for Aura.** The frozen backend already separates delivery (push/WNS/APNs/FCM) from the record. The client should mirror that split rather than treating a notification as whatever arrived.

## Complexity traps observed across the market

1. **Feature parity without mental-model parity** — adding a capability without saying what it *means* in that context.
2. **Aggregated badges** — powerful, but they destroy trust once they mean several things.
3. **Uniformity mistaken for coherence** — making every realtime surface look identical hides that they behave differently.
4. **Context as address space** — encoding "acting as X" in the URL rather than in identity, forcing every destination to be built twice.

Aura currently exhibits **all four**.

---

**Sources:** [Slack Huddles vs Calls](https://clickup.com/blog/slack-huddles-vs-call/) · [Slack vs Discord](https://zapier.com/blog/slack-vs-discord/) · [Slack Huddles](https://www.engadget.com/slack-huddles-audio-143014019.html) · [In-app notification centre design](https://www.courier.com/blog/in-app-notification-center-design) · [Notification centre guide](https://www.courier.com/guides/how-to-build-a-notification-center/chapter-1-introduction-to-notification-centers) · [PatternFly notification badge guidelines](https://www.patternfly.org/components/notification-badge/design-guidelines/) · [Badge UI patterns](https://www.setproduct.com/blog/badge-ui-design) · [Unified inbox tradeoffs](https://www.getmailbird.com/use-unified-inbox-without-mixing-work-personal/)
