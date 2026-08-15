# FD-1 — ONE GOVERNED ATTENTION HUB + ACTIONABLE ATTENTION

# STATUS: FROZEN — FOUNDER APPROVED 2026-08-15

**The canonical identity of this decision is its NAME.** It is deliberately not identified by an option letter.

## Decision history (auditable)

| Step | Record |
|---|---|
| 1 | The original discovery proposed FD-1 options **A / B / C**. |
| 2 | **A** = Communication Inbox + Notification Centre (two surfaces) · **B** = one unified inbox, filtered · **C** = contextual only, no global inbox. |
| 3 | The founder approved **none of them as written**. A distinct model was defined during adjudication. |
| 4 | Founder-approved model: **One Governed Attention Hub + Actionable Attention**. |
| 5 | It **supersedes the original FD-1 option set** where necessary. |

**Relationship to the original options, stated precisely:**
- It is **NOT** original Option B — "one giant chronological notification feed" is **explicitly rejected**.
- It **partially subsumes** Option A's separation, but as **semantic views inside one hub**, not as two separate products.
- It **rejects** Option C's premise that no governed cross-domain projection should exist.

> **Never restate this decision as "FD-1 Option A/B/C".** The decision name is authoritative.

---

## 1. Core decision

The existing fragmented attention architecture **must not survive**. The Release Client moves toward:

> **ONE GOVERNED ATTENTION HUB** answering the human question: **"What needs my attention?"** — without flattening the distinct product domains that generated that attention.

**This is NOT:** one giant chronological notification feed · a renamed notification screen · a dumping ground for every event · another mirrored personal/institution inbox · a replacement for the owning communication/product domains.

The Attention Hub is a **governed PROJECTION** of attention across domains.

---

## 2. Domain ownership remains intact

The Hub does **not** become the owner of: DM · Threads · Spaces · Correspondence · Meetings · Institution Rooms · future Live · replies · mentions · relationships/follows · moderation · publication activity · institutional administration.

Each domain retains its **canonical object · authority · lifecycle · permissions · state · actions · history**. Attention projects only what requires awareness or action.

---

## 3. Proposed semantic views *(architectural direction, not CTA/copy freeze)*

| View | Projects |
|---|---|
| **CONVERSATIONS** | DM, relevant Thread/Space communication, Correspondence and other communication requiring attention |
| **ACTIVITY** | replies, mentions, follows/relationships, reactions, relevant publication activity |
| **INVITATIONS** | Meetings, Institution Rooms, realtime participation, future Live, other legitimate participation invitations |
| **ACTIONS** | matters genuinely requiring a user decision or response |

**Simplify further during design if evidence supports it.** Do not create categories merely because backend event types exist.

---

## 4. Actionable attention

Actionable items must expose **resolvable actions** wherever appropriate. The Hub must not become notification noise.

> **ATTENTION → CONTEXT → ACTION → RESOLUTION → CONTINUITY**

The user should understand: what happened · where it belongs · whether something is required of them · what they can do · whether it has been resolved.

---

## 5. Domain-owned resolution CTAs *(examples only — vocabulary NOT frozen)*

| Attention | Smallest useful action set |
|---|---|
| Meeting invitation | Accept · Decline · View |
| Room / Live invitation | Join · Decline · View context |
| Message / Correspondence | Reply · Open |
| Mention / reply | Reply · View conversation |
| Relationship request *(where the model requires approval)* | Accept · Decline |
| Missed realtime interaction | Call back · Open owning conversation |
| Moderation / administrative | authorised resolution action(s) |
| Informational | View, or resolution via seen/read semantics |

CTA terminology remains subject to **FD-10** (open).

---

## 6. Actions must remain domain-owned *(critical)*

The Hub must **NOT** implement duplicate business logic for meeting acceptance · invitation rejection · replying · calling · moderation · relationship decisions · publication actions · room participation.

```
ATTENTION ITEM
  → DOMAIN ACTION DESCRIPTOR / AUTHORITY
    → CANONICAL DOMAIN ACTION
      → DOMAIN STATE CHANGES
        → ATTENTION PROJECTION UPDATES
```

Attention **orchestrates presentation and routing**. It must not become a second implementation of every product capability.

---

## 7. Direct resolution where appropriate

Where safe and semantically appropriate, common actions (Accept, Decline, Reply, Join, Call back) should be resolvable **directly** from the attention experience.

Do not force: *attention item → unrelated screen → rediscover context → locate action → act → navigate back.*

But direct action must not remove necessary context for consequential decisions. **Use progressive disclosure:** simple decisions direct; complex decisions transition naturally into the owning context.

---

## 8. Routing / redirection

Every item must know its **legitimate owning destination**, and routing must preserve context:

mention → exact post/reply/thread location · message → exact conversation · meeting invitation → meeting context · room invitation → room context · missed Thread call → originating Thread · Space attention → relevant Space location.

> **Do NOT route to generic module landing pages when a canonical contextual destination exists.**

---

## 9. Resolution state — UNREAD is not universal

> **Do NOT treat UNREAD as the universal attention state.**

State-model at minimum: `UNSEEN` · `UNREAD` · `INVITED` · `MISSED` · `ACTION_REQUIRED` · `RESOLVED` · `DISMISSED` · `EXPIRED`, plus any genuinely necessary additions.

