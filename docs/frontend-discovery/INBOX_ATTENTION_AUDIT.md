# Inbox / Attention Audit

> ✅ **FD-5 (FROZEN):** Live attention belongs to the **originating Thread/Space** — **no standalone Live Inbox**. Ordinary audience notification is **non-ringing attention**; only explicitly invited speakers/co-hosts/moderators may be interrupted, via the canonical delivery authorities. See `FD5_LIVE_THREAD_SPACE_FROZEN.md`.

> ✅ **FD-10 (FROZEN)** adds attention vocabulary rules: the primary badge means **unresolved actionable obligations**, contextual language names the **actual obligation** (invitation · missed interaction · mention requiring attention · approval/action required), and internal states (`UNSEEN`/`RESOLVED`/`DISMISSED`/`EXPIRED`) appear **only where useful to comprehension**. See `FD10_TERMINOLOGY_FROZEN.md`.

## FINDING A1 — Eight attention surfaces; one unreachable

**Evidence.**

| Surface | File | Router refs | Status |
|---|---|---|---|
| Messages hub | `messages/presentation/messages_hub_screen.dart` | 2 | live |
| Notifications | `notifications/presentation/notifications_screen.dart` | 1 | live |
| Activity | `activity/presentation/activity_screen.dart` (1,423) | 2 | live |
| Direct inbox | `direct_threads/presentation/inbox_screen.dart` | 4 | live |
| Communications centre | `communications/presentation/communications_center_screen.dart` | 1 | live |
| Correspondence hub | `correspondence/...` | 1 | live |
| Updates / module attention | `updates/module_attention.dart`, `notifications_controller.dart` | — | live (infrastructure) |
| **Conversations** | `conversations/presentation/conversations_screen.dart` (1,033) | **0** | **DEAD** |

**PRODUCT CONSEQUENCE.** A person has at least six places where "something is waiting for me" may appear, with no stated rule for which. Attention is the product's most cross-cutting promise and it is the least governed surface in the client.

**ROOT CAUSE.** Each communication capability shipped with its own list, and no attention authority was ever declared. `updates/module_attention.dart` is an attempt at one, added late and not adopted by the older hubs.

**CLASSIFICATION.** DEMOLISH + REBUILD the attention layer; RETIRE the dead surface.

**FD-12 (FROZEN 2026-08-15):** retirement of `conversations_screen.dart` is **authorised** — disposition only, not deletion during adjudication. `InstitutionCorrespondenceScreen` is carried here as a **candidate** for contextual adjudication. See `FD12_SURFACE_DISPOSITION_FROZEN.md`.

**OPTIONS.**
- **A. Communication Inbox (conversations, DMs, threads, spaces) + Notification Centre (everything else), one badge semantic each.**
- B. One unified inbox for everything, filtered.
- C. Contextual attention only — no global inbox; badges live on their contexts.

**RECOMMENDATION.** A. The market research is directly on point: Slack scopes notifications to channels because a global feed becomes unreadable, while GitHub uses a full-page unified inbox because *triage across contexts* is the job. Aura has both jobs — conversations need continuity (Slack-like), institutional/governance events need triage (GitHub-like). One surface for each, rather than six for neither.

**FOUNDER DECISION.** ✅ **RESOLVED — FD-1 ONE GOVERNED ATTENTION HUB + ACTIONABLE ATTENTION, FROZEN 2026-08-15.**

The approved model is **one governed Hub** that projects attention across domains through a small set of semantic views (Conversations · Activity · Invitations · Actions), rather than the two separate surfaces recommended above. Attention is a **projection, never a new owner** of DM/Thread/Space/Meeting/Room/Live objects, and actionable items expose **domain-owned** resolvable actions.

*(Note: identified by name — this is **not** option A/B/C above. A single chronological feed, i.e. original Option B, is explicitly **rejected**.)* See `FD1_ATTENTION_HUB_FROZEN.md`.

**MIGRATION CONSEQUENCE.** Read/unread state and any server-side attention records must be preserved; `updates/module_attention` logic is the best salvage candidate.

**FOUNDER DECISION.** Yes — A/B/C. This is the single highest-value decision in this discovery.

---

## FINDING A2 — Attention vocabulary is conflated

**Evidence.** `unreadCount` (82 occurrences), `unread` (58), plus `unreadCache`, `unreadCacheAt`, `unreadTtl`, `unreadChat`, `unreadMessages`, `UnreadDot`, `UnreadTone`, `UnreadCountProvider` across 19 files. There is no distinct representation for the states the product actually has.

Required product vocabulary, currently collapsed into "unread":

| State | Meaning | Cleared by |
|---|---|---|
| UNSEEN | never surfaced to the person | surfacing |
| UNREAD | surfaced, not opened | opening |
| UNATTENDED | opened, but requires an action | completing the action |
| ACTION REQUIRED | explicit obligation (approval, response) | acting |
| MENTIONED | directed at this person specifically | reading in context |
| INVITED | membership/participation offer | responding |
| MISSED | time-bound and now past (call, live) | acknowledgement only |
| RESOLVED | obligation discharged | — |
| DISMISSED | deliberately set aside without acting | — |

**PRODUCT CONSEQUENCE.** A badge cannot be trusted, because it does not mean one thing. The research finding is explicit: *define one badge semantic and document it; single-purpose badges are clearer and easier to trust; aggregated badges are easier to confuse.* Aura currently aggregates without defining.

Concretely: a missed call, an unread DM and a pending institutional approval are materially different obligations that currently compete in the same counter.

**CLASSIFICATION.** DEMOLISH + REBUILD as an Attention Authority with an explicit state model. **This is architecture, not UI polish.**

**FD-1 (FROZEN) partially governs this finding.** It freezes that **UNREAD is not the universal attention state**, directs modelling of at least `UNSEEN` · `UNREAD` · `INVITED` · `MISSED` · `ACTION_REQUIRED` · `RESOLVED` · `DISMISSED` · `EXPIRED`, requires **clearing semantics owned by the originating domain**, and requires **deterministic reconciliation** so no dead CTAs survive. **FD-2 remains OPEN** for which states are product-visible.

**BACKEND DEPENDENCY.** The frozen backend already distinguishes notification/attention records, delivery attempts and acknowledgement; the client flattens them.

**FOUNDER DECISION.** ✅ **RESOLVED — FD-2 OBLIGATION BADGE, FROZEN 2026-08-15.**

**Primary badge = unresolved actionable obligations.** `ACTION_REQUIRED` · `INVITED` · `MISSED` contribute while unresolved; **mentions contribute only when they represent unresolved attention** and resolve through owning-domain behaviour. **Passive unread never contributes** — unread stays contextual to conversations and content. Internal lifecycle states stay behavioural rather than becoming global vocabulary, though context may still explain expired/dismissed where useful. **Truncation `99+`.**

This closes the finding: the missed call, the unread DM and the pending institutional approval no longer compete in one counter — only the two that are obligations do. See `FD2_ATTENTION_VOCABULARY_FROZEN.md`.

---

## FINDING A3 — Cross-device read state is unspecified in the client

`unreadCache`, `unreadCacheAt`, `unreadTtl` indicate client-side caching of unread state with a TTL. With the frozen multi-device backend, read state resolved locally per device will diverge across devices.

**CLASSIFICATION.** REFACTOR — read state must project backend truth, not be cached and expired locally.
