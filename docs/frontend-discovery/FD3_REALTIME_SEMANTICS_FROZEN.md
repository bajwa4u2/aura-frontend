# FD-3 — Realtime Product Semantics

# STATUS: FROZEN — FOUNDER APPROVED 2026-08-15

Founder-approved architecture input. This supersedes the open question recorded as Finding R3 in `REALTIME_PRODUCT_MODEL_AUDIT.md`.

---

## 1. Core doctrine

> **Shared realtime infrastructure does NOT imply shared product semantics.**

The Release Client must preserve distinct realtime meaning according to the product/context that **owns** the communication.

### Frozen conceptual ownership

| Context | Frozen meaning |
|---|---|
| **DM** | Private person-to-person realtime conversation. |
| **THREAD** | Realtime conversation **belonging to and retaining continuity with its Thread**. |
| **SPACE** | Group realtime conversation **belonging to and retaining continuity with its Space**. |
| **INSTITUTION ROOM** | Institution-owned persistent/drop-in communication room with **governed participation**. |
| **MEETING** | Purposeful scheduled/instant institutional conversation with **its own Meeting lifecycle**. |
| **LIVE** | Future governed public-stage/audience capability emerging from the appropriate Thread/Space context. **It is NOT another Meeting merely because both use realtime media.** |

---

## 2. Shared infrastructure — what MAY converge

Convergence is permitted and encouraged **underneath** these product semantics:

realtime transport · media primitives · device routing · multi-device authority · media ownership · reconnect · session continuity · common participant primitives · technical connection state · notification/ringing infrastructure · shared realtime controls where genuinely universal.

## What must NOT be erased by that convergence

ownership · initiation · invitation · participation · admission · authority · moderation · history · continuity · public/private meaning · speaker/viewer semantics · end-state · owning product surface.

---

## 3. Meetings protection

Meetings retain their genuine institutional lifecycle and **must not be collapsed into a generic room/call abstraction**.

Product-owned and preserved: preparation · invitation · booking · attendance · waiting/admission · conversation · follow-up · continuity.

> **Do not modify certified Meetings for convenience while reconstructing other realtime consumers.**

---

## 4. The user experience IS to be reconstructed

Distinct product semantics do **not** license preserving the current creation and participation experience. That experience is explicitly **not sacred**.

The future experience for **creating · starting · adding people · selecting people · inviting people · joining · participant management · changing participation state** must be modern, simplified, state-of-the-art and carefully curated.

### Governing UX principle

> # SIMPLIFY THE ACT, NOT THE AUTHORITY.

The **backend** remains rigorous about: eligibility · authority · ownership · invitation · ringing · participant state · role · admission · speaking/viewing rights.

The **frontend** translates those authorities into natural human actions **without exposing unnecessary implementation concepts**.

---

## 5. Common interaction philosophy

A coherent philosophy to design toward — a **product principle, not an instruction to make every surface visually identical**:

> START NATURALLY → establish/infer owning context → select people simply → clearly communicate what will happen → invite/start → progressively manage participation.

Context-specific differences remain where meaningful.

---

## 6. People & Participation selection (investigation directive)

Investigate a **governed shared People & Participation selection pattern/primitives** serving the appropriate contexts **without duplicating eligibility logic**.

Capabilities to evaluate: fast people search · relevant/recent people · institution members where contextually valid · existing participants · multi-select · invitation state · clear eligibility · unavailable/ineligible explanation · role or participation choice **only when genuinely necessary** · simple add/invite actions · progressive disclosure of advanced controls.

> **Backend authority determines eligibility wherever possible. Do not rebuild local frontend permission/role inference.**

This reinforces Finding M1 (shadow governance: 29 files role-check, 20 compute capability booleans).

---

## 7. Participation experience

Users interact with understandable **product actions**, not backend abstractions. Illustrative only:

Start · Join · Invite people · Add participant · Admit · Allow to speak · Return to audience · Leave · End

> **Exact CTA vocabulary is NOT frozen by these examples** — it remains subject to the broader CTA/terminology adjudication (FD-10).

---

## 8. Global-market research requirement (later design work)

Study current high-quality practice for: people/member pickers · participant selection · meeting/session creation · group calls · rooms/huddles · invitations · participant management · speaker/audience transitions · live participation.

Extract: mental models · interaction efficiency · progressive disclosure · selection simplicity · participation clarity · common complexity failures.

> **Do not copy another company's UI or product model.** Apply principles through Aura's own governing purpose and authorities.

---

## 9. The two-sided freeze

**BOTH are frozen simultaneously:**

| A. DISTINCT PRODUCT SEMANTICS | B. COHERENT MODERN INTERACTION QUALITY |
|---|---|
| DM / Thread / Space / Institution Room / Meeting / Live retain their respective ownership and meaning. | Creation, selection, invitation and participation feel like **one mature product family**, not six independently patched experiences. |

> **Do not mistake semantic separation for permission to preserve UX fragmentation.**
> **Do not mistake UX convergence for permission to collapse product semantics.**

---

## 10. Anti-drift guard

FD-3 must never be re-read as either failure mode:

| ❌ Prohibited reading | Why it violates FD-3 |
|---|---|
| "One generic call/room model" | Erases ownership, admission, history, public/private and speaker/viewer meaning (§1, §2, §3, §9A) |
| "Every realtime surface implements its own unrelated participant UX" | Preserves the fragmentation §4 and §9B explicitly reject |
| "Meetings can be collapsed into rooms" | Violates §3 |
| "Live is just another Meeting" | Violates §1 |
| "Semantics differ, so the UX may stay as-is" | Violates §4 |
| "Client re-derives eligibility to simplify the picker" | Violates §6 |

**Any future proposal must be checked against this table before it is accepted.**