**State must have behavioural meaning.** Do not create states for vocabulary completeness.

*(This is directional input to **FD-2**, which remains **OPEN** — FD-1 does not freeze which states are product-visible.)*

---

## 10. Clearing semantics

Opening the Hub must **not** mean "everything has been handled." Attention clears according to its **owning** semantics:

| Act | Clears |
|---|---|
| Viewing | `UNSEEN` |
| Reading content | `UNREAD` |
| Accepting / declining | `INVITED` / `ACTION_REQUIRED` |
| Returning a call or explicit dismissal | `MISSED` |
| Completed domain action | `ACTION_REQUIRED` |

Exact rules determined during authority design.

---

## 11. Dead CTA prevention

Actionable attention must reflect **current** authority/state. No stale Accept / Join / Reply / Call back / Approve when the action is expired · revoked · already completed · no longer authorised · no longer eligible · deleted · otherwise impossible.

**The item reconciles to its actual current state.**

---

## 12. Noise reduction is a primary requirement

Do **not** surface every backend event as a user-facing notification. Investigate: aggregation · deduplication · prioritisation · contextual grouping · resolved-state suppression · low-value activity treatment · interruption vs passive awareness.

> The goal is not *"show everything that happened."* It is *"help the person understand and resolve what deserves their attention."*

---

## 13. Compliance with FD-9 (Contextual Acting Authority)

Do **NOT** create `/inbox` + `/institution/inbox` as mirrored architectures merely because institutional attention exists.

One governed Attention architecture projects according to: authenticated person · active acting context · domain ownership · backend authority.

> Institutional attention may have different **semantics**. That does not justify another **Inbox product**.

---

## 14. Compliance with FD-3 (Realtime Product Semantics)

Realtime attention retains its owning semantics: a missed DM call belongs to **DM** · a missed Thread interaction to its **Thread** · a Space invitation to its **Space** · a Meeting invitation remains a **Meeting** invitation · an Institution Room invitation remains **institution-room** attention · future Live attention belongs to its originating governed context.

> **Do NOT create a generic "Calls" domain merely because several products use realtime infrastructure.**

---

## 15. Communication vs attention

A conversation may contain hundreds of messages. The Hub projects only **the portion currently deserving awareness/action**. Once resolved, the conversation and its history remain in the owning domain.

---

## 16. Frontend Attention Authority direction

Investigate an explicit frontend Attention Authority rather than eight independently evolving implementations. It may govern: attention projection · semantic type · owning domain · destination · state · available actions · priority · aggregation · read/seen/resolved presentation.

> Backend/domain authorities remain **final truth**. The frontend Attention Authority must **not invent permissions or business state.**

---

## 17. Demolition boundary

FD-1 establishes architectural permission to treat the fragmented current attention/inbox implementation as a **DEMOLISH + REBUILD candidate**.

> **Do NOT implement demolition yet.**

**Preserve during reconstruction:** valid underlying domain behaviour · backend contracts · communication histories · notification delivery capability · valid read/unread data · invitation state · deep-link destinations · legitimate user preferences.

**Do not preserve fragmentation** merely because those capabilities currently live on different screens.

---

## 18. Frozen doctrine

> **ONE GOVERNED ATTENTION HUB.**
> **ATTENTION IS A PROJECTION, NOT A NEW OWNER OF DOMAIN OBJECTS.**
> **ACTIONABLE ATTENTION SHOULD PROVIDE RESOLVABLE DOMAIN-OWNED ACTIONS.**
> **ATTENTION → CONTEXT → ACTION → RESOLUTION → CONTINUITY.**
> **DIRECT RESOLUTION SHOULD BE AVAILABLE WHERE SAFE AND APPROPRIATE.**
> **DEEP ROUTING SHOULD RETURN THE USER TO THE EXACT OWNING CONTEXT.**
> **UNREAD IS NOT THE UNIVERSAL ATTENTION STATE.**
> **ATTENTION MUST REDUCE NOISE, NOT MERELY DISPLAY EVENTS.**
> **RESOLVED ACTIONS MUST RECONCILE DETERMINISTICALLY.**
> **ACTING CONTEXT MUST NOT CREATE A SECOND MIRRORED INBOX ARCHITECTURE.**
> **REALTIME ATTENTION RETAINS THE SEMANTICS OF ITS OWNING PRODUCT.**

---

## 19. Anti-drift guard

| ❌ Prohibited reading | Why it violates FD-1 |
|---|---|
| "One chronological feed of every event" | §1, §12 |
| "Rename the notifications screen and ship it" | §1 |
| "The Hub owns invitations / messages / meetings" | §2, §6 |
| "Implement accept/decline inside the Hub" | §6 — that is a second implementation of a domain capability |
| "Route attention to the module landing page" | §8 |
| "Opening the Hub marks everything read" | §10 |
| "Unread covers every attention state" | §9 |
| "Institutional attention needs its own inbox" | §13 (and FD-9) |
| "Group all realtime attention into a Calls domain" | §14 (and FD-3) |
| "Show every backend event so nothing is missed" | §12 |
| "Leave the Accept button; the server will reject it" | §11 |
| "FD-1 authorizes deleting the 8 surfaces now" | §17 — permission to *plan*, not to implement |
| "FD-1 froze the attention state vocabulary" | §9 — FD-2 remains **open** |
